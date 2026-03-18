import Foundation

// MARK: - Action payload

struct CalendarActionPayload: Decodable {
    enum ActionType: String, Decodable {
        case create
        case update
        case delete
    }

    // Optional — small models often omit it; default to .create
    let action: ActionType?
    let title: String?         // required for create/update; omitted for delete
    let search: String?        // existing event title to find (update/delete)
    let start: Date?           // event start for create/update; range start for bulk delete
    let end: Date?             // event end for create/update; range end for bulk delete
    let location: String?
    let notes: String?
    let reminderMinutes: Int?  // minutes before event to trigger alarm
}

// MARK: - Result

enum CalendarActionResult {
    case success(String, CalendarEventPreview)
    case bulkPending([CalendarEventPreview])   // multiple pending-deletion cards
    case failure(String)
}

// MARK: - Controller

/// Receives a JSON payload emitted by the LLM and dispatches to CalendarService.
/// Add new action types here without touching ChatViewModel.
@MainActor
final class CalendarActionController {
    private let calendarService: CalendarService
    private let settings: AppSettings

    // Date formats the LLM might generate — tried in order
    private static let dateFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss",   // canonical ISO8601 (no tz)
        "yyyy-MM-dd HH:mm:ss",     // space instead of T
        "yyyy-MM-dd'T'HH:mm:ssZ",  // with timezone
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd HH:mm",        // no seconds
        "yyyy-MM-dd'T'HH:mm",
    ]

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            for format in CalendarActionController.dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: raw) { return date }
            }

            // Last resort: ISO8601DateFormatter with various options
            let iso = ISO8601DateFormatter()
            for opt: ISO8601DateFormatter.Options in [
                [.withInternetDateTime],
                [.withInternetDateTime, .withFractionalSeconds],
                [.withFullDate, .withTime, .withColonSeparatorInTime],
            ] {
                iso.formatOptions = opt
                if let date = iso.date(from: raw) { return date }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(raw)"
            )
        }
        return d
    }()

    init(calendarService: CalendarService, settings: AppSettings) {
        self.calendarService = calendarService
        self.settings = settings
    }

    func execute(json: String) async -> CalendarActionResult {
        guard let data = json.data(using: .utf8) else {
            return .failure("Malformed action payload.")
        }

        let payload: CalendarActionPayload
        do {
            payload = try Self.decoder.decode(CalendarActionPayload.self, from: data)
        } catch {
            return .failure("Could not parse action [\(json)]: \(error.localizedDescription)")
        }

        switch payload.action ?? .create {
        case .create:
            return await createEvent(payload)
        case .update:
            return await updateEvent(payload)
        case .delete:
            // Bulk delete: no search title but date range provided
            if (payload.search == nil || payload.search!.isEmpty), payload.start != nil, payload.end != nil {
                return await bulkFindEventsForDeletion(payload)
            }
            return await findEventForDeletion(payload)
        }
    }

    // MARK: - Handlers

    private func updateEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for update.)")
        }
        guard p.title != nil || p.start != nil || p.end != nil || p.location != nil || p.notes != nil else {
            return .failure("(No fields to update were provided.)")
        }
        do {
            let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let windowEnd   = Calendar.current.date(byAdding: .day, value:  30, to: .now) ?? .now
            let predicate = calendarService.store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
            let events = calendarService.store.events(matching: predicate)
            guard let event = events.first(where: { ($0.title ?? "").localizedCaseInsensitiveContains(searchTitle) }) else {
                return .failure("(Couldn't find an event called \"\(searchTitle)\" — please specify the exact name.)")
            }

            // Determine what changed BEFORE applying (used for state selection)
            let titleChanged = p.title != nil && p.title != event.title
            let datesChanged = p.start != nil || p.end != nil

            if let newTitle = p.title    { event.title = newTitle }
            if let newStart = p.start    { event.startDate = newStart }
            if let newEnd = p.end        { event.endDate = newEnd }
            if let loc = p.location, !loc.isEmpty   { event.location = loc }
            if let notes = p.notes, !notes.isEmpty  { event.notes = notes }

            try calendarService.store.save(event, span: .thisEvent)

            let state: CalendarEventPreview.PreviewState = datesChanged && !titleChanged ? .rescheduled : .updated
            let preview = CalendarEventPreview(
                title: event.title ?? searchTitle,
                start: event.startDate,
                end: event.endDate,
                calendarName: event.calendar?.title,
                state: state
            )
            let verb = state == .rescheduled ? "Rescheduled" : "Updated"
            return .success("\(verb) \"\(searchTitle)\".", preview)
        } catch {
            return .failure("(Couldn't update event: \(error.localizedDescription))")
        }
    }

    private func findEventForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for deletion.)")
        }
        let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let windowEnd   = Calendar.current.date(byAdding: .day, value:  30, to: .now) ?? .now
        let predicate = calendarService.store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let events = calendarService.store.events(matching: predicate)
        let lower = searchTitle.lowercased()

        // 1. Exact substring match
        var event = events.first(where: { ($0.title ?? "").lowercased().contains(lower) })

        // 2. Word-based fallback: any meaningful word (>3 chars) from search appears in event title or vice versa
        if event == nil {
            let searchWords = lower.split(separator: " ").map(String.init).filter { $0.count > 3 }
            event = events.first(where: { ev in
                let t = (ev.title ?? "").lowercased()
                let titleWords = t.split(separator: " ").map(String.init).filter { $0.count > 3 }
                return searchWords.contains(where: { t.contains($0) })
                    || titleWords.contains(where: { lower.contains($0) })
            })
        }

        guard let event else {
            return .failure("(Couldn't find an event called \"\(searchTitle)\" — please specify the exact name.)")
        }
        let preview = CalendarEventPreview(
            title: event.title ?? searchTitle,
            start: event.startDate,
            end: event.endDate,
            calendarName: event.calendar?.title,
            state: .pendingDeletion,
            eventIdentifier: event.eventIdentifier
        )
        return .success("", preview)
    }

    private func createEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let title = p.title, let start = p.start, let end = p.end else {
            return .failure("(Create requires title, start, and end.)")
        }
        do {
            // Conflict check
            let conflicts = calendarService.findConflicts(start: start, end: end)
            let conflictNote = conflicts.isEmpty ? "" :
                " Note: overlaps with \(conflicts.map { "\"\($0.title ?? "event")\"" }.joined(separator: ", "))."

            let calID = settings.defaultCalendarIdentifier.isEmpty ? nil : settings.defaultCalendarIdentifier
            let identifier = try calendarService.createEvent(
                title: title,
                start: start,
                end: end,
                location: p.location,
                notes: p.notes,
                reminderMinutes: p.reminderMinutes,
                calendarIdentifier: calID
            )
            let calendarName = calendarService.store.event(withIdentifier: identifier)?.calendar?.title
                ?? calendarService.store.defaultCalendarForNewEvents?.title
            let preview = CalendarEventPreview(
                title: title,
                start: start,
                end: end,
                calendarName: calendarName,
                reminderMinutes: p.reminderMinutes
            )
            return .success("Added \"\(title)\" to your calendar.\(conflictNote)", preview)
        } catch {
            return .failure("(Couldn't save event: \(error.localizedDescription))")
        }
    }

    private func bulkFindEventsForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let rangeStart = p.start, let rangeEnd = p.end else {
            return .failure("(Bulk delete requires start and end dates.)")
        }
        let events = calendarService.events(in: rangeStart, end: rangeEnd)
        guard !events.isEmpty else {
            return .failure("(No events found in that date range.)")
        }
        let previews = events.map { event in
            CalendarEventPreview(
                title: event.title ?? "Untitled",
                start: event.startDate,
                end: event.endDate,
                calendarName: event.calendar?.title,
                state: .pendingDeletion,
                eventIdentifier: event.eventIdentifier
            )
        }
        return .bulkPending(previews)
    }
}

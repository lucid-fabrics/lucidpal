import Foundation

// MARK: - Action payload

struct CalendarActionPayload: Decodable {
    enum ActionType: String, Decodable {
        case create
        case update
        case delete
        case query
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
    let isAllDay: Bool?        // true for all-day events (holidays, birthdays)
    let recurrence: String?    // "daily" | "weekly" | "monthly" | "yearly"
    let recurrenceEnd: Date?   // optional end date for recurrence
    let durationMinutes: Int?  // for query: desired free slot length in minutes
}

// MARK: - Result

enum CalendarActionResult {
    case success(String, CalendarEventPreview)
    case bulkPending([CalendarEventPreview])   // multiple pending-deletion cards
    case queryResult(String)                   // free slot query — plain text answer
    case failure(String)
}

// MARK: - Protocol

/// Abstraction for executing LLM-emitted calendar action JSON.
/// Inject via `any CalendarActionControllerProtocol` in ChatViewModel for testability.
@MainActor
protocol CalendarActionControllerProtocol: AnyObject {
    func execute(json: String) async -> CalendarActionResult
}

// MARK: - Controller

/// Receives a JSON payload emitted by the LLM and dispatches to CalendarService.
/// Add new action types here without touching ChatViewModel.
@MainActor
final class CalendarActionController: CalendarActionControllerProtocol {
    private let calendarService: any CalendarServiceProtocol
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

    init(calendarService: any CalendarServiceProtocol, settings: AppSettings) {
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
            if payload.search?.isEmpty ?? true, payload.start != nil, payload.end != nil {
                return await bulkFindEventsForDeletion(payload)
            }
            return await findEventForDeletion(payload)
        case .query:
            return await findFreeSlots(payload)
        }
    }

    // MARK: - Handlers

    private func updateEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for update.)")
        }
        guard p.title != nil || p.start != nil || p.end != nil || p.location != nil || p.notes != nil || p.reminderMinutes != nil else {
            return .failure("(No fields to update were provided.)")
        }
        let events = calendarService.findEvents(matching: searchTitle, windowDays: 60)
        guard let event = events.first(where: { ($0.title ?? "").localizedCaseInsensitiveContains(searchTitle) }) else {
            return .failure("(Couldn't find an event called \"\(searchTitle)\" — please specify the exact name.)")
        }

        // Build pending snapshot — let user confirm before applying
        var pending = PendingCalendarUpdate()
        if let t = p.title    { pending.title = t }
        if let s = p.start    { pending.start = s }
        if let e = p.end      { pending.end = e }
        if let l = p.location, !l.isEmpty { pending.location = l }
        if let n = p.notes, !n.isEmpty    { pending.notes = n }
        if let m = p.reminderMinutes      { pending.reminderMinutes = m }
        if let a = p.isAllDay             { pending.isAllDay = a }
        if let r = p.recurrence           { pending.recurrence = r }

        var preview = CalendarEventPreview(
            title: event.title ?? searchTitle,
            start: event.startDate,
            end: event.endDate,
            calendarName: event.calendarTitle,
            state: .pendingUpdate,
            eventIdentifier: event.eventIdentifier
        )
        preview.pendingUpdate = pending
        return .success("", preview)
    }

    private func findEventForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for deletion.)")
        }
        let events = calendarService.findEvents(matching: searchTitle, windowDays: 60)
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
            calendarName: event.calendarTitle,
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
            let conflicts = calendarService.findConflicts(start: start, end: end, excludingIdentifier: nil)
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
                calendarIdentifier: calID,
                isAllDay: p.isAllDay ?? false,
                recurrence: p.recurrence,
                recurrenceEnd: p.recurrenceEnd
            )
            let calendarName = calendarService.calendarName(forEventIdentifier: identifier)
                ?? calendarService.defaultCalendarInfo()?.title
            let preview = CalendarEventPreview(
                title: title,
                start: start,
                end: end,
                calendarName: calendarName,
                reminderMinutes: p.reminderMinutes,
                isAllDay: p.isAllDay ?? false,
                recurrence: p.recurrence
            )
            return .success("Added \"\(title)\" to your calendar.\(conflictNote)", preview)
        } catch {
            return .failure("(Couldn't save event: \(error.localizedDescription))")
        }
    }

    private func findFreeSlots(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let rangeStart = p.start, let rangeEnd = p.end, rangeStart < rangeEnd else {
            return .failure("(Free slot query requires a valid start and end range.)")
        }
        let requestedMinutes = p.durationMinutes ?? 60
        guard requestedMinutes > 0 else {
            return .failure("(Duration must be greater than 0 minutes.)")
        }
        let duration = TimeInterval(requestedMinutes * 60)
        let events = calendarService.events(in: rangeStart, end: rangeEnd)
            .sorted { $0.startDate < $1.startDate }

        // Collect and merge overlapping busy windows
        var merged: [(Date, Date)] = []
        for ev in events {
            let window = (ev.startDate, ev.endDate)
            if let last = merged.last, window.0 < last.1 {
                merged[merged.count - 1] = (last.0, max(last.1, window.1))
            } else {
                merged.append(window)
            }
        }

        // Find gaps ≥ duration within working hours (8am–8pm)
        let cal = Calendar.current
        var slots: [String] = []
        var cursor = rangeStart

        // Clamp cursor to next 8am if before
        func nextWorkStart(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = 8; comps.minute = 0; comps.second = 0
            let day8am = cal.date(from: comps) ?? from
            return day8am < from ? cal.date(byAdding: .day, value: 1, to: day8am) ?? from : day8am
        }
        func dayEnd(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = 20; comps.minute = 0; comps.second = 0
            return cal.date(from: comps) ?? from
        }

        cursor = nextWorkStart(cursor)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        for window in merged + [(rangeEnd, rangeEnd)] {
            guard cursor < rangeEnd else { break }
            let freeEnd = min(window.0, dayEnd(cursor))
            if freeEnd > cursor && freeEnd.timeIntervalSince(cursor) >= duration {
                slots.append("• \(formatter.string(from: cursor)) – \(formatter.string(from: freeEnd))")
                if slots.count == 3 { break }
            }
            let afterBusy = window.1
            cursor = max(cursor, max(afterBusy, nextWorkStart(afterBusy)))
        }

        if slots.isEmpty {
            return .queryResult("No free \(requestedMinutes)-minute slots found in that range.")
        }
        let label = "\(requestedMinutes)-minute"
        return .queryResult("Free \(label) slots:\n" + slots.joined(separator: "\n"))
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
                calendarName: event.calendarTitle,
                state: .pendingDeletion,
                eventIdentifier: event.eventIdentifier
            )
        }
        return .bulkPending(previews)
    }
}

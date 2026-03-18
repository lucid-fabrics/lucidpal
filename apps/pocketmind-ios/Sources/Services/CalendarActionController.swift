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
    let title: String          // new title (or title to create)
    let search: String?        // existing event title to find (update only)
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
}

// MARK: - Result

enum CalendarActionResult {
    case success(String, CalendarEventPreview)
    case failure(String)
}

// MARK: - Controller

/// Receives a JSON payload emitted by the LLM and dispatches to CalendarService.
/// Add new action types here without touching ChatViewModel.
@MainActor
final class CalendarActionController {
    private let calendarService: CalendarService

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

    init(calendarService: CalendarService) {
        self.calendarService = calendarService
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
            return await findEventForDeletion(payload)
        }
    }

    // MARK: - Handlers

    private func updateEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("⚠️ No search title provided for update.")
        }
        do {
            // Search a 60-day window centred on today rather than on the LLM-emitted date.
            // This avoids missing the original event when the user asks to rename/move it
            // to a date far from its current position.
            let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
            let windowEnd   = Calendar.current.date(byAdding: .day, value:  30, to: .now) ?? .now
            let predicate = calendarService.store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
            let events = calendarService.store.events(matching: predicate)
            guard let event = events.first(where: { ($0.title ?? "").localizedCaseInsensitiveContains(searchTitle) }) else {
                return .failure("⚠️ Could not find event matching \"\(searchTitle)\".")
            }
            event.title = p.title
            event.startDate = p.start
            event.endDate = p.end
            if let loc = p.location, !loc.isEmpty { event.location = loc }
            if let notes = p.notes, !notes.isEmpty { event.notes = notes }
            try calendarService.store.save(event, span: .thisEvent)
            let preview = CalendarEventPreview(title: p.title, start: p.start, end: p.end, calendarName: event.calendar?.title)
            return .success("Updated \"\(searchTitle)\" → \"\(p.title)\".", preview)
        } catch {
            return .failure("⚠️ Couldn't update event: \(error.localizedDescription)")
        }
    }

    private func findEventForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("⚠️ No search title provided for deletion.")
        }
        let windowStart = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        let windowEnd   = Calendar.current.date(byAdding: .day, value:  30, to: .now) ?? .now
        let predicate = calendarService.store.predicateForEvents(withStart: windowStart, end: windowEnd, calendars: nil)
        let events = calendarService.store.events(matching: predicate)
        guard let event = events.first(where: { ($0.title ?? "").localizedCaseInsensitiveContains(searchTitle) }) else {
            return .failure("⚠️ Could not find event matching \"\(searchTitle)\".")
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
        do {
            let calendarName = calendarService.store.defaultCalendarForNewEvents?.title
            try calendarService.createEvent(
                title: p.title,
                start: p.start,
                end: p.end,
                location: p.location,
                notes: p.notes
            )
            let preview = CalendarEventPreview(
                title: p.title,
                start: p.start,
                end: p.end,
                calendarName: calendarName
            )
            return .success("Added \"\(p.title)\" to your calendar.", preview)
        } catch {
            return .failure("⚠️ Couldn't save event: \(error.localizedDescription)")
        }
    }
}

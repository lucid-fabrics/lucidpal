import Foundation

// Types: see CalendarActionModels.swift

// MARK: - Controller

/// Receives a JSON payload emitted by the LLM and dispatches to CalendarService.
/// Add new action types here without touching ChatViewModel.
@MainActor
final class CalendarActionController: CalendarActionControllerProtocol {
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol

    /// Search window for update/delete by title — smaller than the default browse window
    /// to avoid matching stale events from years ago when names recur (e.g. "Dentist").
    static let actionSearchWindowDays = 60

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

            // Second attempt: ISO8601DateFormatter with various options
            let iso = ISO8601DateFormatter()
            for opt: ISO8601DateFormatter.Options in [
                [.withInternetDateTime],
                [.withInternetDateTime, .withFractionalSeconds],
                [.withFullDate, .withTime, .withColonSeparatorInTime],
            ] {
                iso.formatOptions = opt
                if let date = iso.date(from: raw) { return date }
            }

            // Final fallback: NSDataDetector for natural language dates
            // ("tomorrow at 3pm", "next Monday", "in 2 hours", etc.).
            // Respects device locale and timezone automatically.
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
                let nsRange = NSRange(raw.startIndex..., in: raw)
                if let match = detector.firstMatch(in: raw, options: [], range: nsRange),
                   let date = match.date {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(raw)"
            )
        }
        return d
    }()

    init(calendarService: any CalendarServiceProtocol, settings: any AppSettingsProtocol) {
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

        guard let action = payload.action else {
            return .failure("Could not parse action [\(json)]: missing required 'action' field.")
        }
        switch action {
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
        case .list:
            return await listEvents(payload)
        }
    }

}

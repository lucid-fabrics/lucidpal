import Foundation
import OSLog

private let calendarActionLogger = Logger(subsystem: "app.lucidpal", category: "CalendarActionController")

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

    // Cached detector — NSDataDetector construction is expensive (compiles an automaton);
    // instantiating it once and reusing avoids repeated allocation on every date field.
    private static let dateDetector: NSDataDetector? = {
        do {
            return try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        } catch {
            // Construction failure is a programming error (invalid type mask) — surface loudly.
            assertionFailure("NSDataDetector failed to initialize: \(error)")
            calendarActionLogger.fault("NSDataDetector construction failed — relative date parsing disabled: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }()

    // Date formats the LLM might generate — tried in order
    private static let dateFormats: [String] = [
        "yyyy-MM-dd'T'HH:mm:ss",      // canonical ISO8601 (no tz)
        "yyyy-MM-dd HH:mm:ss",        // space instead of T
        "yyyy-MM-dd'T'HH:mm:ssZ",     // with timezone
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ", // with millis + timezone
        "yyyy-MM-dd'T'HH:mm:ss.SSS",  // with millis, no timezone
        "yyyy-MM-dd HH:mm",           // no seconds
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd",                 // date-only (all-day events)
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
            // Skip strings that look like ISO 8601 dates (YYYY-MM prefix or 'T' separator)
            // to avoid silently misparsing exotic variants the formatters above didn't catch.
            // Use a character-level ISO date prefix check (4 digits + '-' + 2 digits) rather
            // than raw.contains("-") to avoid blocking NL strings like "2-hour meeting" or
            // "1-on-1 at 3pm" which contain a hyphen with a leading digit.
            let chars = Array(raw)
            let hasISODatePrefix = chars.count >= 7
                && chars[0].isNumber && chars[1].isNumber
                && chars[2].isNumber && chars[3].isNumber
                && chars[4] == "-"
                && chars[5].isNumber && chars[6].isNumber
            // hasISODatePrefix already covers all ISO datetimes (YYYY-MM-DDThh:mm:ss...),
            // so the former raw.contains("T") guard is omitted — it incorrectly blocked
            // natural language strings like "Tomorrow at 3pm" or "Next Tuesday at noon".
            let looksLikeISO = hasISODatePrefix
            if !looksLikeISO, let detector = CalendarActionController.dateDetector {
                let nsRange = NSRange(raw.startIndex..., in: raw)
                // Require a full-string match — reject partial hits like "tomorrow" inside
                // "meeting tomorrow with Alice" where the intent is ambiguous.
                if let match = detector.firstMatch(in: raw, options: [], range: nsRange),
                   match.range == nsRange,
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
            calendarActionLogger.error("Failed to decode action payload: \(error.localizedDescription, privacy: .public) — payload: \(json, privacy: .private)")
            return .failure("Could not understand the action. Please try again.")
        }

        guard let action = payload.action else {
            calendarActionLogger.error("Action payload missing 'action' field — payload: \(json, privacy: .private)")
            return .failure("Could not understand the action: missing action type.")
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

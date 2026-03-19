import Foundation

// Types: see CalendarActionModels.swift

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
        case .list:
            return await listEvents(payload)
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
                recurrence: p.recurrence,
                location: p.location,
                hasConflict: !conflicts.isEmpty
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

        // Merge overlapping busy windows
        var merged: [(start: Date, end: Date)] = []
        for ev in events {
            let window = (start: ev.startDate, end: ev.endDate)
            if let last = merged.last, window.start < last.end {
                merged[merged.count - 1] = (last.start, max(last.end, window.end))
            } else {
                merged.append(window)
            }
        }

        let freeSlots = CalendarFreeSlotEngine.findSlots(
            busyWindows: merged,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: duration
        )
        return .queryResult(freeSlots)
    }

    private func listEvents(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let rangeStart = p.start, let rangeEnd = p.end, rangeStart < rangeEnd else {
            return .failure("(List requires a valid start and end date range.)")
        }
        let events = calendarService.events(in: rangeStart, end: rangeEnd)
            .sorted { $0.startDate < $1.startDate }
        let previews = events.map { event in
            CalendarEventPreview(
                title: event.title ?? "Untitled",
                start: event.startDate,
                end: event.endDate,
                calendarName: event.calendarTitle,
                state: .created,
                eventIdentifier: event.eventIdentifier,
                isAllDay: event.isAllDay,
                location: event.location
            )
        }
        return .listResult(previews)
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

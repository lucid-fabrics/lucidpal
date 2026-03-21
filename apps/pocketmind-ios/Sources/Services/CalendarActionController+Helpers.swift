import Foundation

// MARK: - CalendarActionController handlers + helpers

extension CalendarActionController {

    // MARK: - Handlers

    func updateEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for update.)")
        }
        guard p.title != nil || p.start != nil || p.end != nil || p.location != nil || p.notes != nil || p.reminderMinutes != nil else {
            return .failure("(No fields to update were provided.)")
        }
        let events = calendarService.findEvents(matching: searchTitle, windowDays: Self.actionSearchWindowDays)
        guard let event = events.first(where: { ($0.title ?? "").localizedCaseInsensitiveContains(searchTitle) }) else {
            return .failure("(Couldn't find an event called \"\(searchTitle)\" — please specify the exact name.)")
        }

        var pending = PendingCalendarUpdate()
        if let t = p.title    { pending.title = t }
        if let s = p.start    { pending.start = s }
        if let e = p.end      { pending.end = e }
        if let l = p.location, !l.isEmpty { pending.location = l }
        if let n = p.notes, !n.isEmpty    { pending.notes = n }
        if let m = p.reminderMinutes      { pending.reminderMinutes = m }
        if let a = p.isAllDay             { pending.isAllDay = a }
        if let r = p.recurrence           { pending.recurrence = r }

        let newStart = pending.start ?? event.startDate
        let newEnd = pending.end ?? event.endDate
        let conflictSnapshots: [ConflictingEventSnapshot]
        if pending.start != nil || pending.end != nil {
            let rawConflicts = calendarService.findConflicts(
                start: newStart, end: newEnd,
                excludingIdentifier: event.eventIdentifier
            )
            conflictSnapshots = makeConflictSnapshots(from: rawConflicts)
        } else {
            conflictSnapshots = []
        }

        var preview = CalendarEventPreview(
            title: event.title ?? searchTitle,
            start: event.startDate,
            end: event.endDate,
            calendarName: event.calendarTitle,
            state: .pendingUpdate,
            eventIdentifier: event.eventIdentifier,
            hasConflict: !conflictSnapshots.isEmpty,
            conflictingEvents: conflictSnapshots
        )
        preview.pendingUpdate = pending
        return .success("", preview)
    }

    func findEventForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let searchTitle = p.search, !searchTitle.isEmpty else {
            return .failure("(No event title provided for deletion.)")
        }
        let events = calendarService.findEvents(matching: searchTitle, windowDays: Self.actionSearchWindowDays)
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

    func createEvent(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let title = p.title, let start = p.start, let end = p.end else {
            return .failure("(Create requires title, start, and end.)")
        }
        do {
            let rawConflicts = calendarService.findConflicts(start: start, end: end, excludingIdentifier: nil)
            let conflictSnapshots = makeConflictSnapshots(from: rawConflicts)
            let conflictNote = conflictSnapshots.isEmpty ? "" :
                " Heads-up: this overlaps with \(conflictSnapshots.map { "\"\($0.title)\"" }.joined(separator: ", "))."

            let calID = settings.defaultCalendarIdentifier.isEmpty ? nil : settings.defaultCalendarIdentifier
            let identifier = try calendarService.createEvent(
                title: title, start: start, end: end,
                location: p.location, notes: p.notes,
                reminderMinutes: p.reminderMinutes,
                calendarIdentifier: calID,
                isAllDay: p.isAllDay ?? false,
                recurrence: p.recurrence,
                recurrenceEnd: p.recurrenceEnd
            )
            let calendarName = calendarService.calendarName(forEventIdentifier: identifier)
                ?? calendarService.defaultCalendarInfo()?.title
            let eventIdentifier = identifier.isEmpty ? nil : identifier
            SiriContextStore.write(SiriLastAction(
                type: .created,
                eventTitle: title, eventStart: start, eventEnd: end,
                calendarName: calendarName, calendarIdentifier: calID,
                isAllDay: p.isAllDay ?? false,
                location: p.location, notes: p.notes,
                eventIdentifier: eventIdentifier, timestamp: .now
            ))
            let preview = CalendarEventPreview(
                title: title, start: start, end: end,
                calendarName: calendarName,
                eventIdentifier: eventIdentifier,
                reminderMinutes: p.reminderMinutes,
                isAllDay: p.isAllDay ?? false,
                recurrence: p.recurrence, location: p.location,
                hasConflict: !conflictSnapshots.isEmpty,
                conflictingEvents: conflictSnapshots
            )
            return .success("Added \"\(title)\" to your calendar.\(conflictNote)", preview)
        } catch {
            return .failure("(Couldn't save event: \(error.localizedDescription))")
        }
    }

    func findFreeSlots(_ p: CalendarActionPayload) async -> CalendarActionResult {
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
        let merged = mergeBusyWindows(from: events)
        let freeSlots = CalendarFreeSlotEngine.findSlots(
            busyWindows: merged, rangeStart: rangeStart, rangeEnd: rangeEnd, duration: duration
        )
        return .queryResult(freeSlots)
    }

    func listEvents(_ p: CalendarActionPayload) async -> CalendarActionResult {
        guard let rangeStart = p.start, let rangeEnd = p.end, rangeStart < rangeEnd else {
            return .failure("(List requires a valid start and end date range.)")
        }
        let events = calendarService.events(in: rangeStart, end: rangeEnd)
            .sorted { $0.startDate < $1.startDate }
        let previews = events.map { event in
            CalendarEventPreview(
                title: event.title ?? "Untitled",
                start: event.startDate, end: event.endDate,
                calendarName: event.calendarTitle,
                state: .listed,
                eventIdentifier: event.eventIdentifier,
                isAllDay: event.isAllDay, location: event.location
            )
        }
        return .listResult(previews)
    }

    func bulkFindEventsForDeletion(_ p: CalendarActionPayload) async -> CalendarActionResult {
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
                start: event.startDate, end: event.endDate,
                calendarName: event.calendarTitle,
                state: .pendingDeletion,
                eventIdentifier: event.eventIdentifier
            )
        }
        return .bulkPending(previews)
    }

    // MARK: - Helpers


    /// Maps an array of `CalendarEventInfo` values to `ConflictingEventSnapshot` values.
    func makeConflictSnapshots(from events: [CalendarEventInfo]) -> [ConflictingEventSnapshot] {
        events.map {
            ConflictingEventSnapshot(
                title: $0.title ?? "Event",
                start: $0.startDate,
                end: $0.endDate,
                calendarName: $0.calendarTitle,
                isRecurring: $0.isRecurring,
                isAllDay: $0.isAllDay
            )
        }
    }

    /// Merges overlapping busy windows from a sorted list of calendar events.
    /// Events must be pre-sorted by `startDate` ascending.
    func mergeBusyWindows(from events: [CalendarEventInfo]) -> [(start: Date, end: Date)] {
        var merged: [(start: Date, end: Date)] = []
        for ev in events {
            let window = (start: ev.startDate, end: ev.endDate)
            if let last = merged.last, window.start < last.end {
                merged[merged.count - 1] = (last.start, max(last.end, window.end))
            } else {
                merged.append(window)
            }
        }
        return merged
    }
}

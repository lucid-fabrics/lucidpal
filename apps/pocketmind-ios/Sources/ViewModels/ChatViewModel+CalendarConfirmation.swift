import Foundation
import OSLog

private let calendarConfirmationLogger = Logger(subsystem: "com.pocketmind", category: "CalendarConfirmation")

// MARK: - Calendar event confirmation (deletion + update)
// Separated from the core ViewModel to keep each file under 300 lines.

extension ChatViewModel {

    /// Returns (messageIndex, previewIndex) if both IDs resolve — DRYs out all confirmation methods.
    func indices(messageID: UUID, previewID: UUID) -> (Int, Int)? {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }),
              let previewIdx = messages[msgIdx].calendarEventPreviews.firstIndex(where: { $0.id == previewID })
        else { return nil }
        return (msgIdx, previewIdx)
    }

    func confirmDeletion(messageID: UUID, previewID: UUID) async {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier
        else { return }
        do {
            try calendarService.deleteEvent(identifier: identifier)
            let preview = messages[msgIdx].calendarEventPreviews[previewIdx]
            SiriContextStore.write(SiriLastAction(
                type: .deleted,
                eventTitle: preview.title,
                eventStart: preview.start,
                eventEnd: preview.end,
                calendarName: preview.calendarName,
                calendarIdentifier: nil,
                isAllDay: preview.isAllDay,
                location: preview.location,
                notes: nil,
                eventIdentifier: nil,
                timestamp: .now
            ))
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .deleted
            hapticService.notifySuccess()
        } catch {
            calendarConfirmationLogger.error("confirmDeletion failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func undoDeletion(messageID: UUID, previewID: UUID) async {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return }
        let preview = messages[msgIdx].calendarEventPreviews[previewIdx]
        do {
            try calendarService.createEvent(
                title: preview.title,
                start: preview.start,
                end: preview.end,
                location: nil,
                notes: nil,
                reminderMinutes: preview.reminderMinutes,
                calendarIdentifier: nil,
                isAllDay: preview.isAllDay,
                recurrence: preview.recurrence,
                recurrenceEnd: nil
            )
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .restored
            hapticService.notifySuccess()
        } catch {
            calendarConfirmationLogger.error("undoDeletion failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func cancelDeletion(messageID: UUID, previewID: UUID) {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .deletionCancelled
        hapticService.impact(.light)
    }

    func confirmAllDeletions(messageID: UUID) async {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        let pendingIndices = messages[msgIdx].calendarEventPreviews.indices.filter {
            messages[msgIdx].calendarEventPreviews[$0].state == .pendingDeletion
        }
        var failures: [String] = []
        for idx in pendingIndices {
            guard let identifier = messages[msgIdx].calendarEventPreviews[idx].eventIdentifier else {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
                continue
            }
            do {
                try calendarService.deleteEvent(identifier: identifier)
                messages[msgIdx].calendarEventPreviews[idx].state = .deleted
            } catch {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
                failures.append(messages[msgIdx].calendarEventPreviews[idx].title)
            }
        }
        if failures.isEmpty {
            hapticService.notifySuccess()
        } else {
            errorMessage = "Couldn't delete: \(failures.joined(separator: ", "))"
        }
    }

    func cancelAllDeletions(messageID: UUID) {
        guard let msgIdx = messages.firstIndex(where: { $0.id == messageID }) else { return }
        for idx in messages[msgIdx].calendarEventPreviews.indices {
            if messages[msgIdx].calendarEventPreviews[idx].state == .pendingDeletion {
                messages[msgIdx].calendarEventPreviews[idx].state = .deletionCancelled
            }
        }
        hapticService.impact(.light)
    }

    func confirmUpdate(messageID: UUID, previewID: UUID) async {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier,
              let pending = messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate
        else { return }
        do {
            let newState = try calendarService.applyUpdate(pending, to: identifier)
            let preview = messages[msgIdx].calendarEventPreviews[previewIdx]
            SiriContextStore.write(SiriLastAction(
                type: newState == .rescheduled ? .rescheduled : .updated,
                eventTitle: pending.title ?? preview.title,
                eventStart: pending.start ?? preview.start,
                eventEnd: pending.end ?? preview.end,
                calendarName: preview.calendarName,
                calendarIdentifier: nil,
                isAllDay: pending.isAllDay ?? preview.isAllDay,
                location: pending.location ?? preview.location,
                notes: pending.notes,
                eventIdentifier: identifier,
                timestamp: .now
            ))
            // Mirror applied changes onto the preview so the card shows the updated values
            if let t = pending.title    { messages[msgIdx].calendarEventPreviews[previewIdx].title = t }
            if let s = pending.start    { messages[msgIdx].calendarEventPreviews[previewIdx].start = s }
            if let e = pending.end      { messages[msgIdx].calendarEventPreviews[previewIdx].end = e }
            if let a = pending.isAllDay { messages[msgIdx].calendarEventPreviews[previewIdx].isAllDay = a }
            if let m = pending.reminderMinutes { messages[msgIdx].calendarEventPreviews[previewIdx].reminderMinutes = m }
            messages[msgIdx].calendarEventPreviews[previewIdx].state = newState
            messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
            hapticService.notifySuccess()
        } catch CalendarError.eventNotFound {
            // Event was deleted externally — dismiss the card rather than leaving it stuck.
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .updateCancelled
            messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
            errorMessage = "That event was deleted from your calendar."
        } catch {
            calendarConfirmationLogger.error("confirmUpdate failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func cancelUpdate(messageID: UUID, previewID: UUID) {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .updateCancelled
        messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
        hapticService.impact(.light)
    }

    // MARK: - Conflict resolution

    /// User chose to keep the conflicting event — clears conflict indicators.
    func keepConflict(messageID: UUID, previewID: UUID) {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].hasConflict = false
        messages[msgIdx].calendarEventPreviews[previewIdx].conflictingEvents = []
        hapticService.impact(.light)
    }

    /// User chose to cancel the conflicting event — deletes it and marks the card deleted.
    func cancelConflict(messageID: UUID, previewID: UUID) async {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier
        else { return }
        do {
            try calendarService.deleteEvent(identifier: identifier)
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .deleted
            messages[msgIdx].calendarEventPreviews[previewIdx].hasConflict = false
            messages[msgIdx].calendarEventPreviews[previewIdx].conflictingEvents = []
            hapticService.notifySuccess()
        } catch {
            calendarConfirmationLogger.error("cancelConflict deletion failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// Finds free slots around the conflicting event's scheduled time.
    /// Searches a 3-day window matching the event's duration.
    func findFreeSlotsForConflict(messageID: UUID, previewID: UUID) async -> [CalendarFreeSlot] {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return [] }
        let preview = messages[msgIdx].calendarEventPreviews[previewIdx]
        let rawDuration = preview.end.timeIntervalSince(preview.start)

        // All-day events are stored with endDate = startDate (EventKit convention),
        // so rawDuration = 0. Use 2 h as the search window for all-day events.
        // Also cap very long timed events to 4 h so working-day slots can always be found.
        let maxSearchDuration: TimeInterval
        if preview.isAllDay || rawDuration <= 0 {
            maxSearchDuration = ChatConstants.allDaySlotSearchHours * ChatConstants.secondsPerHour
        } else {
            maxSearchDuration = min(rawDuration, ChatConstants.maxSlotSearchHours * ChatConstants.secondsPerHour)
        }

        let cal = Calendar.current
        let rangeStart = max(Date(), cal.startOfDay(for: preview.start))
        let rangeEnd = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: rangeStart)) ?? preview.end

        let busyEvents = calendarService.events(in: rangeStart, end: rangeEnd)
            .sorted { $0.startDate < $1.startDate }

        var merged: [(start: Date, end: Date)] = []
        for ev in busyEvents {
            if let last = merged.last, ev.startDate < last.end {
                merged[merged.count - 1] = (last.start, max(last.end, ev.endDate))
            } else {
                merged.append((ev.startDate, ev.endDate))
            }
        }

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: merged,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: maxSearchDuration
        )

        return slots
    }

    /// Reschedules the conflicting event to a chosen free slot.
    func rescheduleConflict(messageID: UUID, previewID: UUID, to slot: CalendarFreeSlot) async {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID),
              let identifier = messages[msgIdx].calendarEventPreviews[previewIdx].eventIdentifier
        else { return }
        let update = PendingCalendarUpdate(start: slot.start, end: slot.end)
        do {
            let newState = try calendarService.applyUpdate(update, to: identifier)
            messages[msgIdx].calendarEventPreviews[previewIdx].start = slot.start
            messages[msgIdx].calendarEventPreviews[previewIdx].end = slot.end
            messages[msgIdx].calendarEventPreviews[previewIdx].state = newState
            messages[msgIdx].calendarEventPreviews[previewIdx].hasConflict = false
            messages[msgIdx].calendarEventPreviews[previewIdx].conflictingEvents = []
            hapticService.notifySuccess()
        } catch {
            calendarConfirmationLogger.error("rescheduleConflict failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

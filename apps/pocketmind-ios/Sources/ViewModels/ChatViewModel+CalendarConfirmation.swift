import Foundation

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
            messages[msgIdx].calendarEventPreviews[previewIdx].state = .deleted
            hapticService.notifySuccess()
        } catch {
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
            errorMessage = error.localizedDescription
        }
    }

    func cancelUpdate(messageID: UUID, previewID: UUID) {
        guard let (msgIdx, previewIdx) = indices(messageID: messageID, previewID: previewID) else { return }
        messages[msgIdx].calendarEventPreviews[previewIdx].state = .updateCancelled
        messages[msgIdx].calendarEventPreviews[previewIdx].pendingUpdate = nil
        hapticService.impact(.light)
    }
}

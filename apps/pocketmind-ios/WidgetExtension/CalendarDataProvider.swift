import EventKit
import Foundation

/// Provides calendar data for widgets without requiring main app dependencies
final class CalendarDataProvider: @unchecked Sendable {
    private let eventStore = EKEventStore()

    func fetchWidgetData() async -> (nextEvent: EventSummary?, freeSlots: [FreeSlotSummary], dayEvents: [EventSummary]) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else {
            return (nil, [], [])
        }

        let now = Date.now
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now

        // Fetch today's events
        let todayPredicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let todayEvents = eventStore.events(matching: todayPredicate)
            .filter { !$0.isAllDay || $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }

        // Find next event (today or within next 7 days)
        let weekPredicate = eventStore.predicateForEvents(withStart: now, end: weekFromNow, calendars: nil)
        let upcomingEvents = eventStore.events(matching: weekPredicate)
            .filter { $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }

        let nextEvent = upcomingEvents.first.map { mapEvent($0) }

        // Calculate free slots for today
        let freeSlots = calculateFreeSlots(
            events: todayEvents,
            start: now,
            end: endOfDay
        )

        // Map today's events for full day view
        let dayEvents = todayEvents.map { mapEvent($0) }

        return (nextEvent, freeSlots, dayEvents)
    }

    private func mapEvent(_ event: EKEvent) -> EventSummary {
        EventSummary(
            id: event.eventIdentifier,
            title: event.title ?? "Untitled",
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            isAllDay: event.isAllDay
        )
    }

    private func calculateFreeSlots(events: [EKEvent], start: Date, end: Date) -> [FreeSlotSummary] {
        let calendar = Calendar.current
        let workDayStart = 9  // 9 AM
        let workDayEnd = 17   // 5 PM

        // Get work day boundaries
        var cursor = max(start, calendar.date(bySettingHour: workDayStart, minute: 0, second: 0, of: start) ?? start)
        let workEnd = calendar.date(bySettingHour: workDayEnd, minute: 0, second: 0, of: start) ?? end
        let searchEnd = min(end, workEnd)

        var freeSlots: [FreeSlotSummary] = []
        let sortedEvents = events.filter { !$0.isAllDay }.sorted { $0.startDate < $1.startDate }

        for event in sortedEvents {
            if cursor < event.startDate && cursor < searchEnd {
                let slotEnd = min(event.startDate, searchEnd)
                let duration = slotEnd.timeIntervalSince(cursor)

                // Only include slots >= 15 minutes
                if duration >= 900 {
                    freeSlots.append(FreeSlotSummary(startDate: cursor, endDate: slotEnd))
                }
            }
            cursor = max(cursor, event.endDate)
        }

        // Add remaining time until end of work day
        if cursor < searchEnd {
            let duration = searchEnd.timeIntervalSince(cursor)
            if duration >= 900 {
                freeSlots.append(FreeSlotSummary(startDate: cursor, endDate: searchEnd))
            }
        }

        return freeSlots
    }
}

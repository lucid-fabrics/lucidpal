import WidgetKit
import SwiftUI

struct PocketMindWidgetProvider: TimelineProvider, Sendable {
    private let dataProvider = CalendarDataProvider()

    func placeholder(in context: Context) -> PocketMindWidgetEntry {
        PocketMindWidgetEntry(
            date: Date.now,
            nextEvent: EventSummary(
                id: "placeholder",
                title: "Team Standup",
                startDate: Date.now.addingTimeInterval(1800),
                endDate: Date.now.addingTimeInterval(3600),
                location: "Conference Room A",
                isAllDay: false
            ),
            freeSlots: [
                FreeSlotSummary(
                    startDate: Date.now,
                    endDate: Date.now.addingTimeInterval(3600)
                )
            ],
            dayEvents: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PocketMindWidgetEntry) -> Void) {
        Task {
            if context.isPreview {
                completion(placeholder(in: context))
            } else {
                let (nextEvent, freeSlots, dayEvents) = await dataProvider.fetchWidgetData()
                let entry = PocketMindWidgetEntry(
                    date: Date.now,
                    nextEvent: nextEvent,
                    freeSlots: freeSlots,
                    dayEvents: dayEvents
                )
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PocketMindWidgetEntry>) -> Void) {
        Task {
            let (nextEvent, freeSlots, dayEvents) = await dataProvider.fetchWidgetData()
            let currentDate = Date.now
            let entry = PocketMindWidgetEntry(
                date: currentDate,
                nextEvent: nextEvent,
                freeSlots: freeSlots,
                dayEvents: dayEvents
            )

            // Refresh timeline when next event starts or every 15 minutes
            let refreshDate: Date
            if let next = nextEvent, next.startDate > currentDate {
                refreshDate = next.startDate
            } else {
                refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
            }

            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

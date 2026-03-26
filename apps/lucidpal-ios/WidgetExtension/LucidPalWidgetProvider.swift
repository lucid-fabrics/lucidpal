import SwiftUI
import WidgetKit

struct LucidPalWidgetProvider: TimelineProvider, Sendable {
    private let dataProvider = CalendarDataProvider()

    func placeholder(in context: Context) -> LucidPalWidgetEntry {
        LucidPalWidgetEntry(
            date: Date.now,
            nextEvent: EventSummary(
                id: "placeholder",
                title: "Team Standup",
                startDate: Date.now.addingTimeInterval(1800),
                endDate: Date.now.addingTimeInterval(WidgetConstants.oneHourSeconds),
                location: "Conference Room A",
                isAllDay: false
            ),
            freeSlots: [
                FreeSlotSummary(
                    startDate: Date.now,
                    endDate: Date.now.addingTimeInterval(WidgetConstants.oneHourSeconds)
                )
            ],
            dayEvents: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LucidPalWidgetEntry) -> Void) {
        let isPreview = context.isPreview
        let placeholderEntry = placeholder(in: context)
        Task { @Sendable in
            if isPreview {
                completion(placeholderEntry)
            } else {
                let (nextEvent, freeSlots, dayEvents) = await dataProvider.fetchWidgetData()
                let entry = LucidPalWidgetEntry(
                    date: Date.now,
                    nextEvent: nextEvent,
                    freeSlots: freeSlots,
                    dayEvents: dayEvents
                )
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LucidPalWidgetEntry>) -> Void) {
        Task { @Sendable in
            let (nextEvent, freeSlots, dayEvents) = await dataProvider.fetchWidgetData()
            let currentDate = Date.now
            let entry = LucidPalWidgetEntry(
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
                // swiftlint:disable:next line_length
                refreshDate = Calendar.current.date(byAdding: .minute, value: WidgetConstants.refreshIntervalMinutes, to: currentDate) ?? currentDate.addingTimeInterval(WidgetConstants.fifteenMinutesSeconds)
            }

            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

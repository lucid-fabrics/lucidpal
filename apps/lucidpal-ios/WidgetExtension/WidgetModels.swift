import Foundation
import WidgetKit

// MARK: - Widget Timeline Entry

struct LucidPalWidgetEntry: TimelineEntry {
    let date: Date
    let nextEvent: EventSummary?
    let freeSlots: [FreeSlotSummary]
    let dayEvents: [EventSummary]
}

// MARK: - Event Summary

struct EventSummary: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool

    var timeUntil: TimeInterval {
        startDate.timeIntervalSince(Date.now)
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var countdownText: String {
        let minutes = Int(timeUntil / 60)
        if minutes < 0 {
            return "Now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours)h"
        } else {
            let days = minutes / 1440
            return "\(days)d"
        }
    }

    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if isAllDay {
            return "All day"
        }

        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }
}

// MARK: - Free Slot Summary

struct FreeSlotSummary: Identifiable, Hashable {
    let id = UUID()
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    var durationText: String {
        if durationMinutes < 60 {
            return "\(durationMinutes)m"
        } else {
            let hours = durationMinutes / 60
            let mins = durationMinutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Widget Configuration

enum WidgetSize {
    case small
    case medium
    case large
}

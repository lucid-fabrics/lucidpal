import SwiftUI

/// Shared design tokens for card layouts, spacing, and typography.
/// Use these instead of inline literals to keep the UI consistent and auditable.
enum DesignConstants {

    // MARK: - Corner Radii
    enum CornerRadius {
        /// Standard card corner radius (event cards, result cards, bulk bars)
        static let card: CGFloat = 12
        /// Date badge corner radius
        static let badge: CGFloat = 8
        /// Chat bubble corner radius
        static let bubble: CGFloat = 18
        /// Compact badge corner radius (free slot cards)
        static let compactBadge: CGFloat = 7
    }

    // MARK: - Padding
    enum Padding {
        /// Standard card internal padding
        static let card: CGFloat = 10
        /// Standard card horizontal padding (larger cards)
        static let cardHorizontal: CGFloat = 12
        /// Bubble horizontal padding
        static let bubbleHorizontal: CGFloat = 14
        /// Bubble vertical padding
        static let bubbleVertical: CGFloat = 10
        /// Row vertical padding (action buttons in cards)
        static let rowVertical: CGFloat = 10
        /// Slot row vertical padding
        static let slotRowVertical: CGFloat = 8
        /// Timestamp horizontal padding
        static let timestamp: CGFloat = 6
        /// Message container horizontal padding
        static let messageHorizontal: CGFloat = 12
    }

    // MARK: - Sizes
    enum Size {
        /// Date badge width (CalendarEventCard)
        static let dateBadgeWidth: CGFloat = 44
        /// Free slot badge width (CalendarQueryResultCard)
        static let slotBadgeWidth: CGFloat = 40
        /// Divider height in button rows
        static let dividerHeight: CGFloat = 36
        /// Minimum spacer length for message alignment
        static let messageSpacer: CGFloat = 60
    }

    // MARK: - Opacity
    enum Opacity {
        /// Dimmed card opacity (deleted events)
        static let dimmed: CGFloat = 0.85
        /// Very dimmed card opacity (cancelled events)
        static let verDimmed: CGFloat = 0.6
        /// Conflict/warning overlay opacity
        static let conflictBorder: CGFloat = 0.3
        /// Update highlight border opacity
        static let updateBorder: CGFloat = 0.3
        /// Free slot border opacity
        static let slotBorder: CGFloat = 0.25
    }

    // MARK: - Font Sizes
    enum FontSize {
        /// Month label in date badge (CalendarEventCard)
        static let monthBadge: CGFloat = 9
        /// Day number in date badge
        static let dayBadge: CGFloat = 20
        /// Slot day number in free-slot badge
        static let slotDayBadge: CGFloat = 18
        /// Tiny icon size (mappin, bell, repeat icons)
        static let tinyIcon: CGFloat = 8
        /// Micro icon size (arrow.right diff row)
        static let microIcon: CGFloat = 7
    }
}

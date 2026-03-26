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
        /// Chat bubble corner radius (standalone or first/last in group)
        static let bubble: CGFloat = 18
        /// Chat bubble corner radius for grouped (inner) edges
        static let bubbleGrouped: CGFloat = 6
        /// Compact badge corner radius (free slot cards)
        static let compactBadge: CGFloat = 7
        /// Input bar pill corner radius
        static let inputBar: CGFloat = 24
        /// Code block corner radius
        static let codeBlock: CGFloat = 10
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

    // MARK: - Shadows
    enum Shadow {
        static let cardColor = Color.black.opacity(0.06)
        static let cardRadius: CGFloat = 4
        static let cardY: CGFloat = 2

        static let floatingColor = Color.black.opacity(0.1)
        static let floatingRadius: CGFloat = 8
        static let floatingY: CGFloat = 4

        static let overlayColor = Color.black.opacity(0.15)
        static let overlayRadius: CGFloat = 16
        static let overlayY: CGFloat = 8
    }

    // MARK: - Animations
    enum Anim {
        static let messageFadeIn: Animation = .spring(duration: 0.35, bounce: 0.15)
        static let sendBounce: Animation = .spring(response: 0.2, dampingFraction: 0.6)
        static let pillEntrance: Animation = .spring(duration: 0.3)
        static let glowFade: Animation = .easeOut(duration: 0.6)
        static let emptyEntrance: Animation = .spring(duration: 0.5, bounce: 0.2)
    }

    // MARK: - Message Grouping
    enum Grouping {
        /// Spacing between consecutive same-role messages
        static let intraGroupSpacing: CGFloat = 2
        /// Spacing between different-role message groups
        static let interGroupSpacing: CGFloat = 12
    }

    // MARK: - Bubble Gradients
    enum BubbleStyle {
        /// User bubble gradient stops
        static let userGradientTop = Color.accentColor
        static let userGradientBottom = Color.accentColor.opacity(0.85)
        /// User bubble shadow
        static let userShadowColor = Color.accentColor.opacity(0.2)
        static let userShadowRadius: CGFloat = 8
        static let userShadowY: CGFloat = 3
        /// Assistant avatar size
        static let avatarSize: CGFloat = 22
    }

    // MARK: - Thresholds
    enum Threshold {
        /// Distance from bottom (in points) to consider scroll "near bottom"
        static let scrollNearBottom: CGFloat = 150
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

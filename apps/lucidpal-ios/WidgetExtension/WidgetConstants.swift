import Foundation

enum WidgetConstants {
    /// Seconds in one hour — used for timeline entry end date.
    static let oneHourSeconds: TimeInterval = 3600
    /// Seconds in fifteen minutes — used for stale-data buffer.
    static let fifteenMinutesSeconds: TimeInterval = 900
    /// Refresh interval in minutes for the widget timeline.
    static let refreshIntervalMinutes = 15
}

import Foundation

// MARK: - Constants

enum ChatConstants {
    /// RAM threshold (GB) for selecting higher history/context limits.
    static let largeContextRAMThresholdGB = 6
    /// Max messages fed into the prompt on high-RAM devices.
    static let largeHistoryLimit = 50
    /// Max messages fed into the prompt on low-RAM devices.
    static let smallHistoryLimit = 20
    /// Seconds to debounce before persisting messages to disk.
    static let persistenceDebounceSeconds: Double = 3
    /// Seconds before auto-dismissing the error banner.
    static let errorAutoDismissSeconds: Double = 5
    /// Maximum character length for auto-generated session titles.
    static let maxSessionTitleLength = 40
    /// Bytes in one gigabyte — used for RAM-based context sizing.
    static let bytesPerGB: UInt64 = 1_073_741_824
    /// Seconds in one hour — used for calendar slot duration calculations.
    static let secondsPerHour: TimeInterval = 3600
    /// Maximum duration (hours) used when searching for a free calendar slot.
    static let maxSlotSearchHours: TimeInterval = 4
    /// Duration (hours) used for all-day event slot searches.
    static let allDaySlotSearchHours: TimeInterval = 2
}

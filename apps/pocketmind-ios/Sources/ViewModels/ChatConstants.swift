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
}

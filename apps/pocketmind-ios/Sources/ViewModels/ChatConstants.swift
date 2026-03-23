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
    /// Delay (ms) before auto-starting voice recording on ChatView appear.
    static let voiceAutoStartDelayMilliseconds: Int = 300
    /// Minutes per hour — used for event proximity thresholds.
    static let minutesPerHour: Int = 60
    /// Seconds in one minute — used for converting reminder minutes to EKAlarm offsets.
    static let secondsPerMinute: Int = 60
    /// Opening tag emitted by Qwen3 models before their reasoning trace.
    static let thinkOpenTag = "<think>"
    /// Closing tag emitted by Qwen3 models after their reasoning trace.
    static let thinkCloseTag = "</think>"
    /// Default LLM context window size (tokens) on low-RAM devices.
    static let defaultContextSizeTokens = 4096
    /// Maximum LLM context window size (tokens) on high-RAM devices (≥ largeContextRAMThresholdGB).
    static let largeContextSizeTokens = 8192
    /// Delay (ms) before resuming AirPods auto-voice after an audio interruption ends.
    static let airPodsAutoResumeDelayMilliseconds: Int = 500
    /// Max characters to display for an event title in hints and suggested prompts.
    static let eventTitlePreviewLength: Int = 20
    /// Max characters shown in the session list last-message preview.
    static let sessionPreviewLength: Int = 120
    /// Max characters logged for synthesis output previews.
    static let synthesisLogPreviewLength: Int = 100
    /// Max characters logged for raw LLM output previews.
    static let rawLogPreviewLength: Int = 200
    /// Hour (24h) marking the end of the work day — used as the upper bound for free-slot search.
    static let defaultWorkdayEndHour: Int = 20
}

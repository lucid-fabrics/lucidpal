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
    /// Hour (24h) at which evening begins — used for time-of-day prompt selection.
    static let eveningStartHour: Int = 17
    /// Hour (24h) before which it is considered morning — used for time-of-day prompt selection.
    static let morningEndHour: Int = 12
    /// Minutes threshold below which an event is considered "starting now".
    static let eventStartingNowMinutes: Int = 5
    /// Maximum token buffer size for llama tokenization.
    static let maxTokenBufferSize: Int = 65_536
    /// Minimum audio recording file size (bytes) to consider valid (~0.5s at 16kHz 16-bit mono).
    static let minimumRecordingFileSize: UInt64 = 16_000
    /// HTTP status code range indicating a successful response.
    static let httpSuccessRange: Range<Int> = 200..<300
    /// Seconds the "copied" toast is shown before auto-dismissing.
    static let toastDisplaySeconds: Double = 1.5
    /// Seconds between generating-phrase rotations in the status indicator.
    static let generatingPhraseIntervalSeconds: Double = 4.5
    /// Nanoseconds to wait before resetting the photo picker selection.
    static let photoPickerResetDelayNanoseconds: UInt64 = 100_000_000
}

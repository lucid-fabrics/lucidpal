import Foundation

enum CalendarError: LocalizedError {
    case notAuthorized
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Calendar access is not authorized. Enable it in Settings."
        case .eventNotFound: return "The event could not be found in your calendar."
        }
    }
}

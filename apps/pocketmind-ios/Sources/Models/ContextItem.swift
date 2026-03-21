import Foundation

/// Represents a single context item from Notes, Reminders, or Mail.
struct ContextItem: Identifiable {
    let id: String
    let source: ContextSource
    let title: String
    let content: String?
    let date: Date?
    let metadata: [String: String]

    enum ContextSource: String {
        case notes = "Notes"
        case reminders = "Reminders"
        case mail = "Mail"
    }
}

extension ContextItem {
    /// Formats the item for LLM context injection.
    func formatted() -> String {
        var parts: [String] = ["[\(source.rawValue)]"]
        parts.append(title)
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append("(\(formatter.string(from: date)))")
        }
        if let content = content, !content.isEmpty {
            parts.append("- \(content)")
        }
        return parts.joined(separator: " ")
    }
}

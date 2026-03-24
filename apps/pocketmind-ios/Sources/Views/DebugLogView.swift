import SwiftUI
import UIKit

struct DebugLogView: View {

    @ObservedObject private var store = DebugLogStore.shared
    @State private var filterCategory: String = "All"
    @State private var filterLevel: DebugLogStore.Entry.Level? = nil
    @State private var searchText = ""
    @State private var copiedToast = false

    private var categories: [String] {
        let cats = Set(store.entries.map(\.category))
        return ["All"] + cats.sorted()
    }

    private var filtered: [DebugLogStore.Entry] {
        store.entries.filter { entry in
            (filterCategory == "All" || entry.category == filterCategory) &&
            (filterLevel == nil || entry.level == filterLevel) &&
            (searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView("No Logs", systemImage: "doc.text.magnifyingglass",
                    description: Text("Send a message or change filters."))
            } else {
                ForEach(filtered.reversed()) { entry in
                    entryRow(entry)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .animation(.easeOut(duration: 0.25), value: filtered.count)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search messages")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Category", selection: $filterCategory) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    Divider()
                    Picker("Level", selection: $filterLevel) {
                        Text("All levels").tag(Optional<DebugLogStore.Entry.Level>.none)
                        ForEach(DebugLogStore.Entry.Level.allCases, id: \.self) { level in
                            Text(level.emoji + " " + level.rawValue).tag(Optional(level))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let text = filtered.reversed().map { e in
                        "[\(e.date.formatted(.dateTime))] [\(e.category)] [\(e.level.rawValue)] \(e.message)"
                    }.joined(separator: "\n")
                    UIPasteboard.general.string = text
                    copiedToast = true
                    Task { try? await Task.sleep(for: .seconds(ChatConstants.toastDisplaySeconds)); copiedToast = false }
                } label: {
                    Image(systemName: copiedToast ? "checkmark" : "doc.on.doc")
                }
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.clear()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: DebugLogStore.Entry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entry.level.emoji)
                    .font(.caption2)
                Text(entry.category)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(categoryColor(entry.category))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "LLM":      return .blue
        case "Chat":     return .purple
        case "Search":   return .orange
        case "Calendar": return .green
        case "Location": return .teal
        default:         return .secondary
        }
    }
}

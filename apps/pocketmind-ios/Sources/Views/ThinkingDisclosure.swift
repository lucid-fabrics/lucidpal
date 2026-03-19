import SwiftUI

// MARK: - Thinking disclosure

struct ThinkingDisclosure: View {
    let content: String
    let isThinking: Bool      // still streaming
    @Binding var isExpanded: Bool
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !isThinking {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .opacity(isThinking ? (pulse ? 0.4 : 1.0) : 1.0)
                        .animation(isThinking ? .easeInOut(duration: 0.8).repeatForever() : .default, value: pulse)
                    Text(isThinking ? "Thinking..." : (isExpanded ? "Hide thinking" : "Thought for a moment"))
                        .font(.caption)
                    Spacer()
                    if !isThinking {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
                .padding(.vertical, DesignConstants.Padding.slotRowVertical)
            }
            .buttonStyle(.plain)
            .onAppear { if isThinking { pulse = true } }
            .onChange(of: isThinking) { _, thinking in pulse = thinking }

            if isExpanded && !isThinking {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignConstants.Padding.cardHorizontal)
                    .padding(.bottom, DesignConstants.Padding.slotRowVertical)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
    }
}

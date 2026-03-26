import SwiftUI

struct SuggestedPromptsView: View {
    let prompts: [String]
    let isLoading: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isLoading {
                ForEach(0..<4, id: \.self) { i in
                    SkeletonChip(delay: Double(i) * 0.15)
                }
            } else {
                ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                    PromptChip(text: prompt, delay: Double(index) * 0.08) {
                        onSelect(prompt)
                    }
                }
            }
        }
    }
}

// MARK: - Real chip

private struct PromptChip: View {
    let text: String
    let delay: Double
    let action: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(PromptChipPressStyle())
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.3).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Prompt Chip Press Style

private struct PromptChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Skeleton chip

private struct SkeletonChip: View {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(shimmerGradient)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.2).delay(delay)) { appeared = true }
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false).delay(delay)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray5), Color(.systemGray4), Color(.systemGray5)],
            startPoint: UnitPoint(x: phase - 0.6, y: 0.5),
            endPoint: UnitPoint(x: phase + 0.6, y: 0.5)
        )
    }
}

import SwiftUI

// MARK: - Mic button label

private enum VoiceRingConstants {
    static let ring1Scale: CGFloat = 1.5
    static let ring2Scale: CGFloat = 1.7
    static let animationDuration: Double = 0.9
    static let ring2Delay: Double = 0.3
}

struct MicButtonLabel: View {
    let isRecording: Bool
    let isTranscribing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring1Scale: CGFloat = 1
    @State private var ring2Scale: CGFloat = 1

    var body: some View {
        ZStack {
            if isTranscribing {
                // Spinning arc while WhisperKit processes
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(reduceMotion ? 0 : ring1Scale * 360))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            ring1Scale = 1
                        }
                    }
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
            } else {
                if isRecording && !reduceMotion {
                    Circle()
                        .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                        .scaleEffect(ring1Scale)
                    Circle()
                        .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                        .scaleEffect(ring2Scale)
                }
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 22))
                    .foregroundStyle(isRecording ? .red : Color(.systemGray))
            }
        }
        .frame(width: 40, height: 40)
        .onChange(of: isRecording) { _, recording in
            guard !reduceMotion else { return }
            if recording {
                // swiftlint:disable line_length
                withAnimation(.easeInOut(duration: VoiceRingConstants.animationDuration).repeatForever(autoreverses: true)) { ring1Scale = VoiceRingConstants.ring1Scale }
                withAnimation(.easeInOut(duration: VoiceRingConstants.animationDuration).delay(VoiceRingConstants.ring2Delay).repeatForever(autoreverses: true)) { ring2Scale = VoiceRingConstants.ring2Scale }
                // swiftlint:enable line_length
            } else {
                ring1Scale = 1
                ring2Scale = 1
            }
        }
        .onAppear {
            guard isRecording && !reduceMotion else { return }
            // swiftlint:disable line_length
            withAnimation(.easeInOut(duration: VoiceRingConstants.animationDuration).repeatForever(autoreverses: true)) { ring1Scale = VoiceRingConstants.ring1Scale }
            withAnimation(.easeInOut(duration: VoiceRingConstants.animationDuration).delay(VoiceRingConstants.ring2Delay).repeatForever(autoreverses: true)) { ring2Scale = VoiceRingConstants.ring2Scale }
            // swiftlint:enable line_length
        }
    }
}

// MARK: - Date separator

struct DateSeparatorView: View {
    let date: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

// MARK: - Voice readiness

struct VoiceReadiness: Equatable {
    let modelLoaded: Bool
    let speechAvailable: Bool
}

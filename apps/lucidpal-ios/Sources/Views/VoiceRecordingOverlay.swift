import SwiftUI

// MARK: - Animation Constants

private enum VoiceOverlayAnim {
    // State transition springs
    static let stateTransitionDuration: Double = 0.4
    static let containerSpringDuration: Double = 0.35
    // Label easing
    static let stateLabelDuration: Double = 0.2
    static let transcriptLabelDuration: Double = 0.15
    // Listening pulse durations
    static let pulseDuration: Double = 0.9
    static let ring1Duration: Double = 1.2
    static let ring1Delay: Double = 0.1
    static let ring2Duration: Double = 1.5
    static let ring2Delay: Double = 0.25
    // Listening pulse animation targets
    static let pulseTargetScale: CGFloat = 1.08
    static let ring1TargetScale: CGFloat = 1.18
    static let ring1TargetOpacity: Double = 0.15
    static let ring2TargetScale: CGFloat = 1.32
    static let ring2TargetOpacity: Double = 0.08
    // Waveform bars
    static let barDurations: [Double] = [0.5, 0.4, 0.6, 0.4, 0.5]
    static let barDelays: [Double]    = [0.0, 0.1, 0.2, 0.3, 0.4]
}

struct VoiceRecordingOverlay: View {
    let transcript: String
    let isTranscribing: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Listening animation
    @State private var pulseScale: CGFloat = 1.0
    @State private var ring1Scale: CGFloat = 1.0
    @State private var ring2Scale: CGFloat = 1.0
    @State private var ring1Opacity: Double = 0.4
    @State private var ring2Opacity: Double = 0.25

    // Processing animation — 5 waveform bars
    @State private var barHeights: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.accentColor.opacity(0.08), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // Central visual — swaps between listening and processing
                ZStack {
                    listeningVisual
                        .opacity(isTranscribing ? 0 : 1)
                        .scaleEffect(isTranscribing ? 0.8 : 1)

                    processingVisual
                        .opacity(isTranscribing ? 1 : 0)
                        .scaleEffect(isTranscribing ? 1 : 0.8)
                }
                .animation(.spring(duration: VoiceOverlayAnim.stateTransitionDuration), value: isTranscribing)

                // Label area
                transcriptLabel
                    .frame(minHeight: 72)
                    .animation(.easeInOut(duration: VoiceOverlayAnim.stateLabelDuration), value: isTranscribing)
                    .animation(.easeInOut(duration: VoiceOverlayAnim.transcriptLabelDuration), value: transcript)

                Spacer()

                // Action buttons — hidden while transcribing
                if !isTranscribing {
                    actionButtons
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.bottom, 48)
            .animation(.spring(duration: VoiceOverlayAnim.containerSpringDuration), value: isTranscribing)
        }
        .onAppear { startListeningAnimation() }
        .onChange(of: isTranscribing) { _, transcribing in
            if transcribing { startProcessingAnimation() }
        }
    }

    // MARK: - Listening visual (pulsing mic)

    private var listeningVisual: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(ring2Opacity))
                .frame(width: 120, height: 120)
                .scaleEffect(ring2Scale)

            Circle()
                .fill(Color.accentColor.opacity(ring1Opacity))
                .frame(width: 96, height: 96)
                .scaleEffect(ring1Scale)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 72, height: 72)
                .scaleEffect(pulseScale)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
        }
    }

    // MARK: - Processing visual (waveform bars)

    private var processingVisual: some View {
        HStack(alignment: .center, spacing: 5) {
            ForEach(barHeights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 48 * barHeights[i])
            }
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Transcript label

    @ViewBuilder
    private var transcriptLabel: some View {
        if isTranscribing {
            Text("Processing…")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else if transcript.isEmpty {
            Text("Listening…")
                .font(.title3)
                .foregroundStyle(.secondary)
        } else {
            Text(transcript)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .padding(.horizontal, 32)
                .transition(.opacity)
        }
    }

    // MARK: - Action buttons (cancel / confirm)

    private var actionButtons: some View {
        HStack(spacing: 24) {
            // Cancel — discard the recording
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGray5), in: Circle())
            }
            .accessibilityLabel("Cancel recording")

            // Confirm — accept the transcript
            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
            }
            .accessibilityLabel("Confirm recording")
        }
    }

    // MARK: - Animations

    private func startListeningAnimation() {
        guard !reduceMotion, !isTranscribing else { return }
        withAnimation(.easeInOut(duration: VoiceOverlayAnim.pulseDuration).repeatForever(autoreverses: true)) {
            pulseScale = VoiceOverlayAnim.pulseTargetScale
        }
        withAnimation(.easeInOut(duration: VoiceOverlayAnim.ring1Duration).repeatForever(autoreverses: true).delay(VoiceOverlayAnim.ring1Delay)) {
            ring1Scale = VoiceOverlayAnim.ring1TargetScale
            ring1Opacity = VoiceOverlayAnim.ring1TargetOpacity
        }
        withAnimation(.easeInOut(duration: VoiceOverlayAnim.ring2Duration).repeatForever(autoreverses: true).delay(VoiceOverlayAnim.ring2Delay)) {
            ring2Scale = VoiceOverlayAnim.ring2TargetScale
            ring2Opacity = VoiceOverlayAnim.ring2TargetOpacity
        }
    }

    private func startProcessingAnimation() {
        guard !reduceMotion else { return }
        let durations = VoiceOverlayAnim.barDurations
        let delays    = VoiceOverlayAnim.barDelays
        for i in barHeights.indices {
            withAnimation(
                .easeInOut(duration: durations[i])
                .repeatForever(autoreverses: true)
                .delay(delays[i])
            ) {
                barHeights[i] = i.isMultiple(of: 2) ? 1.0 : 0.5
            }
        }
    }
}

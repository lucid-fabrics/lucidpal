import SwiftUI
import UIKit

struct OnboardingCarouselView: View {
    @ObservedObject var downloadViewModel: ModelDownloadViewModel
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let infoPages: [OnboardingPage] = [
        OnboardingPage(
            primaryIcon: "iphone.gen3",
            orbitIcons: ["lock.shield.fill", "cpu.fill", "brain.head.profile"],
            iconColor: .blue,
            title: "Fully On-Device",
            subtitle: "Private by design",
            body: "All AI runs directly on your iPhone.\nNo cloud. No accounts. Your data never leaves."
        ),
        OnboardingPage(
            primaryIcon: "calendar.badge.clock",
            orbitIcons: ["plus.circle.fill", "pencil.circle.fill", "magnifyingglass.circle.fill"],
            iconColor: .orange,
            title: "Calendar Intelligence",
            subtitle: "Your schedule, understood",
            body: "Create, rename, reschedule, or find events.\nLucidPal reads and writes your calendar."
        ),
        OnboardingPage(
            primaryIcon: "mic.badge.plus",
            orbitIcons: ["waveform.circle.fill", "text.bubble.fill", "hand.raised.fingers.spread.fill"],
            iconColor: .purple,
            title: "Type or Speak",
            subtitle: "Hands-free ready",
            body: "Tap the mic or just type.\nAsk LucidPal anything — even through Siri."
        ),
    ]

    private var totalPages: Int { Self.infoPages.count + 1 }
    private var isLastPage: Bool { currentPage == totalPages - 1 }
    private var currentColor: Color {
        currentPage < Self.infoPages.count ? Self.infoPages[currentPage].iconColor : .accentColor
    }

    var body: some View {
        ZStack {
            ambientBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: skip jumps to model selection, hidden on last page
                HStack {
                    Spacer()
                    if !isLastPage {
                        Button {
                            if reduceMotion {
                                currentPage = totalPages - 1
                            } else {
                                withAnimation(.spring(duration: 0.45, bounce: 0.1)) {
                                    currentPage = totalPages - 1
                                }
                            }
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(height: 44)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: currentPage)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(Self.infoPages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, pageIndex: index, currentPage: currentPage)
                            .tag(index)
                    }
                    ModelSelectionPageView(downloadViewModel: downloadViewModel)
                        .tag(Self.infoPages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .none : .spring(duration: 0.45, bounce: 0.1), value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 28) {
            progressBar

            Button {
                if !isLastPage {
                    // Skip impact on last page — handleGetStarted fires notification haptic instead.
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.prepare()
                    impact.impactOccurred()
                    let next = min(currentPage + 1, totalPages - 1)
                    if reduceMotion {
                        currentPage = next
                    } else {
                        withAnimation(.spring(duration: 0.45, bounce: 0.15)) { currentPage = next }
                    }
                } else {
                    handleGetStarted()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(ctaLabel)
                        .contentTransition(.interpolate)
                    Image(systemName: isLastPage ? "sparkles" : "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [currentColor, currentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: currentColor.opacity(0.3), radius: 16, y: 6)
            }
            .buttonStyle(OnboardingButtonStyle())
            .accessibilityLabel(ctaLabel)
            .padding(.horizontal, 32)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentPage)
        }
    }

    private var isActivelyDownloading: Bool {
        if case .downloading = downloadViewModel.downloadState { return true }
        return false
    }

    private var ctaLabel: String {
        guard isLastPage else { return "Continue" }
        if downloadViewModel.selectedModel.isDownloaded { return "Get Started" }
        // Download running in background — label reflects that user can proceed now.
        if isActivelyDownloading { return "Continue to App" }
        return "Download & Get Started"
    }

    private func handleGetStarted() {
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)
        // Guard against swipe-back re-tap firing a duplicate download.
        // Also guard against empty model list (no valid model to download).
        if !downloadViewModel.availableModels.isEmpty,
           !downloadViewModel.selectedModel.isDownloaded,
           !isActivelyDownloading {
            downloadViewModel.startDownload()
        }
        if reduceMotion {
            hasCompletedOnboarding = true
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                hasCompletedOnboarding = true
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        // scaleEffect avoids GeometryReader entirely, eliminating the layout-loop
        // risk that arises from animating a width computed inside GeometryReader.
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(.systemGray5))
            Capsule()
                .fill(currentColor)
                .scaleEffect(
                    x: CGFloat(currentPage + 1) / CGFloat(totalPages),
                    anchor: .leading
                )
        }
        .frame(height: 4)
        .padding(.horizontal, 64)
        .animation(reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.15), value: currentPage)
        .accessibilityLabel("Step \(currentPage + 1) of \(totalPages)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Ambient background

    private var ambientBackground: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [
                    currentColor.opacity(0.1),
                    currentColor.opacity(0.04),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 30,
                endRadius: 450
            )
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.5), value: currentPage)
        }
    }
}

// MARK: - Model Selection Page

private struct ModelSelectionPageView: View {
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    private var recommendedModel: ModelInfo? {
        let recommended = ModelInfo.recommended(physicalRAMGB: downloadViewModel.deviceRAMGB)
        // Only return if present in the visible list — avoids badge/footer mismatch
        return downloadViewModel.availableModels.first(where: { $0.id == recommended.id })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Central icon (matches info page style)
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 130, height: 130)
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 100, height: 100)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .symbolRenderingMode(.hierarchical)
                }

                Spacer(minLength: 28)

                Text("DOWNLOAD ONCE · WORKS OFFLINE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.8))
                    .tracking(1.5)

                Text("Choose Your AI")
                    .font(.largeTitle.bold())
                    .padding(.top, 6)

                Spacer(minLength: 28)

                if downloadViewModel.availableModels.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("No models available for this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else {
                    VStack(spacing: 8) {
                        ForEach(downloadViewModel.availableModels) { model in
                            ModelRowButton(
                                model: model,
                                isSelected: downloadViewModel.selectedModel.id == model.id,
                                isRecommended: model.id == recommendedModel?.id
                            ) {
                                downloadViewModel.selectModel(model)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 16)

                if let rec = recommendedModel {
                    Text("Recommended for your device: \(rec.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

private struct ModelRowButton: View {
    let model: ModelInfo
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sizeLabel: String { String(format: "%.1f GB", model.fileSizeGB) }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.systemGray4))
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel("\(model.displayName), \(sizeLabel)\(model.isDownloaded ? ", Downloaded" : "")\(isRecommended ? ", Recommended" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Button style

private struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Page model

private struct OnboardingPage: Identifiable {
    let primaryIcon: String
    let orbitIcons: [String]
    let iconColor: Color
    let title: String
    let subtitle: String
    let body: String

    var id: String { primaryIcon }
}

// MARK: - Single page view

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int

    @State private var phase: EntryPhase = .hidden
    @State private var orbiting = false
    @State private var entranceTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum EntryPhase {
        case hidden, icon, text
    }

    private var isActive: Bool { pageIndex == currentPage }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            iconComposition
                .frame(height: 200)

            Spacer().frame(height: 44)

            textContent

            Spacer()
            Spacer()
        }
        .onAppear { animateEntrance() }
        .onChange(of: currentPage) { _, _ in
            if isActive {
                phase = .hidden
                orbiting = false
                animateEntrance()
            } else {
                entranceTask?.cancel()
                entranceTask = nil
                orbiting = false
                phase = .hidden
            }
        }
    }

    private var iconComposition: some View {
        ZStack {
            Circle()
                .strokeBorder(page.iconColor.opacity(0.08), lineWidth: 1)
                .frame(width: 180, height: 180)
                .opacity(phase != .hidden ? 1 : 0)

            ForEach(Array(page.orbitIcons.enumerated()), id: \.element) { index, icon in
                let angle = Angle.degrees(Double(index) * 120 + (orbiting ? 360 : 0))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(page.iconColor.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(page.iconColor.opacity(0.1), in: Circle())
                    .offset(
                        x: 90 * cos(angle.radians),
                        y: 90 * sin(angle.radians)
                    )
                    .opacity(phase != .hidden ? 1 : 0)
                    .animation(
                        reduceMotion ? .none : .easeOut(duration: 0.5).delay(Double(index) * 0.1),
                        value: phase
                    )
                    .accessibilityHidden(true)
            }
            .animation(
                reduceMotion ? nil : .linear(duration: 30).repeatForever(autoreverses: false),
                value: orbiting
            )

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.08))
                    .frame(width: 130, height: 130)

                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 100, height: 100)

                Circle()
                    .strokeBorder(page.iconColor.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 100, height: 100)

                Image(systemName: page.primaryIcon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(page.iconColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .scaleEffect(phase != .hidden ? 1.0 : 0.5)
            .opacity(phase != .hidden ? 1 : 0)
        }
    }

    private var textContent: some View {
        VStack(spacing: 10) {
            Text(page.subtitle.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(page.iconColor.opacity(0.8))
                .tracking(2)
                .opacity(phase == .text ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (phase == .text ? 0 : 8))
                .animation(reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.1), value: phase)

            // .animation(nil) prevents the container spring from propagating into
            // WordRevealText's own per-word animations, which would double-animate.
            WordRevealText(text: page.title, isRevealed: phase == .text)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .animation(nil, value: phase)

            Text(page.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 36)
                .padding(.top, 6)
                .opacity(phase == .text ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (phase == .text ? 0 : 12))
                .animation(reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.1), value: phase)
        }
    }

    private func animateEntrance() {
        guard isActive else { return }
        if reduceMotion {
            phase = .text
            return
        }
        entranceTask?.cancel()
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            phase = .icon
        }
        entranceTask = Task { @MainActor in
            // Delay text phase so .icon renders first — withAnimation(.delay:) only defers
            // the curve, not the state mutation, causing coalescing on the same runloop pass.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.5, bounce: 0.1)) { phase = .text }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            orbiting = true
        }
    }
}

// MARK: - Word-by-word reveal

private struct WordRevealText: View {
    let text: String
    let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        HStack(spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .opacity(isRevealed ? 1 : 0)
                    .offset(y: (reduceMotion || isRevealed) ? 0 : 12)
                    .animation(
                        .spring(duration: 0.4, bounce: 0.15)
                            .delay(reduceMotion ? 0 : Double(index) * 0.06),
                        value: isRevealed
                    )
            }
        }
        // Collapse word fragments into a single VoiceOver announcement
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

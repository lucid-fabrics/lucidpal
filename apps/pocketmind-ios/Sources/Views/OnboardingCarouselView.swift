import SwiftUI
import UIKit

struct OnboardingCarouselView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [OnboardingPage] = [
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
            body: "Create, rename, reschedule, or find events.\nPocketMind reads and writes your calendar."
        ),
        OnboardingPage(
            primaryIcon: "mic.badge.plus",
            orbitIcons: ["waveform.circle.fill", "text.bubble.fill", "hand.raised.fingers.spread.fill"],
            iconColor: .purple,
            title: "Type or Speak",
            subtitle: "Hands-free ready",
            body: "Tap the mic or just type.\nAsk PocketMind anything — even through Siri."
        ),
    ]

    var body: some View {
        ZStack {
            // Ambient gradient that shifts per page
            ambientBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            hasSeenOnboarding = true
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
                .animation(.easeInOut(duration: 0.2), value: currentPage)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, pageIndex: index, currentPage: currentPage)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(duration: 0.45, bounce: 0.1), value: currentPage)

                // Bottom controls
                bottomControls
                    .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: 28) {
            // Progress bar (replaces dots — more intentional feel)
            progressBar

            // CTA button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) { currentPage += 1 }
                } else {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.easeOut(duration: 0.2)) { hasSeenOnboarding = true }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .contentTransition(.interpolate)
                    Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [pages[currentPage].iconColor, pages[currentPage].iconColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: pages[currentPage].iconColor.opacity(0.3), radius: 16, y: 6)
            }
            .buttonStyle(OnboardingButtonStyle())
            .padding(.horizontal, 32)
            .animation(.easeInOut(duration: 0.3), value: currentPage)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let progress = CGFloat(currentPage + 1) / CGFloat(pages.count)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                Capsule()
                    .fill(pages[currentPage].iconColor)
                    .frame(width: totalWidth * progress, height: 4)
                    .animation(.spring(duration: 0.4, bounce: 0.15), value: currentPage)
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 64)
    }

    private var ambientBackground: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [
                    pages[currentPage].iconColor.opacity(0.1),
                    pages[currentPage].iconColor.opacity(0.04),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 30,
                endRadius: 450
            )
            .animation(.easeInOut(duration: 0.5), value: currentPage)
        }
    }
}

// MARK: - Button style

private struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let primaryIcon: String
    let orbitIcons: [String]
    let iconColor: Color
    let title: String
    let subtitle: String
    let body: String
}

// MARK: - Single page view

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int

    @State private var phase: EntryPhase = .hidden
    @State private var orbiting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum EntryPhase {
        case hidden, icon, text
    }

    private var isActive: Bool { pageIndex == currentPage }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated icon composition
            iconComposition
                .frame(height: 200)

            Spacer().frame(height: 44)

            // Text content with staggered word reveal
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
            }
        }
    }

    // MARK: - Icon composition with orbiting elements

    private var iconComposition: some View {
        ZStack {
            // Orbit ring
            Circle()
                .strokeBorder(page.iconColor.opacity(0.08), lineWidth: 1)
                .frame(width: 180, height: 180)
                .opacity(phase != .hidden ? 1 : 0)

            // Orbiting mini icons
            ForEach(Array(page.orbitIcons.enumerated()), id: \.offset) { index, icon in
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
                        reduceMotion
                            ? .easeOut(duration: 0.4).delay(Double(index) * 0.08)
                            : .easeOut(duration: 0.5).delay(Double(index) * 0.1),
                        value: phase
                    )
            }
            .animation(
                reduceMotion ? nil : .linear(duration: 30).repeatForever(autoreverses: false),
                value: orbiting
            )

            // Central icon with glow
            ZStack {
                // Glow ring
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

    // MARK: - Text with staggered reveal

    private var textContent: some View {
        VStack(spacing: 10) {
            // Subtitle
            Text(page.subtitle.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(page.iconColor.opacity(0.8))
                .tracking(2)
                .opacity(phase == .text ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (phase == .text ? 0 : 8))

            // Title — word by word
            WordRevealText(text: page.title, isRevealed: phase == .text)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            // Body
            Text(page.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 36)
                .padding(.top, 6)
                .opacity(phase == .text ? 1 : 0)
                .offset(y: reduceMotion ? 0 : (phase == .text ? 0 : 12))
        }
        .animation(.spring(duration: 0.5, bounce: 0.1), value: phase)
    }

    private func animateEntrance() {
        guard isActive else { return }
        if reduceMotion {
            phase = .text
            return
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            phase = .icon
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.1).delay(0.2)) {
            phase = .text
        }
        // Start orbit after entrance settles
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
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
        let words = text.components(separatedBy: " ")
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
    }
}

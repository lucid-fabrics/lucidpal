import SwiftUI

struct OnboardingCarouselView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "iphone.gen3",
            iconColor: .blue,
            title: "Fully On-Device",
            body: "All AI runs directly on your iPhone. No internet connection, no accounts, no data ever leaves your phone."
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconColor: .orange,
            title: "Calendar Intelligence",
            body: "Ask PocketMind to create, rename, or find events. It reads and writes your calendar with your permission."
        ),
        OnboardingPage(
            icon: "mic.badge.plus",
            iconColor: .purple,
            title: "Type or Speak",
            body: "Send messages by typing or tapping the mic. You can also ask PocketMind questions hands-free through Siri."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            VStack(spacing: 20) {
                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.accentColor : Color(.systemGray4))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 52)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Page model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

// MARK: - Single page view

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(page.iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }
}

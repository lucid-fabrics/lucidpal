import SwiftUI

struct UnsupportedDeviceView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 48

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    compatibleDevicesCard
                    privacyNote
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 140, height: 140)
                Image(systemName: "memorychip")
                    .font(.system(size: heroIconSize, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .padding(.top, 64)

            VStack(spacing: 12) {
                Text("LucidPal needs a\nbit more muscle")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("We built LucidPal around one belief: your thoughts are yours alone.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(
                    "That means running a full AI model entirely on your device — no cloud, no servers, no data leaving your hands. " +
                    "It's genuinely powerful, but it needs room to breathe. LucidPal requires at least 6 GB of RAM, " +
                    "and this iPhone doesn't quite get there."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Compatible Devices Card

    private var compatibleDevicesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(Color.green)
                    .accessibilityHidden(true)
                Text("Runs beautifully on")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 10) {
                deviceRow("iPhone 12 Pro & 12 Pro Max")
                deviceRow("iPhone 13 · 13 mini · 13 Pro · 13 Pro Max")
                deviceRow("iPhone 14 series and later")
                deviceRow("iPhone 15 series and later")
                deviceRow("iPhone 16 series and later")
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The standard iPhone 12 and 12 mini have 4 GB RAM and aren't supported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("Your privacy is still fully protected. Not a single byte about you ever leaves this device — even this screen.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
        }
        .padding(.top, 36)
        .padding(.bottom, 60) // ScrollView safe area handles device-specific insets
    }

    // MARK: - Helpers

    private func deviceRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
                .accessibilityHidden(true)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

#Preview {
    UnsupportedDeviceView()
}

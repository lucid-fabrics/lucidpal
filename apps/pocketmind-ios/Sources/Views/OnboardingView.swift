import SwiftUI

struct OnboardingView: View {
    @ObservedObject var downloadViewModel: ModelDownloadViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 32) {
                        featureList
                        modelStep
                        calendarStep
                        continueButton
                    }
                    .padding(24)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("PocketMind")
                .font(.largeTitle.bold())
            Text("Your on-device AI calendar assistant")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 48)
        .padding(.bottom, 32)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "lock.shield.fill", color: .green,
                       title: "100% Private",
                       detail: "All AI runs locally. Nothing leaves your device.")
            FeatureRow(icon: "calendar", color: .blue,
                       title: "Calendar Aware",
                       detail: "Ask about your schedule in plain English.")
            FeatureRow(icon: "wifi.slash", color: .orange,
                       title: "Works Offline",
                       detail: "No internet needed after the model is downloaded.")
        }
    }

    private var modelStep: some View {
        VStack(spacing: 12) {
            Label("Step 1: Download a Model", systemImage: "arrow.down.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if downloadViewModel.isModelLoaded {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Model loaded and ready.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ModelDownloadView(viewModel: downloadViewModel)
                    .padding(.horizontal, -8)

                // Corrupted model recovery — shown when loadModel() fails after auto-load
                if let error = downloadViewModel.loadError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button("Delete Corrupted File & Retry") {
                            // Clear error BEFORE delete to avoid a race where
                            // deleteModel() triggers a state update while loadError is still set.
                            downloadViewModel.loadError = nil
                            downloadViewModel.deleteModel(downloadViewModel.selectedModel)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)

                        if let deleteError = downloadViewModel.deleteError {
                            Text(deleteError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var calendarStep: some View {
        VStack(spacing: 12) {
            Label("Step 2: Calendar (optional)", systemImage: "calendar.badge.checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if settingsViewModel.isCalendarAuthorized {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Calendar access granted.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button("Allow Calendar Access") {
                    Task { await settingsViewModel.requestCalendarAccess() }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("You can enable this later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var continueButton: some View {
        Button("Get Started") {
            hasCompletedOnboarding = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(!downloadViewModel.isModelLoaded)
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

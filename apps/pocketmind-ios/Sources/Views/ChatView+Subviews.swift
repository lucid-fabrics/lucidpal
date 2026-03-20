import SwiftUI

// MARK: - Mic button label

struct MicButtonLabel: View {
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring1Scale: CGFloat = 1
    @State private var ring2Scale: CGFloat = 1

    var body: some View {
        ZStack {
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
        .frame(width: 40, height: 40)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { ring1Scale = 1.5 }
                withAnimation(.easeInOut(duration: 0.9).delay(0.3).repeatForever(autoreverses: true)) { ring2Scale = 1.7 }
            } else {
                ring1Scale = 1
                ring2Scale = 1
            }
        }
        .onAppear {
            if isRecording && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { ring1Scale = 1.5 }
                withAnimation(.easeInOut(duration: 0.9).delay(0.3).repeatForever(autoreverses: true)) { ring2Scale = 1.7 }
            }
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

import SwiftUI

struct ToastItem: Equatable {
    let message: String
    let systemImage: String
}

struct ToastView: View {
    let item: ToastItem

    private var semanticColor: Color {
        let msg = item.message.lowercased()
        if msg.contains("error") || msg.contains("fail") || msg.contains("denied") {
            return .red
        } else if msg.contains("success") || msg.contains("saved") || msg.contains("copied")
                    || msg.contains("deleted") || msg.contains("created") {
            return .green
        }
        return .accentColor
    }

    private var semanticIcon: String {
        let msg = item.message.lowercased()
        if msg.contains("error") || msg.contains("fail") || msg.contains("denied") {
            return "exclamationmark.circle.fill"
        } else if msg.contains("success") || msg.contains("saved") || msg.contains("copied")
                    || msg.contains("deleted") || msg.contains("created") {
            return "checkmark.circle.fill"
        }
        return "info.circle.fill"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: semanticIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(semanticColor)
            Text(item.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(semanticColor)
                .frame(width: 3)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14
                    )
                )
        }
        .shadow(color: DesignConstants.Shadow.floatingColor, radius: DesignConstants.Shadow.floatingRadius, y: DesignConstants.Shadow.floatingY)
    }
}

import SwiftUI

// MARK: - Bulk deletion bar

struct BulkDeletionBar: View {
    let count: Int
    let onDeleteAll: () -> Void
    let onKeepAll: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onKeepAll) {
                Text("Keep All")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignConstants.Padding.rowVertical)
            }
            Divider().frame(height: DesignConstants.Size.dividerHeight)
            Button(action: onDeleteAll) {
                Text("Delete All (\(count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignConstants.Padding.rowVertical)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous))
        // swiftlint:disable:next line_length
        .overlay(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.card, style: .continuous).stroke(Color.red.opacity(DesignConstants.Opacity.conflictBorder), lineWidth: 1))
    }
}

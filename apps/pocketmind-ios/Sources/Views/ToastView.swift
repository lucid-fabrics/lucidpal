import SwiftUI

struct ToastItem: Equatable {
    let message: String
    let systemImage: String
}

struct ToastView: View {
    let item: ToastItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(item.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(.label).opacity(0.88))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

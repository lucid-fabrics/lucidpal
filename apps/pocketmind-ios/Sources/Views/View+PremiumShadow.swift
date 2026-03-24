import SwiftUI

extension View {
    func premiumShadow(level: ShadowLevel = .card) -> some View {
        modifier(PremiumShadowModifier(level: level))
    }
}

enum ShadowLevel {
    case card, floating, overlay
}

private struct PremiumShadowModifier: ViewModifier {
    let level: ShadowLevel
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        switch level {
        case .card:
            content.shadow(
                color: isDark ? .white.opacity(0.04) : .black.opacity(0.06),
                radius: isDark ? 2 : 4,
                y: isDark ? 1 : 2
            )
        case .floating:
            content.shadow(
                color: isDark ? .white.opacity(0.06) : .black.opacity(0.1),
                radius: isDark ? 4 : 8,
                y: isDark ? 2 : 4
            )
        case .overlay:
            content.shadow(
                color: isDark ? .white.opacity(0.08) : .black.opacity(0.15),
                radius: isDark ? 8 : 16,
                y: isDark ? 4 : 8
            )
        }
    }
}

@testable import PocketMind
import XCTest

@MainActor
final class DesignConstantsTests: XCTestCase {

    // MARK: - Hierarchy invariants

    func testBubbleCornerRadiusLargerThanCard() {
        XCTAssertGreaterThan(DesignConstants.CornerRadius.bubble, DesignConstants.CornerRadius.card)
    }

    func testCardCornerRadiusLargerThanBadge() {
        XCTAssertGreaterThan(DesignConstants.CornerRadius.card, DesignConstants.CornerRadius.badge)
    }

    func testDateBadgeLargerThanSlotBadge() {
        XCTAssertGreaterThanOrEqual(DesignConstants.Size.dateBadgeWidth, DesignConstants.Size.slotBadgeWidth)
    }

    func testBubblePaddingLargerThanCardPadding() {
        XCTAssertGreaterThan(DesignConstants.Padding.bubbleHorizontal, DesignConstants.Padding.card)
    }

    // MARK: - Opacity range [0, 1]

    func testAllOpacityValuesInRange() {
        let opacities: [CGFloat] = [
            DesignConstants.Opacity.dimmed,
            DesignConstants.Opacity.verDimmed,
            DesignConstants.Opacity.conflictBorder,
            DesignConstants.Opacity.updateBorder,
            DesignConstants.Opacity.slotBorder
        ]
        for opacity in opacities {
            XCTAssertGreaterThan(opacity, 0, "Opacity \(opacity) must be > 0")
            XCTAssertLessThanOrEqual(opacity, 1, "Opacity \(opacity) must be ≤ 1")
        }
    }

    func testDimmedMoreOpaqueThenvVerDimmed() {
        XCTAssertGreaterThan(DesignConstants.Opacity.dimmed, DesignConstants.Opacity.verDimmed)
    }

    // MARK: - Font sizes positive

    func testAllFontSizesPositive() {
        let sizes: [CGFloat] = [
            DesignConstants.FontSize.monthBadge,
            DesignConstants.FontSize.dayBadge,
            DesignConstants.FontSize.slotDayBadge,
            DesignConstants.FontSize.tinyIcon,
            DesignConstants.FontSize.microIcon
        ]
        for size in sizes {
            XCTAssertGreaterThan(size, 0, "Font size \(size) must be positive")
        }
    }

    func testDayBadgeLargerThanMonthBadge() {
        XCTAssertGreaterThan(DesignConstants.FontSize.dayBadge, DesignConstants.FontSize.monthBadge)
    }

    // MARK: - Size constants positive

    func testAllSizeConstantsPositive() {
        XCTAssertGreaterThan(DesignConstants.Size.dateBadgeWidth, 0)
        XCTAssertGreaterThan(DesignConstants.Size.slotBadgeWidth, 0)
        XCTAssertGreaterThan(DesignConstants.Size.dividerHeight, 0)
        XCTAssertGreaterThan(DesignConstants.Size.messageSpacer, 0)
    }
}

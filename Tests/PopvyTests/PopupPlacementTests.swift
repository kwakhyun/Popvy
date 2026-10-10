import AppKit
import XCTest
@testable import Popvy

final class PopupPlacementTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 25, width: 1440, height: 850)

    func testPopupAppearsJustBelowCursorInsteadOfScreenCenter() {
        let anchor = NSRect(x: 180, y: 700, width: 2, height: 18)
        let result = PopupPlacement.frame(anchor: anchor, size: NSSize(width: 336, height: 300), visibleFrame: screen)
        XCTAssertEqual(result.minX, 180)
        XCTAssertEqual(result.maxY, anchor.minY - 8)
    }

    func testBottomRightCornerFlipsUpAndKeepsPopupOnScreen() {
        let anchor = NSRect(x: 1438, y: 35, width: 1, height: 1)
        let result = PopupPlacement.frame(anchor: anchor, size: NSSize(width: 336, height: 400), visibleFrame: screen)
        XCTAssertTrue(screen.insetBy(dx: 8, dy: 8).contains(result))
        XCTAssertEqual(result.minY, anchor.maxY + 8)
        XCTAssertEqual(result.maxX, screen.maxX - 8)
    }

    func testSecondaryMonitorWithNegativeCoordinates() {
        let leftScreen = NSRect(x: -1920, y: -300, width: 1920, height: 1080)
        let result = PopupPlacement.frame(anchor: NSRect(x: -1915, y: -295, width: 1, height: 1),
            size: NSSize(width: 336, height: 412), visibleFrame: leftScreen)
        XCTAssertTrue(leftScreen.insetBy(dx: 8, dy: 8).contains(result))
        XCTAssertLessThan(result.maxX, 0)
    }

    func testOversizedPopupIsClampedToSmallDisplay() {
        let smallScreen = NSRect(x: 10, y: 20, width: 300, height: 250)
        let result = PopupPlacement.frame(anchor: NSRect(x: 100, y: 100, width: 1, height: 1),
            size: NSSize(width: 336, height: 500), visibleFrame: smallScreen)
        XCTAssertEqual(result, smallScreen.insetBy(dx: 8, dy: 8))
    }

    func testCaretCoordinatesUsePrimaryDisplayAndSupportUpperDisplay() {
        let primary = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let result = PopupPlacement.appKitRect(fromAccessibility: CGRect(x: -200, y: -150, width: 0, height: 18), primaryScreen: primary)
        XCTAssertEqual(result, NSRect(x: -200, y: 1032, width: 1, height: 18))
    }

    func testPopupGrowsWithHistoryButStopsAtFourVisibleRows() {
        let one = PopupPlacement.size(itemCount: 1, searching: false, hasNotice: false)
        let four = PopupPlacement.size(itemCount: 4, searching: false, hasNotice: false)
        let many = PopupPlacement.size(itemCount: 100, searching: false, hasNotice: false)
        XCTAssertLessThan(one.height, four.height)
        XCTAssertEqual(four, many)
        XCTAssertLessThanOrEqual(many.height, 420)
        XCTAssertEqual(PopupPlacement.size(itemCount: 4, searching: true, hasNotice: false).height, four.height + 42)
    }
}

import Foundation
@testable import KeyboardViews
import XCTest

/// サイズ調整の枠を画面の外へ引っ張れないこと・「上に広げる」ボタンが縮めたときだけ効くこと
final class OneHandedResizeBoundsTests: XCTestCase {
    // MARK: - 左右の端は画面の内側に留める

    func test_leftEdgeStopsAtScreenEdge() {
        XCTAssertEqual(
            OneHandedHorizontalResize.clampedEdgeX(
                proposed: -80, otherEdgeX: 600, isLeftEdge: true, containerWidth: 1000, minimumWidth: 120),
            0
        )
    }

    func test_rightEdgeStopsAtScreenEdge() {
        XCTAssertEqual(
            OneHandedHorizontalResize.clampedEdgeX(
                proposed: 1100, otherEdgeX: 300, isLeftEdge: false, containerWidth: 1000, minimumWidth: 120),
            1000
        )
    }

    func test_edgeInsideScreenMovesFreely() {
        XCTAssertEqual(
            OneHandedHorizontalResize.clampedEdgeX(
                proposed: 250, otherEdgeX: 600, isLeftEdge: true, containerWidth: 1000, minimumWidth: 120),
            250
        )
    }

    func test_edgeKeepsMinimumWidth() {
        XCTAssertEqual(
            OneHandedHorizontalResize.clampedEdgeX(
                proposed: 590, otherEdgeX: 600, isLeftEdge: true, containerWidth: 1000, minimumWidth: 120),
            480
        )
        XCTAssertEqual(
            OneHandedHorizontalResize.clampedEdgeX(
                proposed: 310, otherEdgeX: 300, isLeftEdge: false, containerWidth: 1000, minimumWidth: 120),
            420
        )
    }

    // MARK: - 「上に広げる」ボタン

    func test_expandUpIsDisabledAtFullHeight() {
        XCTAssertFalse(
            OneHandedVerticalResizeResult.canExpandUp(height: 200, bottomOffset: 40, maximumHeight: 240))
    }

    func test_expandUpIsEnabledWhenShrunk() {
        XCTAssertTrue(
            OneHandedVerticalResizeResult.canExpandUp(height: 180, bottomOffset: 40, maximumHeight: 240))
    }

    func test_expandUpFillsUpToMaximumKeepingBottomOffset() {
        let result = OneHandedVerticalResizeResult.expandedUp(bottomOffset: 40, maximumHeight: 240)
        XCTAssertEqual(result.height, 200)
        XCTAssertEqual(result.bottomOffset, 40)
    }
}

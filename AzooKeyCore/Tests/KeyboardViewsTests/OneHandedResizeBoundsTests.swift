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

    /// 旧実装で画面外に保存された位置から操作しても、枠全体が画面外へ出ない
    func test_edgeStaysOnScreenEvenIfOtherEdgeIsOffScreen() {
        // 左端を右へ: 右端 510 は画面幅 390 の外
        let left = OneHandedHorizontalResize.clampedEdgeX(
            proposed: 390, otherEdgeX: 510, isLeftEdge: true, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(left, 270)
        // 右端を左へ: 左端 -120 は画面の外
        let right = OneHandedHorizontalResize.clampedEdgeX(
            proposed: 0, otherEdgeX: -120, isLeftEdge: false, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(right, 120)
    }

    func test_normalizedEdgesPullsOffScreenFrameBackInside() {
        let shiftedRight = OneHandedHorizontalResize.normalizedEdges(
            left: 270, right: 510, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(shiftedRight.left, 150)
        XCTAssertEqual(shiftedRight.right, 390)

        let shiftedLeft = OneHandedHorizontalResize.normalizedEdges(
            left: -120, right: 120, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(shiftedLeft.left, 0)
        XCTAssertEqual(shiftedLeft.right, 240)

        let tooWide = OneHandedHorizontalResize.normalizedEdges(
            left: -50, right: 500, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(tooWide.left, 0)
        XCTAssertEqual(tooWide.right, 390)

        let inside = OneHandedHorizontalResize.normalizedEdges(
            left: 10, right: 300, containerWidth: 390, minimumWidth: 120)
        XCTAssertEqual(inside.left, 10)
        XCTAssertEqual(inside.right, 300)
    }

    // MARK: - 「上に広げる」ボタン

    /// 縮めて確定 → 再編集すると maximumHeight は縮めた高さになる。上限は全幅の高さ（100%）で見る
    func test_expandCeilingIsFullHeightAfterReEditingShrunkKeyboard() {
        XCTAssertEqual(OneHandedVerticalResizeResult.expandCeiling(maximumHeight: 180, fullHeight: 240), 240)
        XCTAssertTrue(OneHandedVerticalResizeResult.canExpandUp(height: 180, bottomOffset: 0, maximumHeight: 240))
        XCTAssertEqual(OneHandedVerticalResizeResult.expandedUp(bottomOffset: 0, maximumHeight: 240).height, 240)
    }

    func test_expandCeilingKeepsLargerMaximum() {
        XCTAssertEqual(OneHandedVerticalResizeResult.expandCeiling(maximumHeight: 300, fullHeight: 240), 300)
    }

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

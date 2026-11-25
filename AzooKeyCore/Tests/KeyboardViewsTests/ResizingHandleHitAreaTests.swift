import CoreGraphics
@testable import KeyboardViews
import XCTest

final class ResizingHandleHitAreaTests: XCTestCase {
    private let size = CGSize(width: 390, height: 260)
    private let edgeRatio: CGFloat = 1 / 5

    private func rect(_ edge: ResizingHandleHitArea.Edge, size: CGSize? = nil) -> CGRect {
        ResizingHandleHitArea.rect(for: edge, in: size ?? self.size, edgeRatio: edgeRatio)
    }

    func test_hitAreaIsAtLeastMinimumThickness() {
        // 小さく縮めたキーボードでも、指で掴める厚みを保つ
        let small = CGSize(width: 120, height: 120)
        XCTAssertGreaterThanOrEqual(rect(.left, size: small).width, ResizingHandleHitArea.minimumThickness)
        XCTAssertGreaterThanOrEqual(rect(.right, size: small).width, ResizingHandleHitArea.minimumThickness)
        XCTAssertGreaterThanOrEqual(rect(.top, size: small).height, ResizingHandleHitArea.minimumThickness)
    }

    func test_hitAreaCoversDrawnLines() {
        // 描いている線の帯（端から 1/8・中央の ±edgeRatio*0.8）を含む
        let left = rect(.left)
        XCTAssertLessThanOrEqual(left.minX, 0)
        XCTAssertGreaterThanOrEqual(left.maxX, size.width / 8)
        XCTAssertLessThanOrEqual(left.minY, size.height / 2 - size.height * edgeRatio * 0.8)
        XCTAssertGreaterThanOrEqual(left.maxY, size.height / 2 + size.height * edgeRatio * 0.8)

        let top = rect(.top)
        XCTAssertLessThanOrEqual(top.minY, 0)
        XCTAssertGreaterThanOrEqual(top.maxY, size.height / 8)
        XCTAssertLessThanOrEqual(top.minX, size.width / 2 - size.width * edgeRatio * 0.8)
        XCTAssertGreaterThanOrEqual(top.maxX, size.width / 2 + size.width * edgeRatio * 0.8)
    }

    /// 上のつまみは線の下だけでなく、枠の上辺の外側と、幅いっぱいで掴める（2026-11-25 ユーザー指摘「触れる領域が狭すぎる」）
    func test_topHandleSpansFullWidthAndReachesAboveTheEdge() {
        let top = rect(.top)
        XCTAssertLessThanOrEqual(top.minX, 0)
        XCTAssertGreaterThanOrEqual(top.maxX, size.width)
        XCTAssertLessThanOrEqual(top.minY, -ResizingHandleHitArea.outset)
    }

    /// 左右のつまみも枠の外側から掴め、上のつまみの下から枠の下端まで届く
    func test_sideHandlesReachOutsideAndSpanBelowTopHandle() {
        let left = rect(.left)
        let right = rect(.right)
        let top = rect(.top)
        XCTAssertLessThanOrEqual(left.minX, -ResizingHandleHitArea.outset)
        XCTAssertGreaterThanOrEqual(right.maxX, size.width + ResizingHandleHitArea.outset)
        XCTAssertEqual(left.minY, top.maxY, accuracy: 0.001)
        XCTAssertEqual(left.maxY, size.height, accuracy: 0.001)
        XCTAssertEqual(right.width, left.width, accuracy: 0.001)
        XCTAssertEqual(right.minY, left.minY, accuracy: 0.001)
    }

    func test_sideAndTopHandlesDoNotOverlap() {
        // 角で左右のハンドルと上のハンドルが重なると、どちらのドラッグになるかが曖昧になる
        for small in [size, CGSize(width: 120, height: 120)] {
            for side in [ResizingHandleHitArea.Edge.left, .right] {
                XCTAssertFalse(rect(side, size: small).intersects(rect(.top, size: small)), "\(side) \(small)")
            }
        }
    }

    /// 小さく縮めた枠でも、左右の線の全体が左右のつまみに入る（上のつまみに取られない）
    func test_sideLinesBelongToSideHandlesOnSmallFrames() {
        for small in [CGSize(width: 120, height: 120), CGSize(width: 300, height: 100)] {
            let lineTop = small.height / 2 - small.height * edgeRatio * 0.8
            XCTAssertLessThanOrEqual(rect(.left, size: small).minY, lineTop, "\(small)")
            XCTAssertLessThanOrEqual(rect(.right, size: small).minY, lineTop, "\(small)")
        }
    }
}

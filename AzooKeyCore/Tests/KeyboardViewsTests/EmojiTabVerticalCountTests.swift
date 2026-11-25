@testable import KeyboardViews
import XCTest

/// TypeAI: 絵文字タブの行数。iPhone Duo の内側（横向き扱い）は 3 行だと絵文字が大きすぎたので、ホストが 5 行にできる
final class EmojiTabVerticalCountTests: XCTestCase {
    func test_defaultsFollowOrientation() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil), 5)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: nil), 3)
    }

    func test_hostOverrideWinsInHorizontal() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: 5), 5)
    }

    func test_embeddedIsAlwaysFive() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: true, orientation: .horizontal, override: 3), 5)
    }

    func test_invalidOverrideIsIgnored() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: 0), 3)
    }

    /// サイズ調整で縮めたときは行数を減らす。行数 × √(高さの割合) を切り上げる
    /// （2026-11-25 ユーザー指示「縮めたら絵文字も小さく」→ 中間案。55% で 4 行・絵文字は約 30% 小さく）
    func test_shrunkKeyboardShowsFewerRows() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 1), 5)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.8), 5)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.6), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.55), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.5), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: nil, heightRatio: 0.6), 3)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: true, orientation: .horizontal, override: nil, heightRatio: 0.55), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: 5, heightRatio: 0.55), 4)
    }

    /// 最小（100% の半分）まで縮めても 2 行は残す。100% より高くしても行は増やさない
    func test_rowCountIsClampedBetweenTwoAndBase() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: nil, heightRatio: 0.3), 2)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.1), 2)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 1.4), 5)
        // ホストが 1 行を指定したら、縮めても 1 行のまま（2 行に増やさない）
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: 1, heightRatio: 0.5), 1)
    }

    func test_heightRatioOfShrunkInterface() {
        XCTAssertEqual(emojiTabHeightRatio(interfaceHeight: 200, fullHeight: 250), 0.8, accuracy: 0.0001)
        XCTAssertEqual(emojiTabHeightRatio(interfaceHeight: 300, fullHeight: 250), 1)
        XCTAssertEqual(emojiTabHeightRatio(interfaceHeight: 200, fullHeight: 0), 1)
    }

    /// 絵文字の大きさ（100% のときとの比）は、高さの割合と √(割合) のあいだに収まる。
    /// キーと同じだけ小さくはしない（窮屈になる）・100% より大きくもしない（四捨五入で 1.1 倍になった件。2026-11-25 ユーザー指摘）
    func test_emojiShrinksBetweenRatioAndSquareRoot() {
        for ratio in stride(from: CGFloat(0.4), through: 1, by: 0.01) {
            for orientation in [KeyboardOrientation.vertical, .horizontal] {
                let base = emojiTabVerticalCount(isEmbedded: false, orientation: orientation, override: nil)
                let rows = emojiTabVerticalCount(isEmbedded: false, orientation: orientation, override: nil, heightRatio: ratio)
                let scale = ratio * CGFloat(base) / CGFloat(rows)
                XCTAssertLessThanOrEqual(scale, 1 + 0.0001, "ratio=\(ratio) rows=\(rows)")
                XCTAssertGreaterThanOrEqual(scale, ratio - 0.0001, "ratio=\(ratio) rows=\(rows)")
                // 下限の 2 行に止められたときは √ より大きくなりうる
                guard CGFloat(base) * ratio.squareRoot() >= 2 else { continue }
                XCTAssertLessThanOrEqual(scale, ratio.squareRoot() + 0.0001, "ratio=\(ratio) rows=\(rows)")
            }
        }
    }
}

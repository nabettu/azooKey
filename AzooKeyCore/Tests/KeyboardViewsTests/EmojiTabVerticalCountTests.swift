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

    /// サイズ調整で縮めたときは、縮めた割合で行数を減らす（絵文字が小さくなりすぎない。2026-11-25 ユーザー指示）
    func test_shrunkKeyboardShowsFewerRows() {
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 1), 5)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.92), 5)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.8), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.6), 3)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: nil, heightRatio: 0.6), 2)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: true, orientation: .horizontal, override: nil, heightRatio: 0.8), 4)
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .horizontal, override: 5, heightRatio: 0.6), 3)
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

    /// 縮めても絵文字は 100% のときより大きくしない。行数は切り上げる（四捨五入だと 66% で 3 行になり、1 行が 1.1 倍になった。2026-11-25 ユーザー指摘）
    func test_shrunkRowsNeverMakeEmojiLarger() {
        for ratio in stride(from: CGFloat(0.4), through: 1, by: 0.01) {
            for orientation in [KeyboardOrientation.vertical, .horizontal] {
                let base = emojiTabVerticalCount(isEmbedded: false, orientation: orientation, override: nil)
                let rows = emojiTabVerticalCount(isEmbedded: false, orientation: orientation, override: nil, heightRatio: ratio)
                guard rows > 2 else { continue }  // 下限の 2 行では大きくなりうる
                XCTAssertLessThanOrEqual(ratio / CGFloat(rows), 1 / CGFloat(base) + 0.0001, "ratio=\(ratio) rows=\(rows)")
            }
        }
        XCTAssertEqual(emojiTabVerticalCount(isEmbedded: false, orientation: .vertical, override: nil, heightRatio: 0.66), 4)
    }
}

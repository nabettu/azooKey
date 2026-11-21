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
}

import CustardKit
@testable import KeyboardViews
import XCTest

/// TypeAI: 絵文字キーの行き先をホストが列の位置で決められる（両手フリックで押した側だけ絵文字にする。2026-11-25 ユーザー指示）
@MainActor
final class EmojiKeyTabTests: XCTestCase {
    override func tearDown() async throws {
        Design.emojiKeyTab = nil
    }

    func test_defaultsToEmojiTab() {
        Design.emojiKeyTab = nil
        XCTAssertEqual(Design.emojiKeyTabData(gridX: 0), .system(.emoji_tab))
        XCTAssertEqual(Design.emojiKeyTabData(gridX: nil), .system(.emoji_tab))
    }

    func test_hostDecidesByColumn() {
        Design.emojiKeyTab = { x in x < 10 ? .custom("left") : .custom("right") }
        XCTAssertEqual(Design.emojiKeyTabData(gridX: 0), .custom("left"))
        XCTAssertEqual(Design.emojiKeyTabData(gridX: 11), .custom("right"))
    }

    func test_hostCanFallBackToEmojiTab() {
        Design.emojiKeyTab = { _ in nil }
        XCTAssertEqual(Design.emojiKeyTabData(gridX: 3), .system(.emoji_tab))
    }
}

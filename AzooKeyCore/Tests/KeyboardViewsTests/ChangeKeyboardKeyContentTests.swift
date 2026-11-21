@testable import KeyboardViews
import XCTest

/// キー (0,3) に何を出すか。地球儀を自前で描く端末（iPhone Duo・ホームボタンの iPhone・iPad）でも
/// 絵文字キーを消さず、地球儀と半分ずつ並べる（TypeAI）。
final class ChangeKeyboardKeyContentTests: XCTestCase {
    func test_needsGlobeWithEmojiSetting_sharesKeyWithEmoji() {
        XCTAssertEqual(
            ChangeKeyboardKeyContent.resolve(needsInputModeSwitchKey: true, useEmojiKeyInsteadOfCursorBar: true),
            .globeAndEmoji
        )
    }

    func test_needsGlobeWithoutEmojiSetting_isGlobeOnly() {
        XCTAssertEqual(
            ChangeKeyboardKeyContent.resolve(needsInputModeSwitchKey: true, useEmojiKeyInsteadOfCursorBar: false),
            .globe
        )
    }

    func test_systemDrawsGlobe_keepsEmojiOrCursorBar() {
        XCTAssertEqual(
            ChangeKeyboardKeyContent.resolve(needsInputModeSwitchKey: false, useEmojiKeyInsteadOfCursorBar: true),
            .emoji
        )
        XCTAssertEqual(
            ChangeKeyboardKeyContent.resolve(needsInputModeSwitchKey: false, useEmojiKeyInsteadOfCursorBar: false),
            .cursorBar
        )
    }
}

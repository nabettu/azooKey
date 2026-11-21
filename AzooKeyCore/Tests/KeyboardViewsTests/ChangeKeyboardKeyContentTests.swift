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

    func test_labelType_globeAndEmojiUsesSplitLabel() {
        XCTAssertEqual(ChangeKeyboardKeyContent.globeAndEmoji.labelType, .changeKeyboardAndEmoji)
        XCTAssertEqual(ChangeKeyboardKeyContent.globe.labelType, .changeKeyboard)
        XCTAssertEqual(ChangeKeyboardKeyContent.emoji.labelType, .image("face.smiling"))
    }

    func test_splitIconScale_shrinksOnlyWhenHalfIsNarrow() {
        // Duo のカバー（キー幅約 69pt → 半分 34.5pt）で 21pt のアイコンは縮めない
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 34.5, iconSize: 21), 1)
        // 片手モードの最小幅 120pt の 5 列（キー幅約 22pt → 半分 11pt）では収まるまで縮める
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 11, iconSize: 21), 3.0 / 21, accuracy: 0.0001)
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 4, iconSize: 21), 0)
    }

    func test_onlyGlobeAndEmojiSplitsBackground() {
        XCTAssertTrue(ChangeKeyboardKeyContent.globeAndEmoji.splitsBackgroundInHalves)
        XCTAssertFalse(ChangeKeyboardKeyContent.globe.splitsBackgroundInHalves)
        XCTAssertFalse(ChangeKeyboardKeyContent.emoji.splitsBackgroundInHalves)
        XCTAssertFalse(ChangeKeyboardKeyContent.cursorBar.splitsBackgroundInHalves)
    }

    func test_splitHalfWidth_leavesKeyGapBetweenHalves() {
        // 2 つのキーの間をほかのキーと同じ隙間にする
        XCTAssertEqual(KeyLabelType.splitHalfWidth(totalWidth: 69, gap: 5), 32)
        XCTAssertEqual(KeyLabelType.splitHalfWidth(totalWidth: 4, gap: 6), 0)
    }
}

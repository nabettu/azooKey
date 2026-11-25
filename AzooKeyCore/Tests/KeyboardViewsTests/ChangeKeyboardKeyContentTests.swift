@testable import KeyboardViews
import UIKit
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
        // 余白 4pt ずつを残せるうちは残して縮める
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 24, iconSize: 21), 16.0 / 21, accuracy: 0.0001)
    }

    /// 英語専用 QWERTY は 1.4 列のキーを半分に割るので、フリック（1 列 = 1/5）より狭くなる。
    /// 余白を守って縮め続けると Duo の内側の片手モード（半分約 15pt）で 7pt になり判別できない（ai-review の P2）。
    /// 12pt を下回る前に余白の方を削り、それでも入らないときだけ半分の幅いっぱいまで縮める
    func test_splitIconScale_keepsLegibleSizeByDroppingMarginFirst() {
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 15, iconSize: 21), 12.0 / 21, accuracy: 0.0001)
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 11, iconSize: 21), 11.0 / 21, accuracy: 0.0001)
        XCTAssertEqual(KeyLabelType.splitIconScale(halfWidth: 0, iconSize: 21), 0)
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

    /// 分割キーは押した側（地球儀か絵文字）の背景だけを押した色にする
    func test_splitKeyHalf_onlyPressedHalfIsHighlighted() {
        XCTAssertTrue(SplitKeyHalf.leading.isHighlighted(pressedHalves: [.leading]))
        XCTAssertFalse(SplitKeyHalf.trailing.isHighlighted(pressedHalves: [.leading]))
        XCTAssertTrue(SplitKeyHalf.trailing.isHighlighted(pressedHalves: [.trailing]))
        XCTAssertFalse(SplitKeyHalf.leading.isHighlighted(pressedHalves: []))
        XCTAssertFalse(SplitKeyHalf.trailing.isHighlighted(pressedHalves: []))
    }

    /// 左右を別の指で押して片方を離しても、押している側の色は残す（ai-review の P2）
    func test_splitKeyHalf_releasingOneKeepsTheOther() {
        var pressed: Set<SplitKeyHalf> = []
        pressed = SplitKeyHalf.updated(pressed, half: .leading, isPressed: true)
        pressed = SplitKeyHalf.updated(pressed, half: .trailing, isPressed: true)
        pressed = SplitKeyHalf.updated(pressed, half: .leading, isPressed: false)
        XCTAssertEqual(pressed, [.trailing])
        pressed = SplitKeyHalf.updated(pressed, half: .trailing, isPressed: false)
        XCTAssertEqual(pressed, [])
    }

    /// ボタンの押下イベントを「押している / いない」に直す（指をずらして外れたら離した扱い）
    @MainActor
    func test_buttonPressObserver_mapsControlEvents() {
        let button = UIButton(type: .custom)
        let observer = ButtonPressObserver()
        var log: [Bool] = []
        observer.onChange = { log.append($0) }
        observer.attach(to: button)
        for event: UIControl.Event in [.touchDown, .touchDragExit, .touchDragEnter, .touchUpInside, .touchDown, .touchCancel, .touchDown, .touchUpOutside] {
            // ホストアプリの無いテストでは sendActions が届かないので、登録された動作を直接呼ぶ
            for name in button.actions(forTarget: observer, forControlEvent: event) ?? [] {
                observer.perform(NSSelectorFromString(name))
            }
        }
        XCTAssertEqual(log, [true, false, true, false, true, false, true, false])
    }
}

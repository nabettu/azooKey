import CustardKit
@testable import KeyboardViews
import XCTest

/// 英語専用モード（TypeAI。日本語フリック + 英語 QWERTY）の QWERTY の下段。
/// 左下を数字 / 英字タブにしたので、その右は地球儀・絵文字（`changeKeyboard`）にする。
/// `qwertyDynamicChange` のままだと、英字タブでは左下と同じ「123」が 2 つ並び、
/// 地球儀を自前で描く端末（実機の iPhone Duo など）で地球儀が消えていた（2026-11-25 ユーザー報告）
final class EnglishOnlyQwertyCustardTests: XCTestCase {
    private func bottomRowSecondKey(_ custard: Custard) -> CustardInterfaceKey? {
        custard.interface.keys[.gridFit(.init(x: 1.4, y: 3, width: 1.4))]
    }

    func test_letters_secondBottomKeyIsGlobeOrEmoji() {
        XCTAssertEqual(bottomRowSecondKey(.qwertyEnglishOnlyLetters), .system(.changeKeyboard))
    }

    func test_numbersAndSymbols_secondBottomKeyIsGlobeOrEmoji() {
        XCTAssertEqual(
            bottomRowSecondKey(.qwertyEnglishOnly(numbersOrSymbols: .qwertyNumbers)),
            .system(.changeKeyboard)
        )
        XCTAssertEqual(
            bottomRowSecondKey(.qwertyEnglishOnly(numbersOrSymbols: .qwertySymbols)),
            .system(.changeKeyboard)
        )
    }

    /// 英語専用でない QWERTY（日本語 QWERTY と行き来する）は upstream のまま
    func test_standardEnglish_keepsDynamicChange() {
        XCTAssertEqual(
            bottomRowSecondKey(.qwertyEnglish(useShiftKey: true, useDeprecatedShiftKeyBehavior: false)),
            .system(.qwertyDynamicChange)
        )
    }
}

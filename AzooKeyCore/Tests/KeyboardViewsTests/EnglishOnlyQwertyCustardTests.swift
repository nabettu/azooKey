import CustardKit
@testable import KeyboardViews
import XCTest

/// 英語専用モード（TypeAI。日本語フリック + 英語 QWERTY）の QWERTY の下段。
/// 左下を数字 / 英字タブにしたので、その右は地球儀・絵文字（`changeKeyboard`）にする。
/// `qwertyDynamicChange` のままだと、英字タブでは左下と同じ「123」が 2 つ並び、
/// 地球儀を自前で描く端末（実機の iPhone Duo など）で地球儀が消えていた（2026-11-25 ユーザー報告）
final class EnglishOnlyQwertyCustardTests: XCTestCase {
    private func key(_ custard: Custard, x: Double, width: Double) -> CustardInterfaceKey? {
        custard.interface.keys[.gridFit(.init(x: x, y: 3, width: width))]
    }

    private func allEnglishOnlyTabs(splitsChangeKey: Bool) -> [Custard] {
        [
            .qwertyEnglishOnlyLetters(splitsChangeKey: splitsChangeKey),
            .qwertyEnglishOnly(numbersOrSymbols: .qwertyNumbers, splitsChangeKey: splitsChangeKey),
            .qwertyEnglishOnly(numbersOrSymbols: .qwertySymbols, splitsChangeKey: splitsChangeKey),
        ]
    }

    func test_secondBottomKeyIsGlobeOrEmoji() {
        for custard in allEnglishOnlyTabs(splitsChangeKey: false) {
            XCTAssertEqual(key(custard, x: 1.4, width: 1.4), .system(.changeKeyboard))
            XCTAssertEqual(key(custard, x: 2.8, width: 4.4), .system(.qwertySpace))
        }
    }

    /// 地球儀と絵文字を半分ずつ並べるときは、1.4 列を割ると 1 つが小さすぎる（2026-11-25 ユーザー指摘）。
    /// スペースを 1 列縮めて 2.4 列にし、半分ずつがほぼ文字キー 1 つ分になるようにする
    func test_splitChangeKey_takesOneColumnFromSpace() {
        for custard in allEnglishOnlyTabs(splitsChangeKey: true) {
            XCTAssertEqual(key(custard, x: 1.4, width: 2.4), .system(.changeKeyboard))
            XCTAssertEqual(key(custard, x: 3.8, width: 3.4), .system(.qwertySpace))
            XCTAssertNil(key(custard, x: 1.4, width: 1.4))
            XCTAssertNil(key(custard, x: 2.8, width: 4.4))
            XCTAssertEqual(key(custard, x: 7.2, width: 2.8), .system(.enter))
        }
    }

    /// 英語専用でない QWERTY（日本語 QWERTY と行き来する）は upstream のまま
    func test_standardEnglish_keepsDynamicChange() {
        XCTAssertEqual(
            key(.qwertyEnglish(useShiftKey: true, useDeprecatedShiftKeyBehavior: false), x: 1.4, width: 1.4),
            .system(.qwertyDynamicChange)
        )
    }
}

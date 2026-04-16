import CustardKit
import Foundation
import KeyboardThemes
import SwiftUI

/// フリックキーボード用スペースキー
/// 長押しでカーソル移動モード（← →）に入り、左右ドラッグでカーソルを移動する
struct FlickCursorSpaceKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: UnifiedKeyModelProtocol {
    func pressActions(variableStates _: VariableStates) -> [ActionType] {
        [.input(" ")]
    }

    func longPressActions(variableStates _: VariableStates) -> LongpressActionType {
        // 空だがhasLongPressActionをオーバーライドしてtrueを返す
        .init(duration: .normal, start: [], repeat: [])
    }

    func variationSpace(variableStates _: VariableStates) -> UnifiedVariationSpace {
        .none
    }

    func getFlickVariationMap(variableStates _: VariableStates) -> [FlickDirection: UnifiedVariation] {
        [:]
    }

    func getLinearVariations(variableStates _: VariableStates) -> (arr: [QwertyVariationsModel.VariationElement], direction: VariationsViewDirection) {
        ([], .center)
    }

    func isFlickAble(to _: FlickDirection, variableStates _: VariableStates) -> Bool {
        false
    }

    func showsTapBubble(variableStates _: VariableStates) -> Bool { false }

    var supportsCursorTracking: Bool { true }

    func hasLongPressAction(variableStates _: VariableStates) -> Bool {
        true
    }

    func label<ThemeExtension>(width: CGFloat, theme _: ThemeData<ThemeExtension>, states _: VariableStates, color _: Color?) -> KeyLabel<Extension> where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        KeyLabel(.text("空白"), width: width, textSize: .xsmall)
    }

    func backgroundStyleWhenUnpressed<ThemeExtension>(states _: VariableStates, theme: ThemeData<ThemeExtension>) -> UnifiedKeyBackgroundStyleValue where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        (theme.specialKeyFillColor.color, theme.specialKeyFillColor.blendMode)
    }

    func feedback(variableStates: VariableStates) {
        KeyboardFeedback<Extension>.tabOrOtherKey()
    }
}

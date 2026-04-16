import CustardKit
import Foundation
import KeyboardThemes
import SwiftUI

struct FlickNextCandidateKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: UnifiedKeyModelProtocol {
    func pressActions(variableStates: VariableStates) -> [ActionType] {
        if variableStates.resultModel.results.isEmpty {
            [.input(" ")]
        } else {
            [.selectCandidate(.offset(1))]
        }
    }
    func longPressActions(variableStates: VariableStates) -> LongpressActionType {
        if variableStates.resultModel.results.isEmpty {
            // 空の長押しアクション（カーソルトラッキングはView側で処理）
            .init(duration: .normal, start: [], repeat: [])
        } else {
            .init(repeat: [.selectCandidate(.offset(1))])
        }
    }

    // 空白モード時はカーソルトラッキングを有効にする
    var supportsCursorTracking: Bool { true }

    func hasLongPressAction(variableStates: VariableStates) -> Bool {
        // 空白モード時もtrueを返してdecideLongPressOutcomeが.actionになるようにする
        true
    }

    func variationSpace(variableStates: VariableStates) -> UnifiedVariationSpace {
        // 変換候補がある場合のみフリックバリエーションを表示
        if !variableStates.resultModel.results.isEmpty {
            let left: UnifiedVariation = if variableStates.resultModel.selection != nil {
                UnifiedVariation(label: .text("前候補"), pressActions: [.selectCandidate(.offset(-1))], longPressActions: .init(repeat: [.selectCandidate(.offset(-1))]))
            } else {
                UnifiedVariation(label: .text("←"), pressActions: [.moveCursor(-1)], longPressActions: .init(repeat: [.moveCursor(-1)]))
            }
            return .fourWay([
                .left: left,
                .top: UnifiedVariation(label: .text("全角"), pressActions: [.input("　")]),
                .bottom: UnifiedVariation(label: .text("Tab"), pressActions: [.input("\u{0009}")]),
            ])
        }
        // 空白モード時はフリックバリエーションなし（カーソルトラッキングを使う）
        return .none
    }
    func isFlickAble(to direction: FlickDirection, variableStates: VariableStates) -> Bool {
        if variableStates.resultModel.results.isEmpty {
            return false
        }
        switch direction {
        case .left, .top, .bottom: return true
        case .right: return false
        }
    }

    func label<ThemeExtension>(width: CGFloat, theme _: ThemeData<ThemeExtension>, states: VariableStates, color _: Color?) -> KeyLabel<Extension> where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        states.resultModel.results.isEmpty ? KeyLabel(.text("空白"), width: width, textSize: .medium) : KeyLabel(.text("次候補"), width: width, textSize: .medium)
    }
    func backgroundStyleWhenUnpressed<ThemeExtension>(states _: VariableStates, theme: ThemeData<ThemeExtension>) -> UnifiedKeyBackgroundStyleValue where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        (theme.specialKeyFillColor.color, theme.specialKeyFillColor.blendMode)
    }
    func feedback(variableStates: VariableStates) {
        if variableStates.resultModel.results.isEmpty {
            KeyboardFeedback<Extension>.click()
        } else {
            KeyboardFeedback<Extension>.tabOrOtherKey()
        }
    }
}

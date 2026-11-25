import CustardKit
import Foundation
import KeyboardThemes
import SwiftUI

/// キー (0,3) に出すもの
enum ChangeKeyboardKeyContent: Equatable {
    case globe
    /// 地球儀を自前で描く端末（iPhone Duo・ホームボタンの iPhone・iPad）で、絵文字キーを消さずに半分ずつ並べる
    case globeAndEmoji
    case emoji
    case cursorBar

    static func resolve(needsInputModeSwitchKey: Bool, useEmojiKeyInsteadOfCursorBar: Bool) -> Self {
        switch (needsInputModeSwitchKey, useEmojiKeyInsteadOfCursorBar) {
        case (true, true): .globeAndEmoji
        case (true, false): .globe
        case (false, true): .emoji
        case (false, false): .cursorBar
        }
    }

    /// 背景を左右 2 つのキーに分けて描くか
    var splitsBackgroundInHalves: Bool {
        self == .globeAndEmoji
    }

    /// キーに出すラベル
    var labelType: KeyLabelType {
        switch self {
        case .globe: .changeKeyboard
        case .globeAndEmoji: .changeKeyboardAndEmoji
        case .emoji: .image("face.smiling")
        case .cursorBar: .image("arrowtriangle.left.and.line.vertical.and.arrowtriangle.right")
        }
    }
}

struct UnifiedChangeKeyboardKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: UnifiedKeyModelProtocol {
    /// TypeAI: このキーの格子の列。絵文字キーの行き先をホストが決める（`Design.emojiKeyTab`）
    var gridX: CGFloat? = nil

    @MainActor private var _enablePasteButton: Bool {
        Extension.SettingProvider.enablePasteButton
    }
    @MainActor private var usePasteButton: Bool {
        !SemiStaticStates.shared.needsInputModeSwitchKey && SemiStaticStates.shared.hasFullAccess && _enablePasteButton
    }
    @MainActor private var content: ChangeKeyboardKeyContent {
        .resolve(
            needsInputModeSwitchKey: SemiStaticStates.shared.needsInputModeSwitchKey,
            useEmojiKeyInsteadOfCursorBar: Extension.SettingProvider.useEmojiKeyInsteadOfCursorBar
        )
    }
    @MainActor var splitsBackgroundInHalves: Bool {
        content.splitsBackgroundInHalves
    }
    func pressActions(variableStates: VariableStates) -> [ActionType] {
        switch content {
        case .globe, .globeAndEmoji:
            // 地球儀・絵文字はラベルの UIKit ボタンが自分でタッチを受ける
            return []
        case .emoji:
            return [.moveTab(Design.emojiKeyTabData(gridX: gridX))]
        case .cursorBar:
            return [.setCursorBar(.toggle)]
        }
    }
    func longPressActions(variableStates _: VariableStates) -> LongpressActionType {
        .none
    }
    func variationSpace(variableStates: VariableStates) -> UnifiedVariationSpace {
        if usePasteButton {
            return .fourWay([.top: UnifiedVariation(label: .image("doc.on.clipboard"), pressActions: [.paste])])
        }
        return .none
    }
    func isFlickAble(to direction: FlickDirection, variableStates _: VariableStates) -> Bool {
        direction == .top && usePasteButton
    }

    func label<ThemeExtension>(width: CGFloat, theme _: ThemeData<ThemeExtension>, states _: VariableStates, color _: Color?) -> KeyLabel<Extension> where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        KeyLabel(content.labelType, width: width, emojiKeyGridX: gridX)
    }
    func backgroundStyleWhenUnpressed<ThemeExtension>(states _: VariableStates, theme: ThemeData<ThemeExtension>) -> UnifiedKeyBackgroundStyleValue where ThemeExtension: ApplicationSpecificKeyboardViewExtensionLayoutDependentDefaultThemeProvidable {
        (theme.specialKeyFillColor.color, theme.specialKeyFillColor.blendMode)
    }
    func feedback(variableStates _: VariableStates) {
        KeyboardFeedback<Extension>.tabOrOtherKey()
    }
}

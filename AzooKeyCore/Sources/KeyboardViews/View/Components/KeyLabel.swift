//
//  KeyLabel.swift
//  Keyboard
//
//  Created by ensan on 2020/10/20.
//  Copyright © 2020 ensan. All rights reserved.
//

import struct CustardKit.CustardKeyDirectionalLabel
import Foundation
import SwiftUI

public enum KeyLabelType: Sendable, Equatable {
    case text(String)
    case symbols([String])
    case mainAndDirections(String, CustardKeyDirectionalLabel)
    case image(String)
    case customImage(String)
    case changeKeyboard
    /// 地球儀と絵文字を半分ずつ並べたキー（TypeAI: 地球儀を自前で描く端末でも絵文字キーを消さない）
    case changeKeyboardAndEmoji
    case selectable(String, String)
}

private struct SplitKeyGapKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// 半分ずつ並べたキーの間の隙間（キーの外側から、ほかのキーと同じ間隔を渡す）
    var splitKeyGap: CGFloat {
        get { self[SplitKeyGapKey.self] }
        set { self[SplitKeyGapKey.self] = newValue }
    }
}

extension KeyLabelType {
    /// 半分ずつ並べたキーの片方の幅。間に gap を空ける
    static func splitHalfWidth(totalWidth: CGFloat, gap: CGFloat) -> CGFloat {
        max(0, (totalWidth - gap) / 2)
    }

    /// 地球儀と絵文字を半分ずつ並べるときのアイコンの縮小率。左右に 4pt ずつ余白を残して収める（1 より大きくはしない）
    static func splitIconScale(halfWidth: CGFloat, iconSize: CGFloat) -> CGFloat {
        guard iconSize > 0 else { return 1 }
        return max(0, min(1, (halfWidth - 8) / iconSize))
    }
}

public struct DirectionalKeyLabel: View {
    public init(main: String, directions: CustardKeyDirectionalLabel, font: Font = .body, subFont: Font = .caption) {
        self.main = main
        self.directions = directions
        self.font = font
        self.subFont = subFont
    }

    let main: String
    let directions: CustardKeyDirectionalLabel
    let font: Font
    let subFont: Font

    @ViewBuilder
    private func optionalLabel(_ label: String?, font: Font) -> some View {
        if let label {
            Text(label)
                .font(font)
        }
    }

    public var body: some View {
        ZStack {
            HStack {
                self.optionalLabel(directions.left, font: subFont)
                Spacer(minLength: 0)
                self.optionalLabel(directions.right, font: subFont)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                self.optionalLabel(directions.top, font: subFont)
                Spacer(minLength: 0)
                self.optionalLabel(directions.bottom, font: subFont)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(main)
                .font(font)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
public struct KeyLabel<Extension: ApplicationSpecificKeyboardViewExtension>: View {
    private let labelType: KeyLabelType
    private let width: CGFloat
    private var textColor: Color?
    private var textSize: Design.Fonts.LabelFontSizeStrategy
    @Environment(Extension.Theme.self) private var theme
    @Environment(\.userActionManager) private var action
    @EnvironmentObject private var variableStates: VariableStates
    @Environment(\.splitKeyGap) private var splitKeyGap

    private var mainKeyColor: Color {
        textColor ?? theme.textColor.color
    }

    init(_ type: KeyLabelType, width: CGFloat, textSize: Design.Fonts.LabelFontSizeStrategy = .large, textColor: Color? = nil) {
        self.labelType = type
        self.width = width
        self.textColor = textColor
        self.textSize = textSize
    }

    private var keyViewFontSize: CGFloat {
        Extension.SettingProvider.keyViewFontSize
    }

    /// 英語フリック時の入力キー用フォントサイズ（flick_abcタブかつ.largeの場合のみ縮小）
    private var inputKeyViewFontSize: CGFloat {
        let base = Extension.SettingProvider.keyViewFontSize
        if base != -1, textSize == .large, isEnglishFlickTab {
            return base * 0.75
        }
        return base
    }

    /// 英語フリックのタブか。TypeAI: 両手フリックの英語（custard。言語 en_US・テンキー型）も同じく縮める
    private var isEnglishFlickTab: Bool {
        switch variableStates.tabManager.existentialTab() {
        case .flick_abc:
            return true
        case let .custard(custard):
            return custard.language == .en_US && custard.interface.keyStyle == .tenkeyStyle
        default:
            return false
        }
    }

    /// テキストが英語入力キーのラベルかどうか（ASCII英字・記号のみで構成）
    private func isEnglishInputLabel(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { $0.isASCII }
    }

    public var body: some View {
        switch self.labelType {
        case let .text(text):
            let fontSize = isEnglishInputLabel(text) ? inputKeyViewFontSize : keyViewFontSize
            let font = Design.fonts.keyLabelFont(text: text, width: width, fontSize: self.textSize, userDecidedSize: fontSize, theme: theme)
            Text(text)
                .font(font)
                .foregroundStyle(mainKeyColor)
                .allowsHitTesting(false)

        case let .symbols(symbols):
            let mainText = symbols.first!
            let font = Design.fonts.keyLabelFont(text: mainText, width: width, fontSize: self.textSize, userDecidedSize: keyViewFontSize, theme: theme)
            let subText = symbols.dropFirst().joined()
            let subFont = Design.fonts.keyLabelFont(text: subText, width: width, fontSize: .xsmall, userDecidedSize: keyViewFontSize, theme: theme)
            VStack {
                Text(mainText)
                    .font(font)
                Text(subText)
                    .font(subFont)
            }
            .foregroundStyle(mainKeyColor)
            .allowsHitTesting(false)

        case let .mainAndDirections(mainText, directions):
            let font = Design.fonts.keyLabelFont(text: mainText, width: width, fontSize: self.textSize, userDecidedSize: inputKeyViewFontSize, theme: theme)
            let directionLabels = [
                directions.top,
                directions.left,
                directions.right,
                directions.bottom,
            ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            let subFontText = directionLabels.max(by: { $0.count < $1.count }) ?? ""
            let subFont = Design.fonts.keyLabelFont(text: subFontText, width: width, fontSize: .xxsmall, userDecidedSize: inputKeyViewFontSize, theme: theme)
            DirectionalKeyLabel(main: mainText, directions: directions, font: font, subFont: subFont)
                .foregroundStyle(mainKeyColor)
                .allowsHitTesting(false)
        case let .image(imageName):
            Image(systemName: imageName)
                .font(Design.fonts.iconImageFont(keyViewFontSizePreference: Extension.SettingProvider.keyViewFontSize, theme: theme))
                .foregroundStyle(mainKeyColor)
                .allowsHitTesting(false)

        case let .customImage(imageName):
            Image(imageName)
                .resizable()
                .frame(width: 30, height: 30, alignment: .leading)
                .allowsHitTesting(false)

        case .changeKeyboard:
            (self.action.makeChangeKeyboardButtonView() as ChangeKeyboardButtonView<Extension>)
                .foregroundStyle(mainKeyColor)

        case .changeKeyboardAndEmoji:
            // 左半分は地球儀（UIKit のボタン。タップで次のキーボード・長押しで一覧）、
            // 右半分は絵文字タブへ切り替えるボタン。どちらも UIKit のボタンが自分でタッチを受ける
            // 片手モードで幅が狭いときは、半分の幅に収まるようにアイコンを縮める
            let iconSize = Design.fonts.iconFontSize(keyViewFontSizePreference: Extension.SettingProvider.keyViewFontSize)
            let halfWidth = KeyLabelType.splitHalfWidth(totalWidth: width, gap: splitKeyGap)
            let scale = KeyLabelType.splitIconScale(halfWidth: halfWidth, iconSize: iconSize)
            // アイコンの画像だけを縮める（scaleEffect だとボタンの押せる範囲まで縮む。ai-review の指摘）
            HStack(spacing: splitKeyGap) {
                (self.action.makeChangeKeyboardButtonView() as ChangeKeyboardButtonView<Extension>)
                    .foregroundStyle(mainKeyColor)
                    .environment(\.changeKeyboardIconMaxSize, iconSize * scale)
                    .frame(width: halfWidth)
                EmojiTabButtonView<Extension>(size: iconSize * scale) {
                    KeyboardFeedback<Extension>.tabOrOtherKey()
                    self.action.registerAction(.moveTab(.system(.emoji_tab)), variableStates: self.variableStates)
                }
                .frame(width: halfWidth)
            }

        case let .selectable(primary, secondery):
            let font = Design.fonts.keyLabelFont(text: primary + primary, width: width, fontSize: self.textSize, userDecidedSize: keyViewFontSize, theme: theme)
            let subFont = Design.fonts.keyLabelFont(text: secondery + secondery, width: width, fontSize: .small, userDecidedSize: keyViewFontSize, theme: theme)

            HStack(alignment: .bottom) {
                Text(primary)
                    .font(font)
                    .padding(.trailing, -5)
                    .foregroundStyle(mainKeyColor)
                Text(secondery)
                    .font(subFont.bold())
                    .foregroundStyle(.gray)
                    .padding(.leading, -5)
                    .offset(y: -1)
            }.allowsHitTesting(false)
        }
    }

    consuming func textColor(_ color: Color?) -> Self {
        self.textColor = color
        return self
    }
    consuming func textSize(_ textSize: Design.Fonts.LabelFontSizeStrategy) -> Self {
        self.textSize = textSize
        return self
    }
}

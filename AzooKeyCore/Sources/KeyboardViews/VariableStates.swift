//
//  VariableStates.swift
//  Keyboard
//
//  Created by ensan on 2021/02/06.
//  Copyright © 2021 ensan. All rights reserved.
//

import CustardKit
import Foundation
import enum KanaKanjiConverterModule.InputStyle
import enum KanaKanjiConverterModule.KeyboardLanguage
import SwiftUI
import SwiftUIUtils
import SwiftUtils
import UIKit

/// 実行中変更され、かつViewがvariationSpace(variableStates: VariableStates)変更を検知できるべき値。
public final class VariableStates: ObservableObject {
    @MainActor public init(
        interfaceWidth: CGFloat? = nil,
        orientation: KeyboardOrientation? = nil,
        clipboardHistoryManagerConfig: any ClipboardHistoryManagerConfiguration,
        tabManagerConfig: any TabManagerConfiguration,
        userDefaults: UserDefaults,
        sharedUserDefaults: UserDefaults? = nil,
        layoutIdiom: KeyboardLayoutIdiom? = nil
    ) {
        self.layoutIdiom = layoutIdiom ?? .current
        self.tabManager = TabManager(config: tabManagerConfig)
        self.clipboardHistoryManager = ClipboardHistoryManager(config: clipboardHistoryManagerConfig)
        self.keyboardInternalSettingManager = KeyboardInternalSettingManager(userDefaults: userDefaults)
        self.reportSuggestionState = if let sharedUserDefaults {
            ReportSuggestionState(storageUserDefaults: sharedUserDefaults)
        } else {
            nil
        }
        if let interfaceWidth {
            self.setContainerWidth(interfaceWidth, orientation: orientation ?? .vertical)
        } else if let orientation {
            // 小さめの値を適当に入れる
            self.setContainerWidth(200, orientation: orientation)
        }
    }

    @MainActor
    public func setTabForPreview(_ tab: KeyboardTab.ExistentialTab) {
        self.tabManager.moveTab(
            to: .existential(tab),
            variableStates: self
        )
    }

    public struct BoolStates: CustardExpressionEvaluatorContext {
        public func getValue(for key: String) -> ExpressionValue? {
            if let boolValue = self[key] {
                return .bool(boolValue)
            }
            return nil
        }

        var isTextMagnifying = false
        var hasUpsideComponent = false
        public var isCapsLocked = false
        public var isShifted = false

        static let isCapsLockedKey = "isCapsLocked"
        public static let isShiftedKey = "isShifted"
        static let hasUpsideComponentKey = "is_screen_expanded"
        static let hasFullAccessKey = "has_full_access"
        // ビルトインのステートとカスタムのステートの両方を適切に扱いたい
        fileprivate var custardStates: [String: Bool] = [:]

        public func evaluateExpression(_ compiledExpression: CompiledExpression) -> Bool? {
            debug(self.custardStates)
            do {
                let condition = try CustardExpressionEvaluator(context: self).evaluate(compiledExpression: compiledExpression)
                if case let .bool(value) = condition {
                    return value
                }
                return nil
            } catch {
                debug("evaluateExpression", error)
                return nil
            }
        }

        mutating func initializeState(_ key: String, with value: Bool) {
            if !self.custardStates.keys.contains(key) {
                self.custardStates[key] = value
            }
        }

        public subscript(_ key: String) -> Bool? {
            get {
                if key == "isTextMagnifying" {
                    return self.isTextMagnifying
                } else if key == Self.hasFullAccessKey {
                    return SemiStaticStates.shared.hasFullAccess
                } else if key == Self.isCapsLockedKey {
                    return self.isCapsLocked
                } else if key == Self.isShiftedKey {
                    return self.isShifted
                } else if key == Self.hasUpsideComponentKey {
                    return self.hasUpsideComponent
                }
                return custardStates[key]
            }
            set {
                if let newValue {
                    if key == Self.hasFullAccessKey || key == Self.hasUpsideComponentKey {
                        // subscript経由ではRead Onlyにする
                        return
                    } else if key == "isTextMagnifying" {
                        self.isTextMagnifying = newValue
                    } else if key == Self.isShiftedKey {
                        self.isCapsLocked = self.isCapsLocked && !newValue
                        self.isShifted = newValue
                    } else if key == Self.isCapsLockedKey {
                        self.isShifted = self.isShifted && !newValue
                        self.isCapsLocked = newValue
                    } else {
                        custardStates[key] = newValue
                    }
                }
            }
        }
    }
    @MainActor private(set) public var inputStyle: InputStyle = .direct
    @Published private(set) public var tabManager: TabManager
    @Published public var keyboardInternalSettingManager: KeyboardInternalSettingManager
    @Published public var clipboardHistoryManager: ClipboardHistoryManager

    @Published public var keyboardLanguage: KeyboardLanguage = .ja_JP
    @Published private(set) public var keyboardOrientation: KeyboardOrientation = .vertical
    public let layoutIdiom: KeyboardLayoutIdiom

    public var layoutContext: KeyboardLayoutContext {
        KeyboardLayoutContext(
            containerWidth: containerWidth,
            orientation: keyboardOrientation,
            idiom: layoutIdiom
        )
    }

    @MainActor private(set) public var keyboardType: UIKeyboardType = .default
    @MainActor @Published private(set) public var textContentType: UITextContentType?

    /// `ResultModel`の変数
    @Published public var resultModel = ResultModel()

    // Bool値の変数はここにまとめる
    @Published public var boolStates = BoolStates()

    // 片手モードの実行時、キーボードの幅はinterfaceSizeによって決定できる。
    @Published private(set) public var containerWidth: CGFloat = 0
    @Published public var interfaceSize: CGSize = .zero
    @Published public var interfacePosition: CGPoint = .zero
    @Published public var interfaceBottomOffset: CGFloat = 0

    /// 外部では利用しないが、`enterKeyState`の更新時に必要になる
    @MainActor private(set) public var returnKeyType: UIReturnKeyType = .default
    @Published private(set) var enterKeyState: EnterKeyState = .return(.default)

    @Published public var barState: BarState = .none

    @Published var magnifyingText = ""

    @Published public var upsideComponent: UpsideComponent?

    @MainActor public func setHasUpsideComponent(_ value: Bool) {
        self.boolStates.hasUpsideComponent = value
    }

    /// 片手モード編集状態
    @Published public var resizingState: ResizingState = .fullwidth

    @Published public var maximumHeight: CGFloat = 0

    @Published public var heightScaleFromKeyboardHeightSetting: CGFloat = 1

    /// 周囲のテキストが変化した場合にインクリメントする値。変化の検出に利用する。
    /// - note: この値がどれだけ変化するかは実装によるので、変化量は意味をなさない。
    @Published public var textChangedCount: Int = 0

    public struct UndoAction: Equatable {
        public init(action: ActionType, textChangedCount: Int) {
            self.action = action
            self.textChangedCount = textChangedCount
        }

        var action: ActionType
        var textChangedCount: Int
    }

    @Published public var undoAction: UndoAction?

    public struct SurroundingText: Equatable, Hashable, Sendable {
        public var leftSideText: String = ""
        public var centerText: String = ""
        public var rightSideText: String = ""
    }
    @Published private(set) public var surroundingText = SurroundingText()

    @Published public var temporalMessage: TemporalMessage?

    @Published public var reportSuggestionState: ReportSuggestionState?
    @Published public var reportDetailState: ReportDetailState?

    public func setSurroundingText(leftSide: String, center: String, rightSide: String) {
        self.surroundingText.leftSideText = leftSide
        self.surroundingText.centerText = center
        self.surroundingText.rightSideText = rightSide
    }

    @MainActor public var isShowingPrimaryResults: Bool {
        self.resultModel.displayState == .results
    }

    @MainActor public func primaryResultCandidate(at index: Int) -> (any ResultViewItemData)? {
        guard self.resultModel.displayState == .results else { return nil }
        guard self.resultModel.resultData.indices.contains(index) else { return nil }
        return self.resultModel.resultData[index].candidate
    }

    @MainActor public func setResizingMode(_ state: ResizingState) {
        let baseHeight = Design.keyboardHeight(context: layoutContext)
        switch state {
        case .fullwidth:
            let height = keyboardInternalSettingManager.oneHandedModeSetting.heightItem(orientation: keyboardOrientation).height
            interfaceSize = .init(
                width: containerWidth,
                height: Design.fixedFullWidthInterfaceHeight ?? (height ?? baseHeight) * self.heightScaleFromKeyboardHeightSetting
            )
            interfacePosition = .zero
            interfaceBottomOffset = 0

        case .onehanded:
            break

        case .resizing:
            // リサイズ開始時は、保存された値から初期状態を読み込むので変更なし
            let item = keyboardInternalSettingManager.oneHandedModeSetting.item(orientation: keyboardOrientation)
            let height = keyboardInternalSettingManager.oneHandedModeSetting.heightItem(orientation: keyboardOrientation).height
            interfaceSize = CGSize(width: min(item.width, containerWidth), height: (height ?? baseHeight) * heightScaleFromKeyboardHeightSetting)
            interfacePosition = CGPoint(x: item.position.x, y: 0)
            // TypeAI: キーボードの下に間は空けない（下のハンドルは廃止。以前に保存した値も使わない）
            interfaceBottomOffset = 0
        }

        // 以下の処理は全ケースで共通
        self.maximumHeight = interfaceSize.height + interfaceBottomOffset
        self.resizingState = state
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) {value in
            value.update(orientation: keyboardOrientation) {value in
                value.isLastOnehandedMode = state != .fullwidth
            }
        }
    }

    @MainActor public func initialize() {
        self.tabManager.initialize(variableStates: self)
    }

    @MainActor public func closeKeyboard() {
        self.tabManager.closeKeyboard()
        self.upsideComponent = nil
        // 変更する
        self.textChangedCount += 1
        // このタイミングでクリップボードを確認する
        self.clipboardHistoryManager.checkUpdate()
        // 保存処理を行う
        self.clipboardHistoryManager.save()
    }

    @MainActor public func setKeyboardType(_ type: UIKeyboardType?) {
        debug("setKeyboardType:", type.debugDescription)
        guard let type else {
            return
        }
        self.keyboardType = type
        switch type {
        case .default, .asciiCapable:
            return
        case .numbersAndPunctuation:
            return
        case .URL:
            self.setTab(.user_dependent(.english), temporary: true)
        case .numberPad:
            self.setTab(.existential(.custard(.numberPad)), temporary: true)
        case .phonePad:
            self.setTab(.existential(.custard(.phonePad)), temporary: true)
        case .namePhonePad:
            return
        case .emailAddress:
            self.setTab(.user_dependent(.english), temporary: true)
        case .decimalPad:
            self.setTab(.existential(.custard(.decimalPad)), temporary: true)
        case .twitter:
            return
        case .webSearch:
            return
        case .asciiCapableNumberPad:
            return
        @unknown default:
            return
        }
    }

    @MainActor public func setTextContentType(_ type: UITextContentType?) {
        guard self.textContentType != type else {
            return
        }
        self.textContentType = type
    }

    @MainActor public func setEnterKeyState(_ state: RoughEnterKeyState) {
        switch state {
        case .return:
            self.enterKeyState = .return(returnKeyType)
        case .complete:
            self.enterKeyState = .complete
        }
    }

    @MainActor private func setTab(_ tab: KeyboardTab, temporary: Bool = false) {
        if temporary {
            self.tabManager.setTemporalTab(tab, variableStates: self)
        } else {
            self.tabManager.moveTab(to: tab, variableStates: self)
        }
    }

    @MainActor public func setTab(_ tab: TabData, temporary: Bool = false) {
        let tab = tab.tab(config: self.tabManager.config)
        self.setTab(tab, temporary: temporary)
    }

    @MainActor public func setUIReturnKeyType(type: UIReturnKeyType) {
        self.returnKeyType = type
        if case let .return(prev) = self.enterKeyState, prev != type {
            self.setEnterKeyState(.return)
        }
    }

    @MainActor public func updateResizingState() {
        let isLastOnehandedMode = keyboardInternalSettingManager.oneHandedModeSetting.item(orientation: keyboardOrientation).isLastOnehandedMode
        if isLastOnehandedMode {
            self.setResizingMode(.onehanded)
        } else {
            self.setResizingMode(.fullwidth)
        }
    }

    /// TypeAI: このプロセスで最後に知らされた画面（`setOneHandedModeProfile`）
    private var oneHandedModeProfile: String?

    /// TypeAI: サイズ調整の保存値をどの画面のものとして使うかを知らせる。表示のたびに `setContainerWidth` より前に呼ぶ。
    ///
    /// - 画面が変わったら（iPhone Duo を開いた・閉じた）その画面の保存値に入れ替え、前回のモード（全幅 / 片手）に戻す
    /// - プロセスで最初の呼び出しでも前回のモードに戻す。`resizingState` の初期値は全幅で、向きが変わらない限り
    ///   `updateResizingState` が呼ばれないため、縮めて確定した枠が時間をおいて開くと全幅に戻っていた（2026-11-25 ユーザー指摘）
    @MainActor public func setOneHandedModeProfile(_ id: String) {
        guard oneHandedModeProfile != id else {
            return
        }
        let isFirst = oneHandedModeProfile == nil
        oneHandedModeProfile = id
        let switched = keyboardInternalSettingManager.switchOneHandedModeProfile(to: id)
        if switched || isFirst {
            updateResizingState()
        }
    }

    @MainActor public func setInputStyle(_ style: InputStyle) {
        self.inputStyle = style
    }

    @MainActor public func setContainerWidth(_ width: CGFloat, orientation: KeyboardOrientation) {
        guard width > 0 else {
            return
        }
        containerWidth = width
        let updatedContext = KeyboardLayoutContext(
            containerWidth: width,
            orientation: orientation,
            idiom: layoutIdiom
        )
        let height = Design.keyboardHeight(context: updatedContext)
        if self.keyboardOrientation != orientation {
            self.keyboardOrientation = orientation
            self.updateResizingState()
        }
        // 片手モードの処理
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) {value in
            value.setIfFirst(orientation: orientation, size: .init(width: width, height: height), position: .zero)
        }
        let idealHeight = keyboardInternalSettingManager.oneHandedModeSetting.heightItem(orientation: orientation).height
        let ignoreStoredHeight = layoutIdiom == .pad && width < 400
        let effectiveHeight = (ignoreStoredHeight ? height : (idealHeight ?? height)) * heightScaleFromKeyboardHeightSetting
        switch self.resizingState {
        case .fullwidth:
            self.interfaceSize = CGSize(width: width, height: Design.fixedFullWidthInterfaceHeight ?? effectiveHeight)
            self.interfaceBottomOffset = 0
        case .onehanded:
            let item = keyboardInternalSettingManager.oneHandedModeSetting.item(orientation: orientation)
            // 安全のため、指示されたwidth, heightを超える値を許可しない。
            self.interfaceSize = CGSize(width: min(width, item.width), height: effectiveHeight)
            self.interfacePosition = ignoreStoredHeight ? .zero : CGPoint(x: item.position.x, y: 0)
            // TypeAI: キーボードの下に間は空けない（下のハンドルは廃止。以前に保存した値も使わない）
            self.interfaceBottomOffset = 0
        case .resizing:
            if ignoreStoredHeight {
                // iPad のフローティング表示へ移ったときは従来どおり作り直す（保存値の高さ・位置は使えない）
                self.interfaceSize = CGSize(width: min(width, self.interfaceSize.width), height: effectiveHeight)
                self.interfacePosition = .zero
            } else {
                // TypeAI: 調整中の枠の高さは作り直さない。ホストはいま表示している高さから枠を始めるが、
                // 調整中にレイアウトが走ってここで保存値の高さに戻すと、枠が上にめり込んだり
                // （保存値の方が高い）上が減ったり（低い）した（2026-11-23 ユーザー指摘）。幅と位置は画面に収める
                let newWidth = min(width, self.interfaceSize.width)
                let slack = (width - newWidth) / 2
                self.interfaceSize.width = newWidth
                self.interfacePosition = CGPoint(x: min(max(self.interfacePosition.x, -slack), slack), y: 0)
            }
            self.interfaceBottomOffset = 0
        }
    }

    @available(*, deprecated, renamed: "setContainerWidth(_:orientation:)")
    @MainActor public func setInterfaceSize(orientation: KeyboardOrientation, screenWidth: CGFloat) {
        setContainerWidth(screenWidth, orientation: orientation)
    }

    /// TypeAI: 片手モードの左右寄せを反転する（幅はそのまま、空いている広い方の端へ寄せる）。
    /// 保存するのは位置だけ（高さまで保存すると、高さの倍率を使うホストで倍率が二重にかかる）
    @MainActor public func flipOneHandedAlignment() {
        let newX = OneHandedHorizontalResize.positionXAlignedToWiderMargin(
            positionX: interfacePosition.x,
            width: interfaceSize.width,
            containerWidth: containerWidth
        )
        interfacePosition = CGPoint(x: newX, y: 0)
        let orientation = keyboardOrientation
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.update(orientation: orientation) { item in
                item.position = CGPoint(x: newX, y: 0)
            }
        }
    }

    /// TypeAI: ホストが決めた枠（幅・高さ・中央からのずれ）で片手モードを始め、その枠を保存する。
    /// 縦に長く横に広い画面（iPhone Duo の内側の縦持ち・iPad mini の縦）で、全幅だと大きすぎるときの既定に使う。
    /// 幅は画面に、位置は空きの範囲に収める
    @MainActor public func startOneHandedMode(width: CGFloat, height: CGFloat, positionX: CGFloat) {
        let newWidth = min(max(width, 0), containerWidth)
        let slack = (containerWidth - newWidth) / 2
        let newX = min(max(positionX, -slack), slack)
        // 保存した高さに倍率をかけ直さないよう、実行中の倍率も戻す（`resetResizingFrame` と同じ。ai-review の指摘）
        heightScaleFromKeyboardHeightSetting = 1
        interfaceSize = CGSize(width: newWidth, height: height)
        interfacePosition = CGPoint(x: newX, y: 0)
        interfaceBottomOffset = 0
        let orientation = keyboardOrientation
        let size = interfaceSize
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: orientation, size: size, position: CGPoint(x: newX, y: 0), bottomOffset: 0)
            // 次に表示したときも、保存した高さに古い倍率をかけ直さない
            value.setUserHasOverwrittenKeyboardHeightSetting(orientation: orientation)
        }
        setResizingMode(.onehanded)
    }

    /// TypeAI: サイズ調整中のリセット。サイズ調整モードは続けたまま、全幅・100% の枠に戻して保存する
    /// （以前の `resetOneHandedModeSetting` はモードごと抜けていた。2026-11-23 ユーザー指摘）
    @MainActor public func resetResizingFrame() {
        let fullHeight = OneHandedResizeFrame.fullHeight(context: layoutContext)
        heightScaleFromKeyboardHeightSetting = 1
        maximumHeight = max(maximumHeight, fullHeight)
        interfaceSize = CGSize(width: containerWidth, height: fullHeight)
        interfacePosition = .zero
        interfaceBottomOffset = 0
        let orientation = keyboardOrientation
        let size = interfaceSize
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: orientation, size: size, position: .zero, bottomOffset: 0)
            // 確定せずに閉じても、次に表示したとき古い高さの倍率をかけ直さない
            value.setUserHasOverwrittenKeyboardHeightSetting(orientation: orientation)
        }
    }

    @MainActor
    public func resetOneHandedModeSetting() {
        // 設定管理オブジェクトを通じて、oneHandedModeSettingを更新する
        keyboardInternalSettingManager.update(\.oneHandedModeSetting) { setting in
            // ステップ1: まず、カスタム設定をまっさらな状態にリセットする
            setting.reset(orientation: self.keyboardOrientation)

            // ステップ2: 次に、リセットされた項目に「本来のデフォルト値」を再設定する
            // 保存するのは本体の高さ（interfaceSize）。キーボード下の余白（keyboardScreenBottomPadding）は
            // KeyboardView が本体の外に足すので、ここに含めると余白が二重に乗る
            let defaultHeight = Design.keyboardHeight(context: layoutContext)
            let defaultSize = CGSize(width: containerWidth, height: defaultHeight)
            setting.setIfFirst(orientation: self.keyboardOrientation, size: defaultSize, position: .zero, forced: true) // forced: trueで確実に上書きする
        }

        // `updateResizingState()`を呼んで、UIに即時反映させる
        // これにより、リセット後の正しいデフォルトサイズが画面に表示される
        DispatchQueue.main.async {
            self.updateResizingState()
        }
    }

}

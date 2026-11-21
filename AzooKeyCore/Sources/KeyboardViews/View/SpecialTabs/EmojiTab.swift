//
//  EmojiTab.swift
//  azooKey
//
//  Created by ensan on 2023/03/15.
//  Copyright © 2023 ensan. All rights reserved.
//

import KeyboardThemes
import SwiftUI
import SwiftUtils

@MainActor
struct EmojiTab<Extension: ApplicationSpecificKeyboardViewExtension>: View {
    @EnvironmentObject private var variableStates: VariableStates
    @Environment(Extension.Theme.self) private var theme

    fileprivate struct EmojiData: Identifiable {
        init(emoji: String, base: String) {
            self.emoji = emoji
            self.base = base
            self.id = UUID()
        }

        var emoji: String
        var base: String
        var id: UUID
    }

    fileprivate enum Genre: UInt8, CaseIterable, Identifiable {
        /// 最近使った絵文字
        case recent

        /// 😁👪👩‍🦼👩‍💻
        case smileys

        /// 🐱🍄☀️🔥
        case natures

        /// ☕️🍰🍉🍞
        case eats

        /// ⚽️🏄🥇🎲
        case activities

        /// 🚗🏔🌊🚥
        case trips

        /// 🗒💽🔍💻
        case items

        /// ♌️❤️💮🎵
        case symbols

        /// 🏳️‍🌈🇯🇵🇺🇳🇰🇷
        case flags

        var id: UInt8 {
            self.rawValue
        }

        var icon: String {
            switch self {
            case .smileys:
                return "face.smiling"
            case .natures:
                return "pawprint"
            case .eats:
                return "cup.and.saucer"
            case .activities:
                return "soccerball"
            case .trips:
                return "car"
            case .items:
                return "lightbulb"
            case .symbols:
                return "heart"
            case .flags:
                return "flag"
            case .recent:
                return "clock"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .smileys:
                return "顔と感情"
            case .natures:
                return "生き物と自然"
            case .eats:
                return "食事"
            case .activities:
                return "アクティビティ"
            case .trips:
                return "旅行と場所"
            case .items:
                return "物"
            case .symbols:
                return "記号"
            case .flags:
                return "旗"
            case .recent:
                return "よく使う絵文字"
            }
        }

        var next: Genre? {
            switch self {
            case .recent:
                return .smileys
            case .smileys:
                return .natures
            case .natures:
                return .eats
            case .eats:
                return .activities
            case .activities:
                return .trips
            case .trips:
                return .items
            case .items:
                return .symbols
            case .symbols:
                return .flags
            case .flags:
                return nil
            }
        }

        var prev: Genre? {
            switch self {
            case .recent:
                return nil
            case .smileys:
                return .recent
            case .natures:
                return .smileys
            case .eats:
                return .natures
            case .activities:
                return .eats
            case .trips:
                return .activities
            case .items:
                return .trips
            case .symbols:
                return .items
            case .flags:
                return .symbols
            }
        }
    }

    /// TypeAI: フリック配列の横に埋め込むときの大きさ（`Design.embeddedEmojiPanels`）。nil なら絵文字タブとして全体に出す
    private let embeddedSize: CGSize?

    /// 参考用
    private var keysHeight: CGFloat {
        if let embeddedSize { return embeddedSize.height }
        return TabDependentDesign(
            width: 1,
            height: 1,
            interfaceSize: variableStates.interfaceSize,
            layoutContext: variableStates.layoutContext
        ).keysHeight
    }

    private var footerHeight: CGFloat {
        // 埋め込みは高さが低いので、カテゴリのボタンが押せる大きさを保つ
        embeddedSize == nil ? keysHeight * 0.12 : max(28, keysHeight * 0.16)
    }

    private var scrollViewHeight: CGFloat {
        // 埋め込みは渡された高さに収める（フッターとの間の 6pt も引く）
        embeddedSize == nil ? keysHeight - footerHeight : keysHeight - footerHeight - 6
    }

    private var verticalCount: Int {
        switch variableStates.keyboardOrientation {
        case .vertical: return 5
        case .horizontal: return 3
        }
    }

    private var allGenre: [Genre] {
        Genre.allCases.sorted(by: {$0.rawValue < $1.rawValue})
    }

    @State private var emojis: [Genre: [EmojiData]] = [:]

    @State private var selectedGenre: Genre = .smileys

    init() {
        self.embeddedSize = nil
    }

    /// TypeAI: フリック配列の横に埋め込む。「戻る」キーは出さない（タブを移っていないので戻り先が無い）
    init(embeddedSize: CGSize) {
        self.embeddedSize = embeddedSize
    }

    private var panelWidth: CGFloat {
        embeddedSize?.width ?? variableStates.interfaceSize.width
    }
    // 正方形のキーにする
    /// 行のあいだの間隔（`EmojiScrollContent` の `GridItem` と `LazyHGrid` の spacing）
    fileprivate static var rowSpacing: CGFloat { 5 }

    private var keySize: CGFloat {
        // 行の間隔を引いてから割る。引かないと行数 × 間隔ぶんグリッドが表示領域からはみ出し、外側の行が欠ける
        (scrollViewHeight - Self.rowSpacing * CGFloat(verticalCount - 1)) / CGFloat(verticalCount)
    }

    private static func getEmojiDataItem(for emoji: String, replacements: [String: String]) -> EmojiData {
        .init(emoji: replacements[emoji, default: emoji], base: emoji)
    }

    /// EmojiDictionaryを含むバンドルディレクトリを探す
    private static func findEmojiDictionaryURL() -> URL? {
        let mainBundleURL = Bundle.main.bundleURL
        // サブバンドル内の EmojiDictionary を探索
        if let contents = try? FileManager.default.contentsOfDirectory(at: mainBundleURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "bundle" {
                let emojiDir = url.appendingPathComponent("EmojiDictionary", isDirectory: true)
                if FileManager.default.fileExists(atPath: emojiDir.path) {
                    return emojiDir
                }
            }
        }
        // フォールバック: Bundle.main 直下
        return mainBundleURL
    }

    private static func getEmojis(keyboardInternalSettingManager: KeyboardInternalSettingManager) -> [Genre: [EmojiData]] {
        let fileURL: URL
        // 読み込むファイルはバージョンごとに変更する必要がある
        guard let emojiDir = findEmojiDictionaryURL() else {
            debug("EmojiDictionary not found in any bundle")
            return [:]
        }
        let fileName: String
        if #available(iOS 26.4, *) {
            fileName = "emoji_genre_E17.0.txt"
        } else if #available(iOS 18.4, *) {
            fileName = "emoji_genre_E16.0.txt"
        } else {
            fileName = "emoji_genre_E15.1.txt"
        }
        fileURL = emojiDir.appendingPathComponent(fileName, isDirectory: false)
        // ファイルが存在しない場合、利用可能な最新バージョンにフォールバック
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let fallbackNames = ["emoji_genre_E16.0.txt", "emoji_genre_E15.1.txt", "emoji_genre_E15.0.txt", "emoji_genre_E14.0.txt", "emoji_genre_E13.1.txt"]
            var foundURL: URL?
            for name in fallbackNames {
                let candidate = emojiDir.appendingPathComponent(name, isDirectory: false)
                if FileManager.default.fileExists(atPath: candidate.path) {
                    foundURL = candidate
                    break
                }
            }
            guard let fallback = foundURL else {
                debug("No emoji_genre file found in \(emojiDir.path)")
                return [:]
            }
            return loadEmojis(from: fallback, keyboardInternalSettingManager: keyboardInternalSettingManager)
        }
        return loadEmojis(from: fileURL, keyboardInternalSettingManager: keyboardInternalSettingManager)
    }

    private static func loadEmojis(from fileURL: URL, keyboardInternalSettingManager: KeyboardInternalSettingManager) -> [Genre: [EmojiData]] {
        let genres: [String: Genre] = [
            "Symbols": .symbols,
            "Flags": .flags,
            "Food & Drink": .eats,
            "Smileys & People": .smileys,
            "Activities": .activities,
            "Animals & Nature": .natures,
            "Travel & Places": .trips,
            "Objects": .items,
        ]
        let ignoredGenre = ["Component"]
        var emojis: [Genre: [String]] = [:]
        do {
            let string = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = string.split(separator: "\n")
            for line in lines {
                let splited = line.split(separator: "\t", omittingEmptySubsequences: false)
                guard splited.count == 2 else {
                    debug("error", line)
                    return [:]
                }
                if ignoredGenre.contains(String(splited[0])) {
                    continue
                }
                guard let genre = genres[String(splited[0])] else {
                    debug("unknown genre", line)
                    return [:]
                }
                emojis[genre, default: []].append(contentsOf: splited[1].split(separator: ",").map(String.init))
            }
        } catch {
            debug("Failed to load emoji file: \(fileURL.path), error: \(error)")
            return [:]
        }
        // 使った絵文字は EmojiKeyModel が UserDefaults に直接書く（再描画を避けるため）ので、メモリ上の値ではなく保存値を読む
        let preference = KeyboardInternalSettingManager(userDefaults: keyboardInternalSettingManager.userDefaults).tabCharacterPreference
        let recentlyUsed = preference.getRecentlyUsed(for: .system(.emoji), count: 32)
        emojis[.recent] = recentlyUsed

        let replacements = preference.getPreferences(for: .system(.emoji))
        return emojis.mapValues {
            $0.map {
                getEmojiDataItem(for: $0, replacements: replacements)
            }
        }
    }

    private var functionKeyWidth: CGFloat {
        // 埋め込みは幅が半分ほどなので、削除キーが小さくなりすぎないよう割る数を減らす
        panelWidth / (embeddedSize == nil ? 13 : 7)
    }

    private func deleteKey() -> SimpleKeyView<Extension> {
        SimpleKeyView(model: SimpleKeyModel<Extension>(keyLabelType: .image("delete.left"), unpressedKeyColorType: .special, pressActions: [.delete(1)], longPressActions: .init(repeat: [.delete(1)])), width: functionKeyWidth, height: footerHeight)
    }


    private func backTabKey() -> SimpleKeyView<Extension> {
        SimpleKeyView(model: SimpleKeyModel<Extension>(keyLabelType: .text("戻る"), unpressedKeyColorType: .special, pressActions: [.moveTab(.system(.last_tab))], longPressActions: .none), width: functionKeyWidth * 2, height: footerHeight)
    }

    @State private var scrollProxy: ScrollViewProxy?

    private func genreButton(_ genre: Genre) -> some View {
        Button {
            self.selectedGenre = genre
            if let proxy = scrollProxy {
                proxy.scrollTo("genre_\(genre.rawValue)", anchor: .leading)
            }
        } label: {
            Image(systemName: genre.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(genre == selectedGenre ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    genre == selectedGenre
                        ? Circle().fill(Color(uiColor: .systemGray3))
                        : Circle().fill(Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 絵文字スクロール領域（子Viewに切り出して不要な再描画を防止）
            EmojiScrollContent<Extension>(
                emojis: emojis,
                allGenre: allGenre,
                keySize: keySize,
                verticalCount: verticalCount,
                simplyInsert: embeddedSize != nil,
                onProxyReady: { self.scrollProxy = $0 }
            )
            .frame(height: scrollViewHeight)

            Spacer().frame(height: embeddedSize == nil ? 18 : 6)

            // フッター（ネイティブ風カテゴリバー）
            HStack(spacing: 0) {
                if embeddedSize == nil {
                    backTabKey()
                }
                ForEach(allGenre, id: \.self) { genre in
                    if !self.emojis[genre, default: []].isEmpty {
                        genreButton(genre)
                    }
                }
                deleteKey()
            }
            .frame(height: footerHeight)
            .padding(.horizontal, 4)
        }
        .frame(width: panelWidth)
        .onAppear {
            self.updateEmojiData()
            if !self.emojis[.recent, default: []].isEmpty {
                self.selectedGenre = .recent
            }
            // 埋め込みのときはフリックで変換中なので、候補を消さない
            guard embeddedSize == nil else { return }
            variableStates.resultModel.setResults([])
            variableStates.barState = .none
        }
        .onDisappear {
            guard embeddedSize == nil else { return }
            variableStates.resultModel.setResults([])
        }
    }

    /// 絵文字データを読み込む（タブ表示時のみ呼ぶ。入力中の更新はレンダリングずれを起こすため避ける）
    private func updateEmojiData() {
        self.emojis = Self.getEmojis(keyboardInternalSettingManager: variableStates.keyboardInternalSettingManager)
    }
}

private struct ExpandKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: SimpleKeyModelProtocol {
    private var currentLevel: EmojiTabExpandModePreference.Level
    private var action: () -> Void
    func label(width: CGFloat, states: VariableStates) -> KeyLabel<Extension> {
        KeyLabel(.image(self.currentLevel.icon), width: width, textSize: .max)
    }

    init(currentLevel: EmojiTabExpandModePreference.Level, action: @escaping () -> Void) {
        self.currentLevel = currentLevel
        self.action = action
    }
    let unpressedKeyColorType: SimpleUnpressedKeyColorType = .special

    func pressActions(variableStates: VariableStates) -> [ActionType] {
        []
    }
    func longPressActions(variableStates: VariableStates) -> LongpressActionType {
        .none
    }
    func feedback(variableStates: VariableStates) {
        KeyboardFeedback<Extension>.tabOrOtherKey()
    }
    func additionalOnPress(variableStates: VariableStates) {
        self.action()
    }
}

private struct GenreKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: SimpleKeyModelProtocol {
    private var action: () -> Void
    private var systemImage: String
    func label(width: CGFloat, states: VariableStates) -> KeyLabel<Extension> {
        KeyLabel(.image(systemImage), width: width, textSize: .max)
    }

    init(systemImage: String, unpressedKeyColorType: SimpleUnpressedKeyColorType, action: @escaping () -> Void) {
        self.action = action
        self.systemImage = systemImage
        self.unpressedKeyColorType = unpressedKeyColorType
    }
    let unpressedKeyColorType: SimpleUnpressedKeyColorType

    func pressActions(variableStates: VariableStates) -> [ActionType] {
        []
    }
    func longPressActions(variableStates: VariableStates) -> LongpressActionType {
        .none
    }
    func feedback(variableStates: VariableStates) {
        KeyboardFeedback<Extension>.tabOrOtherKey()
    }
    func additionalOnPress(variableStates: VariableStates) {
        self.action()
    }
}

private struct EmojiKeyModel<Extension: ApplicationSpecificKeyboardViewExtension>: SimpleKeyModelProtocol {
    init(_ emoji: String, base: String, simplyInsert: Bool = false) {
        self.emoji = emoji
        self.base = base
        self.simplyInsert = simplyInsert
    }

    /// TypeAI: フリック配列の横に埋め込んだときは、変換中の文字を確定してからそのまま入れる。
    /// 日本語のタブのまま押すので、普通に入れると変換中の文字に混ざり、変換で絵文字が化けた
    private let simplyInsert: Bool

    private let emoji: String
    private let base: String
    var unpressedKeyColorType: SimpleUnpressedKeyColorType {
        .unimportant
    }
    var longPressActions: LongpressActionType {
        .none
    }
    func label(width: CGFloat, states _: VariableStates) -> KeyLabel<Extension> {
        KeyLabel(.text(emoji), width: width, textSize: .max)
    }

    func additionalOnPress(variableStates: VariableStates) {
        // @Publishedのupdate経由だとVariableStatesのobjectWillChangeが発火しスクロールがリセットされる
        // UserDefaultsに直接書き込んで再描画を回避する
        // メモリ上の値は更新しない（上の理由）ので、毎回保存値から読み直す。読み直さないとタップのたびに前回の記録を上書きする
        var pref = KeyboardInternalSettingManager(userDefaults: variableStates.keyboardInternalSettingManager.userDefaults).tabCharacterPreference
        pref.setUsed(base: self.base, for: .system(.emoji))
        if let data = try? JSONEncoder().encode(pref) {
            variableStates.keyboardInternalSettingManager.userDefaults.set(data, forKey: "tab_character_preference")
        }
    }
    func pressActions(variableStates: VariableStates) -> [ActionType] {
        [.input(emoji, simplyInsert: simplyInsert)]
    }
    func longPressActions(variableStates: VariableStates) -> LongpressActionType {
        .none
    }
    func feedback(variableStates: VariableStates) {
        KeyboardFeedback<Extension>.click()
    }
}

/// 絵文字スクロール内容を分離したView
/// variableStatesの@Published変更による再描画を防ぎ、スクロール位置を安定させる
private struct EmojiScrollContent<Extension: ApplicationSpecificKeyboardViewExtension>: View {
    let emojis: [EmojiTab<Extension>.Genre: [EmojiTab<Extension>.EmojiData]]
    let allGenre: [EmojiTab<Extension>.Genre]
    let keySize: CGFloat
    let verticalCount: Int
    var simplyInsert = false
    let onProxyReady: (ScrollViewProxy) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
                let gridItem = GridItem(.fixed(keySize), spacing: EmojiTab<Extension>.rowSpacing)
                HStack(spacing: 8) {
                    ForEach(allGenre, id: \.self) { genre in
                        let models = emojis[genre, default: []]
                        if !models.isEmpty {
                            LazyHGrid(rows: Array(repeating: gridItem, count: verticalCount), spacing: 5) {
                                ForEach(models) { model in
                                    SimpleKeyView<Extension>(model: EmojiKeyModel<Extension>(model.emoji, base: model.base, simplyInsert: simplyInsert), width: keySize, height: keySize)
                                }
                            }
                            .padding(.horizontal, 3)
                            .id("genre_\(genre.rawValue)")
                        }
                    }
                }
                .padding(.horizontal, 5)
                .onAppear { onProxyReady(reader) }
            }
        }
    }
}

private extension EmojiTabExpandModePreference.Level {
    func next() -> Self {
        switch self {
        case .small: return .medium
        case .medium: return .large
        case .large: return .small
        }
    }

    var icon: String {
        switch self {
        case .small:
            return "arrow.up.left.and.arrow.down.right"
        case .medium:
            return "arrow.up.left.and.arrow.down.right"
        case .large:
            return "arrow.down.right.and.arrow.up.left"
        }
    }
}

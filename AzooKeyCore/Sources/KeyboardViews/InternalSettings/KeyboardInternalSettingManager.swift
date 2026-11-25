//
//  KeyboardInternalSettingManager.swift
//
//
//  Created by ensan on 2023/07/21.
//

import Foundation
import SwiftUIUtils

public struct KeyboardInternalSettingManager: UserDefaultsManager {
    public var userDefaults: UserDefaults

    public enum Keys: String, UserDefaultsKeys {
        public typealias Manager = KeyboardInternalSettingManager
        case one_handed_mode_setting
        case tab_character_preference
        case emoji_tab_expand_mode_preference

        public init(keyPath: PartialKeyPath<Manager>) {
            switch keyPath {
            case \Manager.oneHandedModeSetting:
                self = .one_handed_mode_setting
            case \Manager.tabCharacterPreference:
                self = .tab_character_preference
            case \Manager.emojiTabExpandModePreference:
                self = .emoji_tab_expand_mode_preference
            default:
                fatalError("Unknown Key Path: \(keyPath)")
            }
        }
    }

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.oneHandedModeSetting = Self.load(key: .one_handed_mode_setting, userDefaults: userDefaults)
        self.tabCharacterPreference = Self.load(key: .tab_character_preference, userDefaults: userDefaults)
        self.emojiTabExpandModePreference = Self.load(key: .emoji_tab_expand_mode_preference, userDefaults: userDefaults)
    }

    private(set) public var oneHandedModeSetting: OneHandedModeSetting
    private(set) public var tabCharacterPreference: TabCharacterPreference
    private(set) public var emojiTabExpandModePreference: EmojiTabExpandModePreference

    /// TypeAI: 画面ごとの保存値の置き場（いま使っていない画面のぶん）
    static func oneHandedModeProfileKey(_ id: String) -> String {
        "one_handed_mode_setting.profile.\(id)"
    }

    /// TypeAI: サイズ調整の保存値を画面ごとに切り替える（iPhone Duo の閉じた画面 / 開いた画面）。
    ///
    /// 縦 / 横は `OneHandedModeSetting` の中で分かれているので、画面 × 向きで別々の値になる。
    /// いまの値を前の画面の置き場へ移し、`id` の置き場の値（無ければ初期値）を読み込む。
    /// どの画面の値かは値そのもの（`OneHandedModeSetting.profile`）に入れて同じ保存単位で書くので、
    /// 途中で終了しても識別子と値が食い違わない（置き場を先に書き、いまの値は最後に 1 回で書く）。
    ///
    /// 画面を記録していない以前の版の保存値は引き継がず、初期値から始める。どの画面で保存したかが分からず
    /// （Duo の開いた画面の既定の片手モードを閉じた画面に持ち込みうる）、以前の TypeAI は拡張のプロセスが
    /// 作られるたびにこの保存値を消していたので、引き継がなくても失うものはそのプロセスの間の値だけ。
    /// - Returns: 保存値を入れ替えたか
    @discardableResult
    public mutating func switchOneHandedModeProfile(to id: String) -> Bool {
        let current = oneHandedModeSetting
        guard current.profile != id else {
            return false
        }
        if let active = current.profile, let data = try? JSONEncoder().encode(current) {
            userDefaults.set(data, forKey: Self.oneHandedModeProfileKey(active))
        }
        var next = userDefaults.data(forKey: Self.oneHandedModeProfileKey(id))
            .flatMap { try? JSONDecoder().decode(OneHandedModeSetting.self, from: $0) }
            ?? OneHandedModeSetting.initialValue
        next.profile = id
        update(\.oneHandedModeSetting, newValue: next)
        return true
    }
}

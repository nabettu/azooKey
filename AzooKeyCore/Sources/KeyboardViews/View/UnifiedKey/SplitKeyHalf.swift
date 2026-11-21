import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 地球儀と絵文字を半分ずつ並べるキーの、左右どちらの半分か（TypeAI）
enum SplitKeyHalf: Hashable, Sendable {
    case leading
    case trailing

    /// この半分を押した色にするか。中身の UIButton がタッチを先に受けるので、キー全体の押下判定ではなく
    /// ボタンが知らせた「押している側」だけで決める（隙間など、何も起きない所を押しても色は付けない）
    func isHighlighted(pressedHalves: Set<SplitKeyHalf>) -> Bool {
        pressedHalves.contains(self)
    }

    /// 押している側の集合を更新する。左右を別の指で押せるので、片方を離してももう片方は残す
    static func updated(_ pressedHalves: Set<SplitKeyHalf>, half: SplitKeyHalf, isPressed: Bool) -> Set<SplitKeyHalf> {
        var result = pressedHalves
        if isPressed {
            result.insert(half)
        } else {
            result.remove(half)
        }
        return result
    }
}

private struct SplitKeyPressChangeKey: EnvironmentKey {
    static let defaultValue: (@MainActor (SplitKeyHalf, Bool) -> Void)? = nil
}

private struct KeyButtonPressChangeKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Bool) -> Void)? = nil
}

extension EnvironmentValues {
    /// 分割キーの左右どちらかを押した・離したときに呼ぶ。キーの背景が受け取る
    var splitKeyPressChange: (@MainActor (SplitKeyHalf, Bool) -> Void)? {
        get { self[SplitKeyPressChangeKey.self] }
        set { self[SplitKeyPressChangeKey.self] = newValue }
    }

    /// 分割キーの中の UIButton が、押した・離したを知らせる先
    var keyButtonPressChange: (@MainActor (Bool) -> Void)? {
        get { self[KeyButtonPressChangeKey.self] }
        set { self[KeyButtonPressChangeKey.self] = newValue }
    }
}

#if canImport(UIKit)
/// UIButton の押下イベントを「押している / いない」に直して知らせる
@MainActor
public final class ButtonPressObserver: NSObject {
    var onChange: (@MainActor (Bool) -> Void)?

    func attach(to button: UIButton) {
        button.addTarget(self, action: #selector(pressed), for: [.touchDown, .touchDragEnter])
        button.addTarget(self, action: #selector(released), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
    }

    @objc private func pressed() {
        onChange?(true)
    }

    @objc private func released() {
        onChange?(false)
    }
}
#endif

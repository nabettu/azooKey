import CoreGraphics

/// 地球儀と絵文字を半分ずつ並べるキーの、左右どちらの半分か（TypeAI）
enum SplitKeyHalf: Equatable, Sendable {
    case leading
    case trailing

    /// 押し始めの位置（キーの中心からの x のずれ）から、どちらの半分を押したかを決める。
    /// 当たり判定はキーより隙間ぶん広いが、中心で分けるので外側も近い側になる
    static func at(offsetFromCenterX offset: CGFloat) -> SplitKeyHalf {
        offset < 0 ? .leading : .trailing
    }

    /// この半分を押した色にするか。どちら側か分からないときは両方に色を付ける
    func isHighlighted(isActive: Bool, pressedHalf: SplitKeyHalf?) -> Bool {
        guard isActive else {
            return false
        }
        return pressedHalf.map { $0 == self } ?? true
    }
}

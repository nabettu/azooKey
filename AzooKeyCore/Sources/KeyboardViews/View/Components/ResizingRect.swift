//
//  ResizingRect.swift
//  SwiftUI-Playground
//
//  Created by ensan on 2021/03/11.
//

import Foundation
import SwiftUI

struct OneHandedVerticalResizeResult: Equatable {
    let height: CGFloat
    let bottomOffset: CGFloat

    static func movingTopHandle(
        initialHeight: CGFloat,
        bottomOffset: CGFloat,
        translation: CGFloat,
        minimumHeight: CGFloat,
        maximumHeight: CGFloat
    ) -> Self? {
        validated(
            height: initialHeight - translation,
            bottomOffset: bottomOffset,
            minimumHeight: minimumHeight,
            maximumHeight: maximumHeight
        )
    }

    /// 「上に広げる」の上限。縮めて確定してから再編集すると maximumHeight は縮めた高さになっているので、
    /// 全幅のときの高さ（100%）と大きい方を取る
    static func expandCeiling(maximumHeight: CGFloat, fullHeight: CGFloat) -> CGFloat {
        max(maximumHeight, fullHeight)
    }

    /// 「上に広げる」ボタンが効くか。本体の高さ（height + bottomOffset）が上限に届いていれば押しても変わらないので無効にする
    static func canExpandUp(height: CGFloat, bottomOffset: CGFloat, maximumHeight: CGFloat) -> Bool {
        height + bottomOffset < maximumHeight - 0.5
    }

    /// 「上に広げる」: 下の余白はそのままに、上端を上限まで戻す
    static func expandedUp(bottomOffset: CGFloat, maximumHeight: CGFloat) -> Self {
        Self(height: maximumHeight - bottomOffset, bottomOffset: bottomOffset)
    }

    private static func validated(
        height: CGFloat,
        bottomOffset: CGFloat,
        minimumHeight: CGFloat,
        maximumHeight: CGFloat
    ) -> Self? {
        guard height >= minimumHeight,
              bottomOffset >= 0,
              height + bottomOffset <= maximumHeight else {
            return nil
        }
        return Self(height: height, bottomOffset: bottomOffset)
    }
}

/// サイズ調整の左右のハンドル。端は画面（0...containerWidth）の外へ出さず、幅は minimumWidth 以上に保つ
enum OneHandedHorizontalResize {
    static func clampedEdgeX(
        proposed: CGFloat,
        otherEdgeX: CGFloat,
        isLeftEdge: Bool,
        containerWidth: CGFloat,
        minimumWidth: CGFloat
    ) -> CGFloat {
        // 反対側の端も画面内にあるとは限らない（以前の実装で画面外に保存された位置）。先に画面内へ寄せて見る
        if isLeftEdge {
            let other = min(max(otherEdgeX, minimumWidth), containerWidth)
            return min(max(proposed, 0), other - minimumWidth)
        } else {
            let other = min(max(otherEdgeX, 0), containerWidth - minimumWidth)
            return max(min(proposed, containerWidth), other + minimumWidth)
        }
    }

    /// 画面外にはみ出した枠を、幅を保ったまま画面内へ戻す（画面より広ければ画面幅に縮める）
    static func normalizedEdges(
        left: CGFloat,
        right: CGFloat,
        containerWidth: CGFloat,
        minimumWidth: CGFloat
    ) -> (left: CGFloat, right: CGFloat) {
        let width = min(max(right - left, minimumWidth), containerWidth)
        let newLeft = min(max(left, 0), containerWidth - width)
        return (newLeft, newLeft + width)
    }

    /// 左右寄せの反転: 幅はそのままに、空いている広い方の端へ寄せる（ボタンも広い方に出している）。
    /// `positionX` は中央からのずれ（`interfacePosition.x`）
    static func positionXAlignedToWiderMargin(positionX: CGFloat, width: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let slack = max(containerWidth - width, 0) / 2
        let leftMargin = positionX + slack
        let rightMargin = slack - positionX
        return leftMargin >= rightMargin ? -slack : slack
    }
}

/// サイズ調整の枠が「全幅・100% の高さ」か
enum OneHandedResizeFrame {
    /// 全幅のときの高さ（100%）。ホストが固定している画面（Duo）ではその値、それ以外は幅由来の高さ
    @MainActor static func fullHeight(context: KeyboardLayoutContext) -> CGFloat {
        Design.fixedFullWidthInterfaceHeight ?? Design.keyboardHeight(context: context)
    }

    static func isFull(size: CGSize, positionX: CGFloat, containerWidth: CGFloat, fullHeight: CGFloat) -> Bool {
        abs(positionX) < 0.5
            && abs(size.width - containerWidth) < 0.5
            && abs(size.height - fullHeight) < 0.5
    }
}

/// サイズ調整のハンドルのタップ領域。
///
/// ハンドルは太さ 3pt の線で描いているので、線そのものを当たり判定にすると指で掴みにくい。
/// - 上のつまみ: 枠の幅いっぱいで、上辺の外側（`outset`）から厚み `minimumThickness` 以上まで掴める
///   （以前は線の長さ＋余白しか無く、狭すぎた。2026-11-25 ユーザー指摘）
/// - 左右のつまみ: 外側（`outset`）から厚み `minimumThickness` 以上まで、上のつまみの下から枠の下端まで掴める
/// 下のつまみは置いていない（キーボードの下に間を空けることは無い）
enum ResizingHandleHitArea {
    enum Edge: CaseIterable {
        case left, right, top
    }

    /// タップ領域の最小の厚み（Human Interface Guidelines の最小タップ領域）
    static let minimumThickness: CGFloat = 44
    /// 線の帯の内側に足す余白
    static let padding: CGFloat = 12
    /// 枠の外側に広げる幅。辺のすぐ外を触っても掴める
    static let outset: CGFloat = 20

    /// `size` はリサイズ枠の大きさ、`edgeRatio` はハンドルの線の長さの比率（`ResizingRect` と同じ値。いまは使っていない）
    static func rect(for edge: Edge, in size: CGSize, edgeRatio: CGFloat) -> CGRect {
        let topThickness = max(size.height / 8 + padding, minimumThickness)
        switch edge {
        case .top:
            return CGRect(
                x: -outset,
                y: -outset,
                width: size.width + outset * 2,
                height: topThickness + outset
            )
        case .left, .right:
            let thickness = max(size.width / 8 + padding, minimumThickness)
            let x = edge == .left ? -outset : size.width - thickness
            return CGRect(
                x: x,
                y: topThickness,
                width: thickness + outset,
                height: max(size.height - topThickness, 0)
            )
        }
    }
}

@MainActor
struct ResizingRect<Extension: ApplicationSpecificKeyboardViewExtension>: View {
    typealias Position = (current: CGPoint, initial: CGPoint)
    @State private var top_left_edge: Position
    @State private var bottom_right_edge: Position
    @EnvironmentObject private var variableStates: VariableStates

    private let lineWidth: CGFloat = 6
    private let edgeRatio: CGFloat = 1 / 5
    private let edgeColor: Color = .blue

    @State private var initialHeight: CGFloat

    @Binding private var size: CGSize
    @Binding private var position: CGPoint
    @Binding private var bottomOffset: CGFloat

    private let initialSize: CGSize
    private let minimumWidth: CGFloat = 120

    init(
        size: Binding<CGSize>,
        position: Binding<CGPoint>,
        bottomOffset: Binding<CGFloat>,
        initialSize: CGSize
    ) {
        self._size = size
        self._position = position
        self._bottomOffset = bottomOffset
        self._initialHeight = .init(initialValue: size.height.wrappedValue)
        let tl = CGPoint(
            x: (2 * position.x.wrappedValue - size.width.wrappedValue + initialSize.width) / 2,
            y: (-size.height.wrappedValue + initialSize.height) / 2
        )
        self._top_left_edge = .init(initialValue: (tl, tl))
        let br = CGPoint(
            x: (2 * position.x.wrappedValue + size.width.wrappedValue + initialSize.width) / 2,
            y: (size.height.wrappedValue + initialSize.height) / 2
        )
        self._bottom_right_edge = .init(initialValue: (br, br))
        self.initialSize = initialSize
    }

    func updateUserDefaults() {
        // UserDefaultsのデータを更新する
        variableStates.keyboardInternalSettingManager.update(\.oneHandedModeSetting) {value in
            value.set(
                orientation: variableStates.keyboardOrientation,
                size: size,
                position: position,
                bottomOffset: bottomOffset
            )
        }
    }

    // left < right, top < bottomとなるように修正
    func correctOrder() {
        let (left, right) = (self.top_left_edge.current.x, self.bottom_right_edge.current.x)
        (self.top_left_edge.current.x, self.bottom_right_edge.current.x) = (min(left, right), max(left, right))
        let (top, bottom) = (self.top_left_edge.current.y, self.bottom_right_edge.current.y)
        (self.top_left_edge.current.y, self.bottom_right_edge.current.y) = (min(top, bottom), max(top, bottom))
    }

    func setInitial() {
        self.initialHeight = self.size.height
        self.top_left_edge.initial = self.top_left_edge.current
        self.bottom_right_edge.initial = self.bottom_right_edge.current
    }

    func xGesture(isLeftEdge: Bool) -> some Gesture {
        DragGesture(minimumDistance: .zero, coordinateSpace: .global)
            .onChanged {value in
                let dx = value.location.x - value.startLocation.x
                // 画面の外へは引っ張れない（以前は中心が画面端に来るまで動かせ、半分はみ出せた）
                if isLeftEdge {
                    self.top_left_edge.current.x = OneHandedHorizontalResize.clampedEdgeX(
                        proposed: self.top_left_edge.initial.x + dx,
                        otherEdgeX: self.bottom_right_edge.current.x,
                        isLeftEdge: true,
                        containerWidth: initialSize.width,
                        minimumWidth: minimumWidth
                    )
                } else {
                    self.bottom_right_edge.current.x = OneHandedHorizontalResize.clampedEdgeX(
                        proposed: self.bottom_right_edge.initial.x + dx,
                        otherEdgeX: self.top_left_edge.current.x,
                        isLeftEdge: false,
                        containerWidth: initialSize.width,
                        minimumWidth: minimumWidth
                    )
                }
                self.size.width = bottom_right_edge.current.x - top_left_edge.current.x
                self.position.x = (top_left_edge.current.x + bottom_right_edge.current.x - initialSize.width) / 2
            }
            .onEnded {_ in
                self.correctOrder()
                self.setInitial()
                self.updateUserDefaults()
            }
    }

    /// 上のハンドル。キーボードの下に間を空けることは無いので、下のハンドルは置かない（2026-11-23 ユーザー指示）
    func topGesture() -> some Gesture {
        DragGesture(minimumDistance: .zero, coordinateSpace: .global)
            .onChanged { value in
                let dy = value.location.y - value.startLocation.y
                let minimumHeight = Design.keyboardHeight(
                    context: variableStates.layoutContext
                ) / 2
                guard let result = OneHandedVerticalResizeResult.movingTopHandle(
                    initialHeight: initialHeight,
                    bottomOffset: 0,
                    translation: dy,
                    minimumHeight: minimumHeight,
                    maximumHeight: variableStates.maximumHeight
                ) else {
                    return
                }
                self.top_left_edge.current.y = self.top_left_edge.initial.y + dy
                self.size.height = result.height
                self.bottomOffset = 0
                self.position.y = 0
            }
            .onEnded { _ in
                self.correctOrder()
                self.setInitial()
                self.updateUserDefaults()
            }
    }

    private func handleHitArea(_ edge: ResizingHandleHitArea.Edge) -> Path {
        Path(ResizingHandleHitArea.rect(for: edge, in: size, edgeRatio: edgeRatio))
    }

    /// 枠の角の座標を size / position から決め直す（ボタンで枠を動かしたとき）
    private func syncEdgesWithFrame() {
        let left = (2 * position.x - size.width + initialSize.width) / 2
        let right = left + size.width
        top_left_edge.current = CGPoint(x: left, y: (initialSize.height - size.height) / 2)
        bottom_right_edge.current = CGPoint(x: right, y: (initialSize.height + size.height) / 2)
        setInitial()
    }

    /// 編集を始めたときに直す: 以前の実装で画面外に保存された枠は画面内へ戻し、
    /// 下に空けた間（下のハンドルは廃止した）は無くす
    private func normalizeFrame() {
        let normalized = OneHandedHorizontalResize.normalizedEdges(
            left: top_left_edge.current.x,
            right: bottom_right_edge.current.x,
            containerWidth: initialSize.width,
            minimumWidth: minimumWidth
        )
        guard normalized.left != top_left_edge.current.x
                || normalized.right != bottom_right_edge.current.x
                || bottomOffset != 0 else {
            return
        }
        size.width = normalized.right - normalized.left
        position.x = (normalized.left + normalized.right - initialSize.width) / 2
        bottomOffset = 0
        syncEdgesWithFrame()
        updateUserDefaults()
    }

    var body: some View {
        ZStack {
            Path {path in
                for i in 0..<4 {
                    let x = size.width / 24 * CGFloat(i)
                    let ratio = (1 - CGFloat(i) / 4) * 0.8
                    path.move(to: CGPoint(x: x, y: size.height / 2 - size.height * edgeRatio * ratio))
                    path.addLine(to: CGPoint(x: x, y: size.height / 2 + size.height * edgeRatio * ratio))
                }
            }
            .stroke(Color.white, lineWidth: 3)
            .contentShape(handleHitArea(.left))
            .gesture(xGesture(isLeftEdge: true))
            Path {path in
                for i in 0..<4 {
                    let y = size.height / 24 * CGFloat(i)
                    let ratio = (1 - CGFloat(i) / 4) * 0.8
                    path.move(to: CGPoint(x: size.width / 2 - size.width * edgeRatio * ratio, y: y))
                    path.addLine(to: CGPoint(x: size.width / 2 + size.width * edgeRatio * ratio, y: y))
                }
            }
            .stroke(Color.white, lineWidth: 3)
            .contentShape(handleHitArea(.top))
            .gesture(topGesture())
            Path {path in
                for i in 0..<4 {
                    let x = size.width - size.width / 24 * CGFloat(i)
                    let ratio = (1 - CGFloat(i) / 4) * 0.8
                    path.move(to: CGPoint(x: x, y: size.height / 2 - size.height * edgeRatio * ratio))
                    path.addLine(to: CGPoint(x: x, y: size.height / 2 + size.height * edgeRatio * ratio))
                }
            }
            .stroke(Color.white, lineWidth: 3)
            .contentShape(handleHitArea(.right))
            .gesture(xGesture(isLeftEdge: false))
            HStack {
                let cur = min(size.width, size.height) * 0.22
                let max = min(initialSize.width, initialSize.height) * 0.22
                let r = min(cur, max)
                let fullHeight = OneHandedResizeFrame.fullHeight(context: variableStates.layoutContext)
                // リセット: 全幅・100% の枠に戻す。サイズ調整モードは続ける（以前はモードごと抜けていた）
                Button {
                    KeyboardFeedback<Extension>.reset()
                    withAnimation(.interactiveSpring()) {
                        variableStates.resetResizingFrame()
                    }
                    self.syncEdgesWithFrame()
                } label: {
                    Circle()
                        .fill(Color.red)
                        .frame(width: r, height: r)
                        .overlay {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.white)
                                .font(Font.system(size: r * 0.5))
                        }
                }
                Button {
                    // 全幅の高さは Duo ではホストの固定値で、initialSize.height（幅由来）とは一致しない
                    if OneHandedResizeFrame.isFull(
                        size: size,
                        positionX: position.x,
                        containerWidth: initialSize.width,
                        fullHeight: fullHeight
                    ) {
                        variableStates.setResizingMode(.fullwidth)
                    } else {
                        variableStates.setResizingMode(.onehanded)
                    }
                    variableStates.heightScaleFromKeyboardHeightSetting = 1
                    variableStates.keyboardInternalSettingManager.update(\.oneHandedModeSetting) {value in
                        value.setUserHasOverwrittenKeyboardHeightSetting(orientation: variableStates.keyboardOrientation)
                    }
                } label: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: r, height: r)
                        .overlay {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.white)
                                .font(Font.system(size: r * 0.5))
                        }
                }
                // 上に広げる: 縮めたときだけ押せる。上限（100%）より上へは広がらないので、上限にいるときは無効
                let expandCeiling = OneHandedVerticalResizeResult.expandCeiling(
                    maximumHeight: variableStates.maximumHeight,
                    fullHeight: fullHeight
                )
                let canExpandUp = OneHandedVerticalResizeResult.canExpandUp(
                    height: size.height,
                    bottomOffset: 0,
                    maximumHeight: expandCeiling
                )
                Button {
                    let result = OneHandedVerticalResizeResult.expandedUp(
                        bottomOffset: 0,
                        maximumHeight: expandCeiling
                    )
                    // 枠（= キーボードの高さ）も上限まで広げる。上ハンドルもここまで動かせるようになる
                    variableStates.maximumHeight = expandCeiling
                    withAnimation(.interactiveSpring()) {
                        self.size.height = result.height
                        self.bottomOffset = 0
                        self.position.y = 0
                    }
                    self.syncEdgesWithFrame()
                    self.updateUserDefaults()
                } label: {
                    Circle()
                        .fill(canExpandUp ? Color.blue : Color.gray)
                        .frame(width: r, height: r)
                        .overlay {
                            Image(systemName: "arrow.up.to.line.compact")
                                .foregroundStyle(.white)
                                .font(.system(size: r * 0.5))
                        }
                        .opacity(canExpandUp ? 1 : 0.5)
                }
                .disabled(!canExpandUp)
            }
        }
        .onAppear(perform: normalizeFrame)
    }
}

@MainActor
struct ResizingBindingFrame<Extension: ApplicationSpecificKeyboardViewExtension>: ViewModifier {
    private let initialSize: CGSize
    @Binding private var position: CGPoint
    @Binding private var size: CGSize
    @Binding private var bottomOffset: CGFloat
    @EnvironmentObject private var variableStates: VariableStates
    private var hideResetButtonInOneHandedMode: Bool {
        Extension.SettingProvider.hideResetButtonInOneHandedMode
    }
    init(
        size: Binding<CGSize>,
        position: Binding<CGPoint>,
        bottomOffset: Binding<CGFloat>,
        initialSize: CGSize
    ) {
        self.initialSize = initialSize
        self._size = size
        self._position = position
        self._bottomOffset = bottomOffset
    }

    private var isAtDefaultWidth: Bool {
        // 浮動小数点数の計算誤差を考慮し、0.1ポイント未満の差は「同じ」と見なします
        self.size.width.isApproximatelyEqual(to: self.initialSize.width, absoluteTolerance: 0.1)
    }

    /// 片手モードで空いた側に出すボタン。左右寄せの反転だけを置く
    /// （以前の「サイズ調整モード」「全幅に戻す」は 2026-11-23 ユーザー指示で外した）
    @ViewBuilder
    private func editButtons(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
        let UIMaxButtonDiameter: CGFloat = 48.0
        // 縦方向と横方向、両方にはみ出さない直径(r)を計算
        let fittableRFromWidth = availableWidth - 8 // 左右の端から少し余白をとる
        let fittableR = max(0, min(availableHeight / 2, fittableRFromWidth))
        let r = min(fittableR, UIMaxButtonDiameter) * 0.9

        // 計算の結果、ボタンがタップできる十分な大きさを持つ場合のみ表示する
        if r >= 16 {
            VStack {
                Spacer()
                Button {
                    withAnimation(.interactiveSpring()) {
                        variableStates.flipOneHandedAlignment()
                    }
                } label: {
                    Circle().fill(Color.blue)
                        .overlay {
                            Image(systemName: "arrow.left.arrow.right").foregroundStyle(.white).font(.system(size: r * 0.5))
                        }
                }
                .frame(width: r, height: r)
                .contentShape(Circle())
                Spacer()
            }
        }
    }

    func body(content: Content) -> some View {
        switch variableStates.resizingState {
        case .onehanded:
            // 親Viewに対して、そのサイズを教えてくれるGeometryReaderを重ねる
            VStack(spacing: 0) {
                content
                    .frame(width: size.width, height: size.height)
                Color.clear
                    .frame(height: bottomOffset)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height + bottomOffset, alignment: .top)
            .offset(x: position.x, y: 0)
            .overlay {
                    if !hideResetButtonInOneHandedMode && !isAtDefaultWidth {
                        // GeometryReaderが親のサイズ(initialSize)を正確に教えてくれる
                        GeometryReader { geo in
                            // --- 親を基準としたレイアウト計算 ---
                            let leftMargin = position.x + geo.size.width / 2 - size.width / 2
                            let rightMargin = geo.size.width / 2 - position.x - size.width / 2

                            // 左右の広い方のマージンにボタンを配置
                            if leftMargin >= rightMargin {
                                // 左側に配置
                                HStack {
                                    editButtons(availableWidth: leftMargin, availableHeight: geo.size.height)
                                    Spacer()
                                }
                            } else {
                                // 右側に配置
                                HStack {
                                    Spacer()
                                    editButtons(availableWidth: rightMargin, availableHeight: geo.size.height)
                                }
                            }
                        }
                    }
                }

        case .fullwidth:
            content
        case .resizing:
            let maximumHeight = variableStates.maximumHeight
            let height = variableStates.interfaceSize.height
            let offSet = (maximumHeight - height) / 2 - bottomOffset
            ZStack {
                content
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: size.width, height: size.height)
            }
            .disabled(true)
            .overlay {
                ResizingRect<Extension>(
                    size: $size,
                    position: $position,
                    bottomOffset: $bottomOffset,
                    initialSize: initialSize
                )
            }
            .frame(width: size.width, height: size.height)
            .offset(x: position.x, y: offSet)
        }
    }
}

extension View {
    @MainActor func resizingFrame<Extension: ApplicationSpecificKeyboardViewExtension>(
        size: Binding<CGSize>,
        position: Binding<CGPoint>,
        bottomOffset: Binding<CGFloat>,
        initialSize: CGSize,
        extension: Extension.Type
    ) -> some View {
        self.modifier(
            ResizingBindingFrame<Extension>(
                size: size,
                position: position,
                bottomOffset: bottomOffset,
                initialSize: initialSize
            )
        )
    }
}

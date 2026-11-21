import SwiftUI

struct KeyPressValue {
    var time: Date
    var startLocation: CGPoint
    var location: CGPoint
    /// 押し始めの位置の、キーの中心からの x のずれ。分割キーでどちらの半分を押したかに使う（取れない経路では nil）
    var startOffsetFromCenterX: CGFloat?

    init(_ value: DragGesture.Value, centerX: CGFloat? = nil) {
        time = value.time
        startLocation = value.startLocation
        location = value.location
        startOffsetFromCenterX = centerX.map { value.startLocation.x - $0 }
    }

    init(time: Date, startLocation: CGPoint, location: CGPoint, startOffsetFromCenterX: CGFloat? = nil) {
        self.time = time
        self.startLocation = startLocation
        self.location = location
        self.startOffsetFromCenterX = startOffsetFromCenterX
    }
}

@MainActor
struct KeyPressHandlers {
    var onChanged: (KeyPressValue) -> Void
    var onEnded: () -> Void
}

@MainActor
struct KeyPressGestureModifier: ViewModifier {
    var hitSize: CGSize
    /// キー本体の幅（当たり判定は隙間ぶん広い）。押し始めの位置をキーの中心からのずれにするのに使う
    var keyWidth: CGFloat
    var flick: KeyPressHandlers
    var linear: KeyPressHandlers
    var onCancelled: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.0, *) {
            content.overlay {
                ImmediateKeyGesture(
                    onChanged: { value in
                        flick.onChanged(value)
                        linear.onChanged(value)
                    },
                    onEnded: {
                        flick.onEnded()
                        linear.onEnded()
                    },
                    onCancelled: onCancelled
                )
                .frame(width: hitSize.width, height: hitSize.height)
            }
        } else {
            legacyGesture(content: content)
        }
        #else
        legacyGesture(content: content)
        #endif
    }

    private func legacyGesture(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: .zero, coordinateSpace: .global)
                .onChanged { flick.onChanged(KeyPressValue($0)) }
                .onEnded { _ in flick.onEnded() }
                .simultaneously(with:
                    DragGesture(minimumDistance: .zero)
                        .onChanged { linear.onChanged(KeyPressValue($0, centerX: keyWidth / 2)) }
                        .onEnded { _ in linear.onEnded() }
                )
        )
    }
}

#if os(iOS)
import UIKit

// iOS 27 can defer zero-distance DragGesture updates near system gestures.
// Give each key a concrete UIKit hit-test surface, including its share of the
// spacing between keys. A recognizer bridged onto the SwiftUI hosting view can
// miss touches near the candidate bar before touchesBegan is ever called.
// Deliver the lifecycle directly from UIKit to preserve immediate touch-down.
@available(iOS 18.0, *)
struct ImmediateKeyGesture: UIViewRepresentable {
    var onChanged: (KeyPressValue) -> Void
    var onEnded: () -> Void
    var onCancelled: () -> Void

    func makeUIView(context: Context) -> TouchSurface {
        let view = TouchSurface()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: TouchSurface, context: Context) {
        view.recognizer.onChanged = onChanged
        view.recognizer.onEnded = onEnded
        view.recognizer.onCancelled = onCancelled
    }

    static func dismantleUIView(_ view: TouchSurface, coordinator: ()) {
        view.recognizer.cancel()
        view.recognizer.isEnabled = false
    }

    final class TouchSurface: UIView {
        let recognizer = Recognizer()

        init() {
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
            isMultipleTouchEnabled = true
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            addGestureRecognizer(recognizer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class Recognizer: UIGestureRecognizer {
        var onChanged: ((KeyPressValue) -> Void)?
        var onEnded: (() -> Void)?
        var onCancelled: (() -> Void)?
        private var trackedTouch: UITouch?
        private var startLocation: CGPoint = .zero
        private var startOffsetFromCenterX: CGFloat?

        // Observe the key's touch without preventing other recognizers.
        override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
        override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            guard trackedTouch == nil, let touch = touches.first else {
                return
            }
            trackedTouch = touch
            startLocation = touch.location(in: nil)
            // 当たり判定の面はキーと中心が同じなので、面の中心からのずれ = キーの中心からのずれ
            startOffsetFromCenterX = view.map { touch.location(in: $0).x - $0.bounds.midX }
            onChanged?(KeyPressValue(time: Date(), startLocation: startLocation, location: startLocation, startOffsetFromCenterX: startOffsetFromCenterX))
            state = .began
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch = trackedTouch, touches.contains(touch) else {
                return
            }
            onChanged?(KeyPressValue(time: Date(), startLocation: startLocation, location: touch.location(in: nil), startOffsetFromCenterX: startOffsetFromCenterX))
            state = .changed
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch = trackedTouch, touches.contains(touch) else {
                return
            }
            trackedTouch = nil
            onEnded?()
            state = .ended
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
            guard let touch = trackedTouch, touches.contains(touch) else {
                return
            }
            cancel()
            state = .cancelled
        }

        override func reset() {
            cancel()
            super.reset()
        }

        fileprivate func cancel() {
            guard trackedTouch != nil else {
                return
            }
            trackedTouch = nil
            onCancelled?()
        }
    }
}

#endif

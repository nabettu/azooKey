//
//  ChangeKeyboardButtonView.swift
//  Keyboard
//
//  Created by ensan on 2021/02/06.
//  Copyright © 2021 ensan. All rights reserved.
//

import Foundation
import SwiftUI

public struct ChangeKeyboardButtonView<Extension: ApplicationSpecificKeyboardViewExtension>: UIViewRepresentable {
    private let selector: Selector?
    private let size: CGFloat
    @Environment(Extension.Theme.self) private var theme

    public init(selector: Selector? = nil, size: CGFloat) {
        self.selector = selector
        self.size = size
    }

    private var weight: UIImage.SymbolWeight {
        switch theme.textFont {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case  .light, .regular:
            return .light
        case .medium:
            return .medium
        case .semibold, .bold:
            return .semibold
        case .heavy:
            return .heavy
        case .black:
            return .black
        }
    }

    public func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        if let selector {
            button.addTarget(nil, action: selector, for: .allTouchEvents)
        }
        let largeConfig = UIImage.SymbolConfiguration(pointSize: size, weight: weight, scale: .default)
        let largeBoldDoc = UIImage(systemName: "globe", withConfiguration: largeConfig)
        button.setImage(largeBoldDoc, for: .normal)
        button.setTitleColor(UIColor(theme.textColor.color), for: [.normal, .highlighted])
        button.tintColor = UIColor(theme.textColor.color)
        return button
    }

    public func updateUIView(_ uiView: UIButton, context: Context) {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: size, weight: weight, scale: .default)
        let largeBoldDoc = UIImage(systemName: "globe", withConfiguration: largeConfig)
        uiView.setImage(largeBoldDoc, for: .normal)
        uiView.setTitleColor(UIColor(theme.textColor.color), for: [.normal, .highlighted])
        uiView.tintColor = UIColor(theme.textColor.color)
    }
}

/// 地球儀と並べる絵文字ボタン。地球儀（UIKit のボタン）と同じくタッチを自分で受けるために UIKit で作る
struct EmojiTabButtonView<Extension: ApplicationSpecificKeyboardViewExtension>: UIViewRepresentable {
    let size: CGFloat
    let onTap: () -> Void
    @Environment(Extension.Theme.self) private var theme

    final class Coordinator: NSObject {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) {
            self.onTap = onTap
        }
        @objc func tapped() {
            onTap()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    /// 地球儀（`ChangeKeyboardButtonView.weight`）と同じ太さにする
    private var weight: UIImage.SymbolWeight {
        switch theme.textFont {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light, .regular: .light
        case .medium: .medium
        case .semibold, .bold: .semibold
        case .heavy: .heavy
        case .black: .black
        }
    }

    private var image: UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: weight, scale: .default)
        return UIImage(systemName: "face.smiling", withConfiguration: config)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        button.accessibilityLabel = "Emoji"
        updateUIView(button, context: context)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        context.coordinator.onTap = onTap
        uiView.setImage(image, for: .normal)
        uiView.tintColor = UIColor(theme.textColor.color)
    }
}

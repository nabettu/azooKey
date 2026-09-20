//
//  StrokeAndFill.swift
//  azooKey
//
//  Created by ensan on 2021/02/26.
//  Copyright © 2021 ensan. All rights reserved.
//

import Foundation
import SwiftUI

public extension Shape {
    // このパッケージの deployment target は iOS 17（Package.swift の platforms）なので、
    // かつてあった `if #available(iOS 17, *)` の else 側（ZStack で fill と stroke を
    // 重ねる旧実装）は到達しない。iOS 27.1 SDK ではその else が
    // 「TupleContent の View 適合は iOS 26 以降」でコンパイルエラーになるため削除した。
    func strokeAndFill(fillContent: some ShapeStyle, strokeContent: some ShapeStyle, lineWidth: CGFloat) -> some View {
        self
            .fill(fillContent)
            .stroke(strokeContent, lineWidth: lineWidth)
    }
}

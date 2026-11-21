import Combine
import CustardKit
import Foundation
@testable import KeyboardViews
import XCTest

/// TypeAI: ホストが高さを固定する画面（iPhone Duo）では、全幅に戻すとき（タブ切替・回転）から固定値で描く。
/// 幅由来の高さを一度出してからホストが書き戻すと、その 1 コマがちらつきに見えた（2026-11-21 実機）
@MainActor
final class FixedFullWidthInterfaceHeightTests: XCTestCase {
    private struct ClipboardConfig: ClipboardHistoryManagerConfiguration {
        var enabled: Bool { false }
        var saveDirectory: URL? { nil }
        var maxCount: Int { 0 }
    }

    private struct EmptyCustardManager: CustardManagerProtocol {
        struct NotFound: Error {}
        func custard(identifier: String) throws -> Custard { throw NotFound() }
        func tabbar(identifier: Int) throws -> TabBarData { throw NotFound() }
    }

    private struct TabConfig: TabManagerConfiguration {
        var japaneseLayout: LanguageLayout { .flick }
        var englishLayout: LanguageLayout { .flick }
        var custardManager: any CustardManagerProtocol { EmptyCustardManager() }
    }

    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "FixedFullWidthInterfaceHeightTests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        Design.fixedFullWidthInterfaceHeight = nil
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeStates() throws -> VariableStates {
        VariableStates(
            interfaceWidth: 801,
            orientation: .horizontal,
            clipboardHistoryManagerConfig: ClipboardConfig(),
            tabManagerConfig: TabConfig(),
            userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)),
            layoutIdiom: .phone
        )
    }

    /// publish された高さの列。最終値だけを見ると「幅由来の高さ → 固定値」と 2 回出す実装でも通ってしまう
    private func publishedHeights(of states: VariableStates, during action: () -> Void) -> [CGFloat] {
        var heights: [CGFloat] = []
        let cancellable = states.$interfaceSize.dropFirst().sink { heights.append($0.height) }
        action()
        cancellable.cancel()
        return heights
    }

    func test_fullwidthPublishesOnlyFixedHeight() throws {
        let states = try makeStates()
        Design.fixedFullWidthInterfaceHeight = 281
        let heights = publishedHeights(of: states) { states.setResizingMode(.fullwidth) }
        XCTAssertFalse(heights.isEmpty)
        XCTAssertEqual(heights, Array(repeating: 281, count: heights.count), "固定値以外の高さを一度でも出すとちらつく")
        XCTAssertEqual(states.maximumHeight, 281, accuracy: 0.001)
    }

    func test_containerWidthUpdatePublishesOnlyFixedHeight() throws {
        let states = try makeStates()
        Design.fixedFullWidthInterfaceHeight = 281
        let heights = publishedHeights(of: states) { states.setContainerWidth(801, orientation: .horizontal) }
        XCTAssertFalse(heights.isEmpty)
        XCTAssertEqual(heights, Array(repeating: 281, count: heights.count))
    }

    /// nil なら従来どおり保存値（無ければ幅由来の高さ）× 高さの設定の倍率
    func test_nilKeepsAzooKeyHeight() throws {
        let states = try makeStates()
        Design.fixedFullWidthInterfaceHeight = nil
        states.setResizingMode(.fullwidth)
        let stored = states.keyboardInternalSettingManager.oneHandedModeSetting
            .heightItem(orientation: .horizontal).height
        let expected = (stored ?? Design.keyboardHeight(context: states.layoutContext))
            * states.heightScaleFromKeyboardHeightSetting
        XCTAssertEqual(states.interfaceSize.height, expected, accuracy: 0.001)
    }
}

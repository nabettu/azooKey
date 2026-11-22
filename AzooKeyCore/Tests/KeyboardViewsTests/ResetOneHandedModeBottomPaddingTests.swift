import CustardKit
import Foundation
@testable import KeyboardViews
import XCTest

/// キーボード下の余白（`Design.keyboardScreenBottomPadding`）は表示側（`KeyboardView`）が
/// 本体の高さ（`interfaceSize`）の外に足す。リセットで保存する高さに含めると二重に乗る。
@MainActor
final class ResetOneHandedModeBottomPaddingTests: XCTestCase {
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
    private var savedPadding: CGFloat = 0

    override func setUp() async throws {
        suiteName = "ResetOneHandedModeBottomPaddingTests-\(UUID().uuidString)"
        savedPadding = Design.keyboardScreenBottomPadding
    }

    override func tearDown() async throws {
        Design.keyboardScreenBottomPadding = savedPadding
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeStates() throws -> VariableStates {
        VariableStates(
            interfaceWidth: 390,
            orientation: .vertical,
            clipboardHistoryManagerConfig: ClipboardConfig(),
            tabManagerConfig: TabConfig(),
            userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)),
            layoutIdiom: .phone
        )
    }

    func test_resetStoresKeyboardHeightWithoutBottomPadding() throws {
        Design.keyboardScreenBottomPadding = 18
        let states = try makeStates()

        states.resetOneHandedModeSetting()

        let stored = states.keyboardInternalSettingManager.oneHandedModeSetting
            .heightItem(orientation: .vertical).height
        XCTAssertEqual(
            try XCTUnwrap(stored),
            Design.keyboardHeight(context: states.layoutContext),
            accuracy: 0.001
        )
    }

    /// リセットは画面への反映をメインキューに積む（updateResizingState）。それを待ってから見る
    func test_interfaceHeightAfterResetIsDefaultKeyboardHeight() throws {
        Design.keyboardScreenBottomPadding = 18
        let states = try makeStates()

        states.resetOneHandedModeSetting()
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)

        XCTAssertEqual(
            states.interfaceSize.height,
            Design.keyboardHeight(context: states.layoutContext),
            accuracy: 0.001
        )
    }
}

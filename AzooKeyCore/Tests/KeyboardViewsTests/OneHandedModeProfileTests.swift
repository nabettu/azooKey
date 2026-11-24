import CustardKit
import Foundation
@testable import KeyboardViews
import XCTest

/// サイズ調整の保存値を「画面ごと」（iPhone Duo の閉じた画面 / 開いた画面）に分けて持つ。
/// 向き（縦 / 横）は `OneHandedModeSetting` の中で分かれているので、画面 × 向きで別々になる（2026-11-25 ユーザー指示）
@MainActor
final class OneHandedModeProfileTests: XCTestCase {
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
    private var savedFixedHeight: CGFloat?

    override func setUp() async throws {
        suiteName = "OneHandedModeProfileTests-\(UUID().uuidString)"
        savedFixedHeight = Design.fixedFullWidthInterfaceHeight
        Design.fixedFullWidthInterfaceHeight = nil
    }

    override func tearDown() async throws {
        Design.fixedFullWidthInterfaceHeight = savedFixedHeight
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func userDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    /// キーボード拡張のプロセスが作り直されたときと同じく、保存値から VariableStates を作り直す
    private func makeStates() throws -> VariableStates {
        VariableStates(
            clipboardHistoryManagerConfig: ClipboardConfig(),
            tabManagerConfig: TabConfig(),
            userDefaults: try userDefaults(),
            layoutIdiom: .phone
        )
    }

    /// ホストが表示のたびにやる順番（画面を知らせる → 幅と向きを渡す）
    private func show(_ states: VariableStates, profile: String, width: CGFloat, orientation: KeyboardOrientation) {
        states.setOneHandedModeProfile(profile)
        states.setContainerWidth(width, orientation: orientation)
    }

    /// サイズ調整で縮めて確定したのと同じ状態にする（ResizingRect の updateUserDefaults → 確定ボタン）
    private func resize(_ states: VariableStates, to size: CGSize, positionX: CGFloat) {
        states.setResizingMode(.resizing)
        states.interfaceSize = size
        states.interfacePosition = CGPoint(x: positionX, y: 0)
        states.keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: states.keyboardOrientation, size: size, position: CGPoint(x: positionX, y: 0), bottomOffset: 0)
            value.setUserHasOverwrittenKeyboardHeightSetting(orientation: states.keyboardOrientation)
        }
        states.setResizingMode(.onehanded)
    }

    func test_resizedFrameIsRestoredAfterProcessRestartInPortrait() throws {
        let first = try makeStates()
        show(first, profile: "402x874", width: 402, orientation: .vertical)
        resize(first, to: CGSize(width: 300, height: 180), positionX: 51)

        // 時間をおいて開いた = プロセスが作り直された
        let second = try makeStates()
        show(second, profile: "402x874", width: 402, orientation: .vertical)

        XCTAssertEqual(second.resizingState, .onehanded)
        XCTAssertEqual(second.interfaceSize.width, 300, accuracy: 0.001)
        XCTAssertEqual(second.interfaceSize.height, 180, accuracy: 0.001)
        XCTAssertEqual(second.interfacePosition.x, 51, accuracy: 0.001)
    }

    func test_heightOnlyResizeAtFullWidthIsRestored() throws {
        let first = try makeStates()
        show(first, profile: "402x874", width: 402, orientation: .vertical)
        first.keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: .vertical, size: CGSize(width: 402, height: 170), position: .zero, bottomOffset: 0)
        }
        first.setResizingMode(.fullwidth)

        let second = try makeStates()
        show(second, profile: "402x874", width: 402, orientation: .vertical)

        XCTAssertEqual(second.resizingState, .fullwidth)
        XCTAssertEqual(second.interfaceSize.height, 170, accuracy: 0.001)
    }

    func test_eachScreenKeepsItsOwnFrame() throws {
        let states = try makeStates()
        // 閉じた画面（カバー）で縮める
        show(states, profile: "cover", width: 466, orientation: .vertical)
        resize(states, to: CGSize(width: 380, height: 200), positionX: 43)
        // 開いた画面に移ると、カバーの枠は持ち込まない（まだ調整していないので全幅）
        show(states, profile: "inner", width: 801, orientation: .horizontal)
        XCTAssertEqual(states.resizingState, .fullwidth)
        XCTAssertEqual(states.interfaceSize.width, 801, accuracy: 0.001)
        // 開いた画面で別の枠にする
        resize(states, to: CGSize(width: 600, height: 220), positionX: -100)

        // 閉じるとカバーの枠に戻る
        show(states, profile: "cover", width: 466, orientation: .vertical)
        XCTAssertEqual(states.resizingState, .onehanded)
        XCTAssertEqual(states.interfaceSize.width, 380, accuracy: 0.001)
        XCTAssertEqual(states.interfaceSize.height, 200, accuracy: 0.001)

        // プロセスを作り直して開いた画面で出しても、開いた画面の枠
        let restarted = try makeStates()
        show(restarted, profile: "inner", width: 801, orientation: .horizontal)
        XCTAssertEqual(restarted.resizingState, .onehanded)
        XCTAssertEqual(restarted.interfaceSize.width, 600, accuracy: 0.001)
        XCTAssertEqual(restarted.interfaceSize.height, 220, accuracy: 0.001)
        XCTAssertEqual(restarted.interfacePosition.x, -100, accuracy: 0.001)
    }

    func test_portraitAndLandscapeOfTheSameScreenAreSeparate() throws {
        let states = try makeStates()
        show(states, profile: "inner", width: 801, orientation: .horizontal)
        resize(states, to: CGSize(width: 600, height: 220), positionX: 0)
        show(states, profile: "inner", width: 700, orientation: .vertical)
        XCTAssertEqual(states.resizingState, .fullwidth)
        show(states, profile: "inner", width: 801, orientation: .horizontal)
        XCTAssertEqual(states.resizingState, .onehanded)
        XCTAssertEqual(states.interfaceSize.width, 600, accuracy: 0.001)
    }

    /// 以前の版で保存した値（画面を記録していない）は引き継がない。どの画面の値か分からず、
    /// Duo の開いた画面の既定の片手モード（縦）を閉じた画面に持ち込みうる
    func test_legacySettingIsNotCarriedIntoTheFirstProfile() throws {
        let legacy = try makeStates()
        legacy.setContainerWidth(669, orientation: .vertical)
        resize(legacy, to: CGSize(width: 535, height: 277), positionX: 67)

        let upgraded = try makeStates()
        show(upgraded, profile: "466x678", width: 466, orientation: .vertical)
        XCTAssertEqual(upgraded.resizingState, .fullwidth)
        XCTAssertEqual(upgraded.interfaceSize.width, 466, accuracy: 0.001)
    }
}

import Combine
import CustardKit
import Foundation
@testable import KeyboardViews
import XCTest

/// TypeAI: サイズ調整モードの開始・途中のレイアウト・左右寄せの反転・リセット（2026-11-23 ユーザー指摘）
@MainActor
final class ResizingSessionTests: XCTestCase {
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
        suiteName = "ResizingSessionTests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
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

    // MARK: - 調整中のレイアウトで枠を作り直さない

    /// ホストはいま表示している高さから枠を始める（Duo で固定値 209・保存値 261）。調整中にレイアウトが走って
    /// 保存値の高さで上書きされると、枠が上にめり込んだり（保存値の方が高い）上が減ったり（低い）した
    func test_layoutPassDuringResizingKeepsTheFrame() throws {
        let states = try makeStates()
        states.setContainerWidth(801, orientation: .horizontal)
        states.setResizingMode(.resizing)
        states.interfaceSize.height = 209
        states.maximumHeight = 209

        states.setContainerWidth(801, orientation: .horizontal)

        XCTAssertEqual(states.interfaceSize.height, 209)
        XCTAssertEqual(states.maximumHeight, 209)
        XCTAssertEqual(states.interfaceBottomOffset, 0)
    }

    // MARK: - キーボードの下に間を空けない

    func test_resizingIgnoresSavedBottomOffset() throws {
        let states = try makeStates()
        states.setContainerWidth(801, orientation: .horizontal)
        states.keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: .horizontal, size: CGSize(width: 500, height: 200), position: .zero, bottomOffset: 40)
        }

        states.setResizingMode(.resizing)
        XCTAssertEqual(states.interfaceBottomOffset, 0)

        states.setResizingMode(.onehanded)
        states.setContainerWidth(801, orientation: .horizontal)
        XCTAssertEqual(states.interfaceBottomOffset, 0)
    }

    // MARK: - 左右寄せの反転

    func test_flipMovesKeyboardToTheWiderMargin() {
        // 右寄せ（左が空いている）→ 左寄せ
        XCTAssertEqual(OneHandedHorizontalResize.positionXAlignedToWiderMargin(positionX: 300, width: 400, containerWidth: 1000), -300)
        // 左寄せ → 右寄せ
        XCTAssertEqual(OneHandedHorizontalResize.positionXAlignedToWiderMargin(positionX: -300, width: 400, containerWidth: 1000), 300)
        // 少しだけ右に寄っている → 左端へ
        XCTAssertEqual(OneHandedHorizontalResize.positionXAlignedToWiderMargin(positionX: 50, width: 400, containerWidth: 1000), -300)
    }

    /// 反転で保存するのは位置だけ。高さまで保存すると、高さの倍率を使うホストで次の表示に倍率が二重にかかる
    func test_flipSavesOnlyPosition() throws {
        let states = try makeStates()
        states.setContainerWidth(801, orientation: .horizontal)
        states.keyboardInternalSettingManager.update(\.oneHandedModeSetting) { value in
            value.set(orientation: .horizontal, size: CGSize(width: 401, height: 200), position: CGPoint(x: 200, y: 0), bottomOffset: 0)
        }
        states.heightScaleFromKeyboardHeightSetting = 1.2
        states.interfaceSize = CGSize(width: 401, height: 240)
        states.interfacePosition = CGPoint(x: 200, y: 0)

        states.flipOneHandedAlignment()

        XCTAssertEqual(states.interfacePosition.x, -200)
        let setting = states.keyboardInternalSettingManager.oneHandedModeSetting
        XCTAssertEqual(setting.item(orientation: .horizontal).position.x, -200)
        XCTAssertEqual(setting.item(orientation: .horizontal).width, 401)
        XCTAssertEqual(setting.heightItem(orientation: .horizontal).height, 200)
    }

    // MARK: - ホストが決める片手モードの既定

    /// 縦に長く横に広い画面（Duo の内側の縦持ち・iPad mini の縦）で、ホストが幅・高さ・寄せを決めて片手モードで始める。
    /// 保存もするので、次のレイアウト（setContainerWidth）や向きの往復でも同じ枠に戻る
    func test_startOneHandedModeKeepsFrameAcrossLayout() throws {
        let states = try makeStates()
        states.setContainerWidth(669, orientation: .vertical)

        states.startOneHandedMode(width: 535, height: 277, positionX: 67)

        XCTAssertEqual(states.resizingState, .onehanded)
        XCTAssertEqual(states.interfaceSize, CGSize(width: 535, height: 277))
        XCTAssertEqual(states.interfacePosition.x, 67)
        XCTAssertEqual(states.maximumHeight, 277)

        states.setContainerWidth(669, orientation: .vertical)
        XCTAssertEqual(states.resizingState, .onehanded)
        XCTAssertEqual(states.interfaceSize, CGSize(width: 535, height: 277))
        XCTAssertEqual(states.interfacePosition.x, 67)

        // 横にして戻しても片手モードのまま同じ枠
        states.setContainerWidth(951, orientation: .horizontal)
        states.setContainerWidth(669, orientation: .vertical)
        XCTAssertEqual(states.resizingState, .onehanded)
        XCTAssertEqual(states.interfaceSize, CGSize(width: 535, height: 277))
        XCTAssertEqual(states.interfacePosition.x, 67)
    }

    /// 画面より広い幅を渡されても画面に収め、位置も空きの範囲に収める
    func test_startOneHandedModeClampsToContainer() throws {
        let states = try makeStates()
        states.setContainerWidth(669, orientation: .vertical)

        states.startOneHandedMode(width: 900, height: 277, positionX: 300)

        XCTAssertEqual(states.interfaceSize.width, 669)
        XCTAssertEqual(states.interfacePosition.x, 0)
    }

    // MARK: - リセット

    /// リセットしてもサイズ調整モードは続き、枠は全幅・100%（Duo ではホストの固定値）に戻る
    func test_resetKeepsResizingModeAndUsesFixedFullHeight() throws {
        Design.fixedFullWidthInterfaceHeight = 209
        defer { Design.fixedFullWidthInterfaceHeight = nil }
        let states = try makeStates()
        states.setContainerWidth(801, orientation: .horizontal)
        states.setResizingMode(.resizing)
        states.interfaceSize = CGSize(width: 400, height: 150)
        states.interfacePosition = CGPoint(x: 100, y: 0)
        states.maximumHeight = 150

        states.resetResizingFrame()

        XCTAssertEqual(states.resizingState, .resizing)
        XCTAssertEqual(states.interfaceSize, CGSize(width: 801, height: 209))
        XCTAssertEqual(states.interfacePosition, .zero)
        XCTAssertEqual(states.maximumHeight, 209)
        let setting = states.keyboardInternalSettingManager.oneHandedModeSetting
        XCTAssertTrue(setting.heightItem(orientation: .horizontal).userHasOverwrittenKeyboardHeightSetting)
        XCTAssertEqual(setting.heightItem(orientation: .horizontal).height, 209)
        // リセット直後に確定すると全幅に戻る
        XCTAssertTrue(OneHandedResizeFrame.isFull(
            size: states.interfaceSize,
            positionX: states.interfacePosition.x,
            containerWidth: states.containerWidth,
            fullHeight: OneHandedResizeFrame.fullHeight(context: states.layoutContext)
        ))
    }

    // MARK: - 調整中に画面幅が変わったとき

    func test_widthChangeDuringResizingKeepsFrameOnScreen() throws {
        let states = try makeStates()
        states.setContainerWidth(801, orientation: .horizontal)
        states.setResizingMode(.resizing)
        states.interfaceSize = CGSize(width: 500, height: 209)
        states.interfacePosition = CGPoint(x: 150, y: 0)

        states.setContainerWidth(600, orientation: .horizontal)

        XCTAssertEqual(states.interfaceSize, CGSize(width: 500, height: 209))
        XCTAssertEqual(states.interfacePosition.x, 50)
    }

    /// iPad のフローティング表示（幅 400 未満）へ移ったら、従来どおり保存値を使わず作り直す
    func test_padFloatingDuringResizingResetsPosition() throws {
        let states = VariableStates(
            interfaceWidth: 801,
            orientation: .vertical,
            clipboardHistoryManagerConfig: ClipboardConfig(),
            tabManagerConfig: TabConfig(),
            userDefaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)),
            layoutIdiom: .pad
        )
        states.setContainerWidth(801, orientation: .vertical)
        states.setResizingMode(.resizing)
        states.interfaceSize = CGSize(width: 500, height: 400)
        states.interfacePosition = CGPoint(x: 150, y: 0)

        states.setContainerWidth(320, orientation: .vertical)

        XCTAssertEqual(states.interfacePosition, .zero)
        XCTAssertEqual(states.interfaceSize.width, 320)
        XCTAssertEqual(states.interfaceSize.height, Design.keyboardHeight(context: states.layoutContext))
    }

    // MARK: - 確定したときに全幅へ戻すか

    /// 全幅の高さはホストの固定値（Duo）のことがあり、`initialSize.height`（幅由来）と一致しない。
    /// リセット直後に確定しても全幅に戻ること
    func test_isFullFrameUsesFullHeightNotWidthDerivedHeight() {
        XCTAssertTrue(OneHandedResizeFrame.isFull(
            size: CGSize(width: 801, height: 209), positionX: 0, containerWidth: 801, fullHeight: 209))
        XCTAssertTrue(OneHandedResizeFrame.isFull(
            size: CGSize(width: 800.95, height: 209.04), positionX: 0.01, containerWidth: 801, fullHeight: 209))
        XCTAssertFalse(OneHandedResizeFrame.isFull(
            size: CGSize(width: 500, height: 209), positionX: 0, containerWidth: 801, fullHeight: 209))
        XCTAssertFalse(OneHandedResizeFrame.isFull(
            size: CGSize(width: 801, height: 180), positionX: 0, containerWidth: 801, fullHeight: 209))
    }
}

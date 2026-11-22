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

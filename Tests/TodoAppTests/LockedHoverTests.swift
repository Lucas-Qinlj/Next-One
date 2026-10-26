import AppKit
import XCTest
import TodoCore
@testable import TodoApp

final class LockedHoverTests: XCTestCase {
    @MainActor func testHoverLifecyclePreservesPreferencesAndInputPolicy() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(store: try Store(directory: directory))
        let controller = FloatingController(model: model)
        defer {
            controller.timer?.invalidate(); controller.lockHoverTimer?.invalidate()
            controller.ball.close(); controller.panel.close()
            NSStatusBar.system.removeStatusItem(controller.statusItem)
            model.window = nil
        }
        let inside = CGPoint(x: controller.panel.frame.midX, y: controller.panel.frame.midY)
        let outside = CGPoint(x: controller.panel.frame.maxX + 100, y: controller.panel.frame.maxY + 100)
        controller.updateLockHover(at: inside)
        XCTAssertFalse(model.lockHover)
        XCTAssertNil(controller.lockHoverTimer)
        model.opacity = 0.3
        controller.setLocked(true)
        let timer = controller.lockHoverTimer
        controller.applySettings()
        XCTAssertTrue(timer === controller.lockHoverTimer)
        controller.updateLockHover(at: inside)
        XCTAssertTrue(model.lockHover)
        XCTAssertEqual(controller.panel.alphaValue, 0.5)
        XCTAssertFalse(controller.panel.hasShadow)
        XCTAssertTrue(controller.panel.ignoresMouseEvents)
        XCTAssertFalse(controller.panel.canBecomeKey)
        XCTAssertEqual(controller.ball.alphaValue, 1)
        XCTAssertFalse(controller.ball.ignoresMouseEvents)
        XCTAssertEqual(model.opacity, 0.3)
        controller.savePreferences()
        let preferences = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: controller.preferencesURL)) as? [String: Any])
        XCTAssertEqual(preferences["opacity"] as? Double, 0.3)
        XCTAssertNil(preferences["lockHover"])
        controller.updateLockHover(at: outside)
        XCTAssertFalse(model.lockHover)
        XCTAssertEqual(controller.panel.alphaValue, 1)
        XCTAssertTrue(controller.panel.hasShadow)
        model.opacity = 0
        controller.updateLockHover(at: inside)
        controller.toggle()
        XCTAssertFalse(model.lockHover)
        XCTAssertNil(controller.lockHoverTimer)
        controller.toggle()
        controller.updateLockHover(at: inside)
        XCTAssertTrue(model.lockHover)
        controller.setLocked(false)
        XCTAssertFalse(model.lockHover)
        XCTAssertEqual(model.opacity, 0)
        XCTAssertEqual(controller.panel.alphaValue, 1)
        XCTAssertNil(controller.lockHoverTimer)
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        controller.setLocked(true)
        controller.updateLockHover(at: inside)
        model.pinned = false
        controller.applySettings()
        XCTAssertFalse(model.locked)
        XCTAssertFalse(model.lockHover)
        XCTAssertNil(controller.lockHoverTimer)
    }
    @MainActor func testTimerReadsActualPointerAfterPanelMoves() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(store: try Store(directory: directory))
        let controller = FloatingController(model: model)
        defer {
            controller.timer?.invalidate(); controller.lockHoverTimer?.invalidate()
            controller.ball.close(); controller.panel.close()
            NSStatusBar.system.removeStatusItem(controller.statusItem)
            model.window = nil
        }
        controller.setLocked(true)
        let pointer = NSEvent.mouseLocation
        controller.panel.setFrameOrigin(CGPoint(x: pointer.x - 100, y: pointer.y - 100))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(model.lockHover)
        XCTAssertEqual(controller.panel.alphaValue, 0.5)
        XCTAssertTrue(controller.panel.ignoresMouseEvents)
        controller.panel.setFrameOrigin(CGPoint(x: pointer.x + 100, y: pointer.y + 100))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(model.lockHover)
        XCTAssertEqual(controller.panel.alphaValue, 1)
    }

}

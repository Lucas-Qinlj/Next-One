import AppKit
import XCTest
import TodoCore
@testable import TodoApp

final class HeaderDragTests: XCTestCase {
    @MainActor func testHeaderDragMovesBothWindowsWithoutToggling() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = FloatingController(model: AppModel(store: try Store(directory: directory)))
        defer {
            controller.timer?.invalidate()
            controller.ball.close(); controller.panel.close()
            NSStatusBar.system.removeStatusItem(controller.statusItem)
        }
        let view = HeaderDragView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))
        view.controller = controller
        controller.panel.contentView = view
        func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0,
                              windowNumber: controller.panel.windowNumber, context: nil,
                              eventNumber: 0, clickCount: 1, pressure: 1)!
        }
        let origin = controller.geometry.anchor
        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
        view.mouseDown(with: event(.leftMouseDown, NSPoint(x: 30, y: 20)))
        view.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 32, y: 20)))
        XCTAssertEqual(controller.geometry.anchor, origin)
        view.mouseUp(with: event(.leftMouseUp, NSPoint(x: 32, y: 20)))
        XCTAssertTrue(controller.expanded)
        view.mouseDown(with: event(.leftMouseDown, NSPoint(x: 30, y: 20)))
        view.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: 10, y: 10)))
        XCTAssertEqual(controller.geometry.anchor, CGPoint(x: origin.x - 20, y: origin.y - 10))
        XCTAssertEqual(controller.ball.frame.midX, controller.geometry.anchor.x)
        XCTAssertEqual(controller.ball.frame.midY, controller.geometry.anchor.y)
        XCTAssertEqual(controller.panel.frame, controller.geometry.frame)
        // The window moved under the pointer; mouseUp is now at the original local point.
        view.mouseUp(with: event(.leftMouseUp, NSPoint(x: 30, y: 20)))
        XCTAssertTrue(controller.expanded)
        XCTAssertNil(controller.mouseOrigin)
        XCTAssertNil(controller.dragOrigin)
        XCTAssertTrue(FileManager.default.fileExists(atPath: controller.preferencesURL.path))
    }
}

import AppKit
import XCTest
import TodoCore
@testable import TodoApp

final class ScrollbarLayoutTests: XCTestCase {
    @MainActor func testEveryPageReclaimsLegacyScrollbarGutter() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        let model = AppModel(store: store)
        for index in 0..<20 {
            _ = try store.execute("add", ["title": "Layout task \(index)", "project": "unclassified",
                                          "description": String(repeating: "Long notes\n", count: 30)])
        }
        model.refresh()
        let controller = FloatingController(model: model)
        defer {
            controller.timer?.invalidate(); controller.lockHoverTimer?.invalidate()
            controller.panel.close(); controller.ball.close()
            NSStatusBar.system.removeStatusItem(controller.statusItem)
            model.window = nil
        }
        func scrolls(_ view: NSView) -> [NSScrollView] {
            ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrolls)
        }
        for width in [340.0, 520.0] {
            controller.geometry.size = CGSize(width: width, height: 480)
            controller.layout()
            for page in ["list", "detail", "settings", "trash"] {
                model.back()
                if page == "detail" { model.select(model.state.liveTasks[0]) }
                if page == "settings" { model.showSettings() }
                if page == "trash" { model.trash = true }
                try await Task.sleep(for: .milliseconds(150))
                let host = try XCTUnwrap(controller.panel.contentView)
                let containers = scrolls(host)
                XCTAssertFalse(containers.isEmpty, page)
                // Reproduce the system's traditional always-visible style without changing system defaults.
                for scroll in containers { scroll.scrollerStyle = .legacy }
                host.layout()
                host.layoutSubtreeIfNeeded()
                for scroll in containers {
                    XCTAssertEqual(scroll.scrollerStyle, .overlay, "\(page), \(width)")
                    XCTAssertEqual(scroll.contentView.frame.width, scroll.bounds.width, accuracy: 1, "\(page), \(width): reserved right gutter")
                    if let scroller = scroll.verticalScroller { XCTAssertTrue(scroller is ThinScroller) }
                }
            }
        }
    }
}

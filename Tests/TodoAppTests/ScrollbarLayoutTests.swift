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
                    let indicator = try XCTUnwrap(scroll.subviews.first { $0 is PersistentScrollIndicator })
                    XCTAssertNil(indicator.hitTest(.zero))
                    XCTAssertEqual(indicator.frame.size, scroll.bounds.size)
                }
                if let path = ProcessInfo.processInfo.environment["SCROLLBAR_EVIDENCE"] {
                    try await Task.sleep(for: .seconds(2))
                    let capture = Process()
                    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    capture.arguments = ["-x", "-l", String(controller.panel.windowNumber), "\(path)/\(page)-\(Int(width)).png"]
                    try capture.run(); capture.waitUntilExit()
                    XCTAssertEqual(capture.terminationStatus, 0)
                }
            }
        }
    }

    @MainActor func testIdleThumbRenderingAndScrollPosition() async throws {
        _ = NSApplication.shared
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 800))
        scroll.documentView = document
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { window.close() }
        window.orderFrontRegardless()
        // Let AppKit apply the initial system style before applying the app's overlay policy.
        try await Task.sleep(for: .milliseconds(300))
        scroll.verticalScroller = ThinScroller.replacing(try XCTUnwrap(scroll.verticalScroller))
        scroll.horizontalScroller = ThinScroller.replacing(try XCTUnwrap(scroll.horizontalScroller))
        scroll.scrollerStyle = .overlay
        let indicator = PersistentScrollIndicator(scrollView: scroll)
        scroll.addSubview(indicator, positioned: .above, relativeTo: nil)
        scroll.flashScrollers()
        try await Task.sleep(for: .seconds(4))
        let vertical = try XCTUnwrap(scroll.verticalScroller as? ThinScroller)
        let horizontal = try XCTUnwrap(scroll.horizontalScroller as? ThinScroller)
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            window.appearance = NSAppearance(named: appearance)
            let bitmap = try XCTUnwrap(indicator.bitmapImageRepForCachingDisplay(in: indicator.bounds))
            indicator.cacheDisplay(in: indicator.bounds, to: bitmap)
            let painted = (0..<bitmap.pixelsHigh).contains { y in
                (0..<bitmap.pixelsWide).contains { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 }
            }
            XCTAssertTrue(painted, "Idle thumb must remain visible in \(appearance)")
        }
        XCTAssertEqual(vertical.visibleKnobRect.width, 3)
        XCTAssertEqual(vertical.visibleKnobRect.maxX, vertical.bounds.maxX)
        XCTAssertEqual(horizontal.visibleKnobRect.height, 3)
        XCTAssertEqual(scroll.contentView.frame.size, scroll.bounds.size)
        let thumbPoint = NSPoint(x: vertical.visibleKnobRect.midX, y: vertical.visibleKnobRect.midY)
        XCTAssertEqual(vertical.testPart(vertical.convert(thumbPoint, to: nil)), .knob)
        XCTAssertTrue(scroll.hitTest(vertical.convert(thumbPoint, to: scroll.superview)) === vertical)
        let before = vertical.visibleKnobRect
        scroll.contentView.scroll(to: NSPoint(x: 200, y: 200))
        scroll.reflectScrolledClipView(scroll.contentView)
        XCTAssertNotEqual(vertical.visibleKnobRect.origin, before.origin)
        XCTAssertNil(indicator.hitTest(NSPoint(x: 199, y: 100)))
        document.setFrameSize(NSSize(width: 100, height: 100))
        scroll.reflectScrolledClipView(scroll.contentView)
        XCTAssertTrue(vertical.visibleKnobRect.isEmpty)
        XCTAssertTrue(horizontal.visibleKnobRect.isEmpty)
    }
}

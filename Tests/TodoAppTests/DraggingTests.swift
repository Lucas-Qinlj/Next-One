import AppKit
import XCTest
import TodoCore
@testable import TodoApp

final class DraggingTests: XCTestCase {
    @MainActor func testNativeDragSessionLifecycle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project": "unclassified", "title": "Source"])
        let item = try XCTUnwrap(store.snapshot().liveTasks.first)
        let model = AppModel(store: store)
        let first = try XCTUnwrap(model.beginTaskDrag(item))
        XCTAssertEqual(model.taskDrag?.item.id, item.id)
        let second = try XCTUnwrap(model.beginTaskDrag(item))
        model.endTaskDrag(first.token)
        XCTAssertEqual(model.taskDrag?.token, second.token)
        model.dropHint = TaskDropHint(target: item.id, placement: "before")
        model.endTaskDrag(second.token)
        XCTAssertNil(model.taskDrag)
        XCTAssertNil(model.dropHint)
        XCTAssertEqual(try store.snapshot().liveTasks.first?.revision, 1)
    }
    @MainActor func testLocalDropUsesRowBoundsInsteadOfWholeVisibleArea() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        for title in ["Source", "First", "Second"] { _ = try store.execute("add", ["project": "unclassified", "title": title]) }
        let tasks = try store.snapshot().liveTasks
        let model = AppModel(store: store)
        model.taskDrag = TaskDrag(item: tasks[0])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400)); window.contentView = root
        let first = LocalDropRegion(frame: NSRect(x: 0, y: 200, width: 300, height: 40)); first.taskID = tasks[1].id
        let second = LocalDropRegion(frame: NSRect(x: 0, y: 100, width: 300, height: 40)); second.taskID = tasks[2].id
        root.addSubview(first); root.addSubview(second)
        model.dragRegions.add(first); model.dragRegions.add(second)
        model.updateLocalDrop(at: second.convert(NSPoint(x: 20, y: 20), to: nil), in: window)
        XCTAssertEqual(model.dropHint, TaskDropHint(target: tasks[2].id, placement: "merge"))
        model.updateLocalDrop(at: second.convert(NSPoint(x: 20, y: 38), to: nil), in: window)
        XCTAssertEqual(model.dropHint, TaskDropHint(target: tasks[2].id, placement: "after"))
        model.updateLocalDrop(at: NSPoint(x: 350, y: 350), in: window)
        XCTAssertNil(model.dropHint)
        first.isHidden = true
        model.updateLocalDrop(at: first.convert(NSPoint(x: 20, y: 20), to: nil), in: window)
        XCTAssertNil(model.dropHint)
    }
    @MainActor func testMergeOnlyUnclassifiedAndCancelLeavesData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project": "unclassified", "title": "Source"])
        _ = try store.execute("add", ["project": "unclassified", "title": "Target"])
        let items = try store.snapshot().liveTasks
        let model = AppModel(store: store)
        model.taskDrag = TaskDrag(item: items[0])
        XCTAssertEqual(model.placement(on: items[1], fraction: 0.5), "merge")
        XCTAssertEqual(model.placement(on: items[1], fraction: 0.1), "before")
        XCTAssertEqual(model.placement(on: items[1], fraction: 0.9), "after")
        XCTAssertNil(model.placement(on: items[0], fraction: 0.5))
        let before = try store.snapshot()
        XCTAssertTrue(model.finishDrop(on: items[1], placement: "merge"))
        XCTAssertNotNil(model.taskMerge)
        XCTAssertEqual(try store.snapshot(), before)
        model.taskMerge = nil
        XCTAssertEqual(try store.snapshot(), before)
        var assigned = items[0]; assigned.projectID = "some-project"
        model.taskDrag = TaskDrag(item: assigned)
        XCTAssertNotEqual(model.placement(on: items[1], fraction: 0.5), "merge")
        model.taskDrag = TaskDrag(item: items[0])
        XCTAssertNotEqual(model.placement(on: assigned, fraction: 0.5), "merge")
        model.taskDrag = nil
    }
}

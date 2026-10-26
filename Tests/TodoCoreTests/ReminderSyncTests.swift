import XCTest
@testable import TodoCore

final class ReminderSyncTests: XCTestCase {
    func testProjectionUsesUUIDMarkerNotReusedCodeAndNeverAttachmentsOrPaths() throws {
        var state = Snapshot()
        state.projects = [Project(id: "p", name: "Project", paths: ["/private/secret"])]
        let parent = TodoItem(id: "parent", projectID: "p", shortCode: "A1", title: "Parent")
        let child = TodoItem(id: "child", projectID: "p", parentID: parent.id, shortCode: "A2", title: "Child", description: "Notes", priority: "high", dueDate: "2026-10-27")
        state.tasks = [parent, child]
        let value = ReminderFields.project(child, in: state, marker: "NextOne:v1:dataset:child")
        XCTAssertEqual(value.title, "A2-Child")
        XCTAssertEqual(value.priority, 1)
        XCTAssertTrue(value.notes.contains("Project / Parent"))
        XCTAssertFalse(value.notes.contains("/private/secret"))
        var changed = child; changed.shortCode = "Z9"
        XCTAssertEqual(ReminderFields.project(changed, in: state, marker: "NextOne:v1:dataset:child").notes, value.notes)
        state.tasks[0].title = "Renamed"
        XCTAssertTrue(ReminderFields.project(child, in: state, marker: "m").notes.contains("Renamed"))
    }
    func testRemoteCompletionWinsBeforeLocalTitleIsPublished() {
        let old = ReminderFields(title: "Old", notes: "marker", dueDate: "2026-10-27", dueAt: nil, priority: 5)
        var local = old; local.title = "New"
        var link = ReminderLink(calendarID: "c", sourceID: "s"); link.fields = old
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: local, localDone: false, remote: old, remoteDone: true, recurring: false), .pullCompletion(true))
        link.completed = true
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: local, localDone: true, remote: old, remoteDone: false, recurring: false), .pullCompletion(false))
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: local, localDone: false, remote: old, remoteDone: false, recurring: false), .publish)
    }
    func testExternalEditAndRecurrenceRequireDecision() {
        let value = ReminderFields(title: "Old", notes: "marker", dueDate: nil, dueAt: nil, priority: 5)
        var remote = value; remote.title = "Phone"
        var link = ReminderLink(calendarID: "c", sourceID: "s"); link.fields = value
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: value, localDone: false, remote: remote, remoteDone: false, recurring: false), .conflict("edited"))
        link.forceLocal = true
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: value, localDone: false, remote: remote, remoteDone: false, recurring: false), .publish)
        XCTAssertEqual(ReminderDecision.evaluate(link: link, local: value, localDone: false, remote: remote, remoteDone: false, recurring: true), .conflict("recurring"))
    }
    func testDurableIntentExclusiveOwnerAndLegacyStoreCannotEraseMapping() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try Store(directory: dir)
        var file: ReminderSyncFile? = try ReminderSyncFile(directory: dir)
        var state = file!.state
        let marker = state.marker("task")
        state.links["task"] = ReminderLink(calendarID: "c", sourceID: "s")
        state.links["task"]?.issue = "missing"
        try file!.save(state)
        XCTAssertThrowsError(try ReminderSyncFile(directory: dir))
        _ = try store.execute("add", ["title":"CLI", "project":"unclassified"])
        file = nil
        let reopened = try ReminderSyncFile(directory: dir)
        XCTAssertEqual(reopened.state.marker("task"), marker)
        XCTAssertEqual(reopened.state.links["task"]?.issue, "missing")
        XCTAssertFalse(reopened.state.enabled)
    }
    func testCopiedDataCannotSilentlyBecomeSecondWriter() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source"), copy = root.appendingPathComponent("copy")
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try Store(directory: source)
        do { _ = try ReminderSyncFile(directory: source) }
        try FileManager.default.copyItem(at: source, to: copy)
        XCTAssertThrowsError(try ReminderSyncFile(directory: copy))
    }
    func testInboundCompletionUsesBusinessRulesAndOriginalCompletionTime() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try Store(directory: dir)
        let p = try store.execute("add", ["title": "parent", "project": "unclassified"])["task"] as! [String: Any]
        let id = p["id"] as! String
        let c = try store.execute("add", ["title": "child", "parent": id])["task"] as! [String: Any]
        let child = c["id"] as! String
        let date = Date(timeIntervalSince1970: 1700000000)
        XCTAssertThrowsError(try store.applyReminderCompletion(id: id, expectedRevision: 1, status: "done", completionDate: date))
        XCTAssertEqual(try store.snapshot().liveTasks.first { $0.id == id }?.status, "todo")
        try store.applyReminderCompletion(id: child, expectedRevision: 1, status: "done", completionDate: date)
        XCTAssertEqual(try store.snapshot().liveTasks.first { $0.id == child }?.completedAt, ISO8601DateFormatter().string(from: date))
        XCTAssertThrowsError(try store.applyReminderCompletion(id: child, expectedRevision: 1, status: "todo", completionDate: nil))
        try store.applyReminderCompletion(id: id, expectedRevision: 1, status: "done", completionDate: date)
        let revision = try store.snapshot().liveTasks.first { $0.id == child }!.revision
        try store.applyReminderCompletion(id: child, expectedRevision: revision, status: "in_progress", completionDate: nil)
        let state = try store.snapshot()
        XCTAssertEqual(state.liveTasks.first { $0.id == child }?.status, "in_progress")
        XCTAssertEqual(state.liveTasks.first { $0.id == id }?.status, "todo")
    }

}

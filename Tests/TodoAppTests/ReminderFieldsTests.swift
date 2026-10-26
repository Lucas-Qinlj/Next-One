import XCTest
import EventKit
import TodoCore
@testable import TodoApp

@MainActor final class ReminderFieldsTests: XCTestCase {
    func testDatesAndOwnedAlarmDoNotEraseUnmanagedAlarm() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let bridge = ReminderSync(store: try Store(directory: dir))
        let reminder = EKReminder(eventStore: EKEventStore())
        let future = "2099-10-27T09:45:00Z"
        let value = ReminderFields(title: "A1-Test", notes: "Test", dueDate: nil, dueAt: future, priority: 1)
        let other = Date(timeIntervalSince1970: 123456)
        reminder.addAlarm(EKAlarm(absoluteDate: other))
        bridge.apply(value, done: false, completedAt: nil, to: reminder)
        bridge.updateAlarm(reminder, old: nil, new: value, done: false)
        XCTAssertEqual(bridge.fields(reminder), value)
        XCTAssertEqual(reminder.alarms?.count, 2)
        bridge.updateAlarm(reminder, old: value, new: value, done: true)
        XCTAssertEqual(reminder.alarms?.map(\.absoluteDate), [other])
        let day = ReminderFields(title: "Day", notes: "", dueDate: "2026-10-27", dueAt: nil, priority: 9)
        bridge.apply(day, done: true, completedAt: "2026-10-26T01:00:00Z", to: reminder)
        XCTAssertEqual(bridge.fields(reminder), day)
        XCTAssertNil(reminder.dueDateComponents?.hour)
        XCTAssertTrue(reminder.isCompleted)
    }
}

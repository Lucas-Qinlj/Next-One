import Foundation
import Darwin

public struct ReminderFields: Codable, Equatable {
    public var title: String
    public var notes: String
    public var dueDate: String?
    public var dueAt: String?
    public var priority: Int
    public init(title: String, notes: String, dueDate: String?, dueAt: String?, priority: Int) {
        self.title = title; self.notes = notes; self.dueDate = dueDate; self.dueAt = dueAt; self.priority = priority
    }
    public static func project(_ task: TodoItem, in snapshot: Snapshot, marker: String) -> Self {
        let project = snapshot.projects.first { $0.id == task.projectID }?.name ?? ""
        let path = snapshot.ancestors(task.id).reversed().map(\.title).joined(separator: " / ")
        let context = [project, path].filter { !$0.isEmpty }.joined(separator: " / ")
        return Self(title: "\(task.shortCode ?? "")-\(task.title)",
                    notes: task.description + "\n\n—— Next One ——\n" + context + "\n" + marker,
                    dueDate: task.dueDate, dueAt: task.dueAt,
                    priority: ["high": 1, "medium": 5, "low": 9][task.priority] ?? 5)
    }
}
public struct ReminderLink: Codable, Equatable {
    public var itemID: String?
    public var calendarID: String
    public var sourceID: String
    public var fields: ReminderFields?
    public var completed: Bool = false
    public var previousStatus = "todo"
    public var issue: String?
    public var stopped = false
    public var forceLocal = false
    public var removed = false
    public init(calendarID: String, sourceID: String) { self.calendarID = calendarID; self.sourceID = sourceID }
}
public struct ReminderSyncState: Codable {
    public var version = 1
    public var datasetID = UUID().uuidString
    public var ownerPath: String
    public var enabled = false
    public var calendarID = ""
    public var sourceID = ""
    public var generation = 0
    public var links: [String: ReminderLink] = [:]
    public init(ownerPath: String) { self.ownerPath = ownerPath }
    public func marker(_ id: String) -> String { "NextOne:v1:\(datasetID):\(id)" }
}

/// Independent sidecar: old CLI versions cannot erase sync metadata when rewriting task snapshots.
/// Task changes remain durable in Store; latest projections reconstruct outgoing work after a crash.
public final class ReminderSyncFile {
    private let descriptor: Int32
    private let url: URL
    public private(set) var state: ReminderSyncState
    public init(directory: URL) throws {
        let path = directory.resolvingSymlinksInPath().standardizedFileURL.path
        url = directory.appendingPathComponent("reminder-sync.json")
        descriptor = open(directory.appendingPathComponent("reminder-sync.lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw TodoError("sync_storage", "无法打开同步记录。") }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor); throw TodoError("sync_busy", "另一个 Next One 正在同步此数据目录。")
        }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                state = try JSONDecoder().decode(ReminderSyncState.self, from: Data(contentsOf: url))
                guard state.version == 1 else { throw TodoError("sync_version", "同步记录版本较新，请升级应用。") }
                guard state.ownerPath == path else { throw TodoError("sync_copy", "数据目录已移动或复制；请先核对原同步记录，避免重复同步。") }
            } else {
                state = ReminderSyncState(ownerPath: path)
                try Self.write(state, to: url)
            }
        } catch { flock(descriptor, LOCK_UN); close(descriptor); throw error }
    }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }
    public func save(_ next: ReminderSyncState) throws {
        try Self.write(next, to: url); state = next
    }
    private static func write(_ value: ReminderSyncState, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        let fd = open(url.path, O_RDONLY)
        if fd >= 0 { defer { close(fd) }; guard fsync(fd) == 0 else { throw TodoError("sync_storage", "无法保存同步记录。") } }
    }
}

public enum ReminderDecision: Equatable {
    case publish, pullCompletion(Bool), conflict(String)
    public static func evaluate(link: ReminderLink, local: ReminderFields, localDone: Bool,
                                remote: ReminderFields, remoteDone: Bool, recurring: Bool) -> Self {
        if recurring { return .conflict("recurring") }
        if link.forceLocal { return .publish }
        if let baseline = link.fields, remote != baseline { return .conflict("edited") }
        if remoteDone != link.completed && localDone == link.completed { return .pullCompletion(remoteDone) }
        return .publish
    }
}

import Foundation

public struct TodoError: Error, LocalizedError {
    public let code: String
    public let message: String
    public init(_ code: String, _ message: String) { self.code = code; self.message = message }
    public var errorDescription: String? { message }
}
public struct Project: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var paths: [String]
    public var revision: Int = 1
}
public struct TodoItem: Codable, Identifiable, Equatable {
    public var id: String = UUID().uuidString
    public var projectID: String?
    public var parentID: String?
    public var title: String
    public var description: String = ""
    public var status: String = "todo"
    public var priority: String = "medium"
    public var sortOrder: Int?
    public var color: String = "none"
    public var dueDate: String?
    public var dueAt: String?
    public var createdAt: String = timestamp()
    public var updatedAt: String = timestamp()
    public var completedAt: String?
    public var source: String = "user"
    public var revision: Int = 1
    public var deletionID: String?
}
public struct Attachment: Codable, Identifiable, Equatable {
    public var id: String
    public var taskID: String
    public var filename: String
    public var mediaType: String
    public var bytes: Int
    public var storedName: String
    public var deleted: Bool = false
}
public struct RequestRecord: Codable, Equatable {
    var fingerprint: String
    var response: Data
}
public struct Snapshot: Codable, Equatable {
    public var projects: [Project] = []
    public var tasks: [TodoItem] = []
    public var attachments: [Attachment] = []
    public var boardOrder: [String]?
    public var boardRevision: Int?
    var requests: [String: RequestRecord] = [:]
    public init() {}
    public var liveTasks: [TodoItem] { tasks.filter { $0.deletionID == nil } }
    public func children(_ id: String?) -> [TodoItem] {
        liveTasks.filter { $0.parentID == id }.sorted(by: taskOrder)
    }
    public var boardKeys: [String] {
        let roots = children(nil)
        let defaults = projects.filter { p in roots.contains { $0.projectID == p.id } }.map { "p:" + $0.id }
            + roots.filter { $0.projectID == nil && $0.status != "done" }.map { "t:" + $0.id }
        let valid = Set(defaults)
        var seen = Set<String>()
        return ((boardOrder ?? []) + defaults).filter { valid.contains($0) && seen.insert($0).inserted }
    }
    public func descendants(_ id: String) -> [TodoItem] {
        let kids = children(id)
        return kids + kids.flatMap { descendants($0.id) }
    }
    public func ancestors(_ id: String) -> [TodoItem] {
        var result: [TodoItem] = []
        var next = tasks.first { $0.id == id }?.parentID
        while let parent = next, let item = tasks.first(where: { $0.id == parent }) {
            if result.contains(where: { $0.id == parent }) { break }
            result.append(item); next = item.parentID
        }
        return result
    }
}
public func taskOrder(_ a: TodoItem, _ b: TodoItem) -> Bool {
    if a.sortOrder != b.sortOrder { return (a.sortOrder ?? Int.max) < (b.sortOrder ?? Int.max) }
    let rank = ["high": 0, "medium": 1, "low": 2]
    if rank[a.priority] != rank[b.priority] { return rank[a.priority, default: 1] < rank[b.priority, default: 1] }
    let da = a.dueDate ?? a.dueAt ?? "9999", db = b.dueDate ?? b.dueAt ?? "9999"
    return da == db ? (a.createdAt == b.createdAt ? a.id < b.id : a.createdAt < b.createdAt) : da < db
}
public func timestamp() -> String { ISO8601DateFormatter().string(from: Date()) }
public func jsonObject<T: Encodable>(_ value: T) throws -> Any {
    let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
    return try JSONSerialization.jsonObject(with: encoder.encode(value))
}
public func normalizedPath(_ path: String) -> String {
    URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).standardizedFileURL.resolvingSymlinksInPath().path
}

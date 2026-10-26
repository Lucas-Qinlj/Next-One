import Foundation
import CryptoKit

public struct TodoError: Error, LocalizedError {
    public let code: String
    public let message: String
    public let localizedText: LocalizedText
    public init(_ code: String, _ message: LocalizedText) { self.code = code; self.localizedText = message; self.message = message.original }
    public init(_ code: String, verbatim message: String) { self.init(code, LocalizedText(stringLiteral: message)) }
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
    public var shortCode: String?
    public var title: String
    public var description: String = ""
    public var status: String = "todo"
    public var priority: String = "low"
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
    public var nextTaskNumber: Int?
    var requests: [String: RequestRecord] = [:]
    public init() {}
    // Bijective base-26 letters with one base-9 (1...9) digit.
    public static func taskCode(_ number: Int) -> String {
        precondition(number > 0)
        var letters = (number - 1) / 9 + 1
        var prefix = ""
        while letters > 0 {
            letters -= 1
            prefix = String(UnicodeScalar(65 + letters % 26)!) + prefix
            letters /= 26
        }
        return prefix + String((number - 1) % 9 + 1)
    }
    mutating func allocateTaskCode(occupied: inout Set<String>) throws -> String {
        var number = nextTaskNumber ?? 1
        while number > 0 && number < Int.max {
            let code = Self.taskCode(number)
            number += 1
            if occupied.insert(code).inserted {
                nextTaskNumber = number
                return code
            }
        }
        throw TodoError("storage_unavailable", verbatim: "Task number capacity exceeded.")
    }
    mutating func allocateTaskCode() throws -> String {
        var occupied = Set(liveTasks.compactMap(\.shortCode))
        return try allocateTaskCode(occupied: &occupied)
    }
    mutating func assignLegacyTaskCodes() throws {
        var occupied = Set<String>()
        let indices = tasks.indices.sorted {
            tasks[$0].createdAt == tasks[$1].createdAt ? tasks[$0].id < tasks[$1].id : tasks[$0].createdAt < tasks[$1].createdAt
        }
        for i in indices { tasks[i].shortCode = try allocateTaskCode(occupied: &occupied) }
    }
    public var needsCodeArchiving: Bool { tasks.contains { $0.deletionID == nil && ($0.shortCode?.count ?? 0) >= 4 } }
    public var completedArchiveTasks: [TodoItem] { tasks.filter { $0.deletionID == nil && $0.status == "done" } }
    public var completedArchiveToken: String {
        let input = completedArchiveTasks.sorted { $0.id < $1.id }.map { "\($0.id):\($0.revision)" }.joined(separator: "\n")
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public func taskTreeCount(_ roots: [TodoItem]) -> Int {
        roots.reduce(0) { $0 + 1 + descendants($1.id).count }
    }
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

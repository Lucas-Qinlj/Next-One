import Foundation
import CSQLite
import UniformTypeIdentifiers

public final class Store {
    public let directory: URL
    private var db: OpaquePointer?
    private let lock = NSRecursiveLock()
    public static var defaultDirectoryName: String {
        #if TODO_AI_DISTRIBUTION
        return "Next-One-Release"
        #else
        return "Next-One"
        #endif
    }
    static func resolveDirectory(environment: [String: String], applicationSupport: URL) -> URL {
        if let path = environment["NEXT_ONE_HOME"] ?? environment["TODO_AI_HOME"] { return URL(fileURLWithPath: path) }
        return applicationSupport.appendingPathComponent(defaultDirectoryName)
    }
    public static var defaultDirectory: URL {
        resolveDirectory(environment: ProcessInfo.processInfo.environment,
                         applicationSupport: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0])
    }
    static func prepareDefaultDirectory(_ directory: URL, legacy: URL) throws {
        let fm = FileManager.default
        // Alias the existing store instead of copying a live SQLite database or splitting writes.
        if (try? directory.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            guard (try? directory.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                throw TodoError("storage_unavailable", verbatim: "Invalid data directory link: " + directory.path)
            }
            return
        }
        if fm.fileExists(atPath: directory.path) { return }
        guard fm.fileExists(atPath: legacy.path) else { return }
        guard (try? legacy.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
            throw TodoError("storage_unavailable", verbatim: "Legacy data path is not a directory: " + legacy.path)
        }
        do { try fm.createSymbolicLink(at: directory, withDestinationURL: legacy) }
        catch {
            // A concurrent app/CLI may have created exactly the same link.
            guard directory.resolvingSymlinksInPath() == legacy.resolvingSymlinksInPath(), fm.fileExists(atPath: directory.path) else { throw error }
        }
    }
    public init(directory explicitDirectory: URL? = nil) throws {
        let directory = explicitDirectory ?? Store.defaultDirectory
        self.directory = directory
        do {
            let env = ProcessInfo.processInfo.environment
            if explicitDirectory == nil && env["NEXT_ONE_HOME"] == nil && env["TODO_AI_HOME"] == nil {
                let legacyName = Store.defaultDirectoryName.replacingOccurrences(of: "Next-One", with: "Todo-AI")
                try Store.prepareDefaultDirectory(directory, legacy: directory.deletingLastPathComponent().appendingPathComponent(legacyName))
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("attachments"), withIntermediateDirectories: true)
        } catch { throw TodoError("storage_unavailable", verbatim: error.localizedDescription) }
        guard sqlite3_open_v2(directory.appendingPathComponent("todo.sqlite").path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if db != nil { sqlite3_close(db); db = nil }
            throw TodoError("storage_unavailable", "无法打开待办存储。")
        }
        sqlite3_busy_timeout(db, 5000)
        try sql("PRAGMA journal_mode=WAL")
        try sql("PRAGMA synchronous=FULL")
        let version = try scalar("PRAGMA user_version")
        guard ["0", "1", "2", "3"].contains(version) else { throw TodoError("storage_unavailable", "数据版本较新，请升级应用；未修改数据。") }
        try sql("BEGIN IMMEDIATE")
        do {
            try sql("CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), json TEXT NOT NULL)")
            if try scalar("SELECT json FROM state WHERE id=1").isEmpty { try save(Snapshot()) }
            // Read version again inside the write lock: another process may have migrated it.
            let lockedVersion = try scalar("PRAGMA user_version")
            guard ["0", "1", "2", "3"].contains(lockedVersion) else { throw TodoError("storage_unavailable", "数据版本较新，请升级应用；未修改数据。") }
            if lockedVersion != "3" {
                var state = try load()
                if lockedVersion == "0" || lockedVersion == "1" { try state.assignLegacyTaskCodes() }
                for i in state.tasks.indices where state.tasks[i].deletionID != nil { state.tasks[i].shortCode = nil }
                try save(state)
                try sql("PRAGMA user_version=3")
            }
            try sql("COMMIT")
        } catch { try? sql("ROLLBACK"); throw error }
    }
    deinit { sqlite3_close(db) }
    private func sql(_ query: String) throws {
        guard sqlite3_exec(db, query, nil, nil, nil) == SQLITE_OK else { throw databaseError() }
    }
    private func databaseError() -> TodoError { TodoError("storage_unavailable", verbatim: String(cString: sqlite3_errmsg(db))) }
    private func scalar(_ query: String) throws -> String {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        let step = sqlite3_step(stmt)
        if step == SQLITE_DONE { return "" }
        guard step == SQLITE_ROW else { throw databaseError() }
        return sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
    }
    private func load() throws -> Snapshot {
        do { return try JSONDecoder().decode(Snapshot.self, from: Data(scalar("SELECT json FROM state WHERE id=1").utf8)) }
        catch let error as TodoError { throw error }
        catch { throw TodoError("storage_unavailable", "数据无法读取，已保留原文件：\(error.localizedDescription)") }
    }
    private func save(_ state: Snapshot) throws {
        // ponytail: one transactional snapshot suits a personal task list; normalize tables if measured size demands it.
        let data = try JSONEncoder().encode(state)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO state(id,json) VALUES(1,?)", -1, &stmt, nil) == SQLITE_OK else { throw databaseError() }
        defer { sqlite3_finalize(stmt) }
        let json = String(decoding: data, as: UTF8.self)
        let result = json.withCString { pointer -> Int32 in
            sqlite3_bind_text(stmt, 1, pointer, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            return sqlite3_step(stmt)
        }
        guard result == SQLITE_DONE else { throw databaseError() }
    }
    public func snapshot() throws -> Snapshot { lock.lock(); defer { lock.unlock() }; return try load() }
    public func attachmentURL(_ attachment: Attachment) -> URL { directory.appendingPathComponent("attachments").appendingPathComponent(attachment.storedName) }

    public func execute(_ command: String, _ args: [String: String] = [:]) throws -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        try validateArguments(command, args)
        let readOnly = ["project list", "board list", "context", "list", "get", "trash", "archive preview"].contains(command)
        try sql(readOnly ? "BEGIN" : "BEGIN IMMEDIATE")
        var copied: URL?
        do {
            var state = try load()
            let fingerprint = String(decoding: try JSONSerialization.data(withJSONObject: ["command": command, "args": args], options: [.sortedKeys]), as: UTF8.self)
            if let key = args["request-key"], let record = state.requests[key] {
                guard record.fingerprint == fingerprint else { throw TodoError("idempotency_conflict", "请求标识已用于不同内容。") }
                let result = try JSONSerialization.jsonObject(with: record.response) as! [String: Any]
                try sql("COMMIT"); return result
            }
            let resolved = try resolveTaskReferences(command, args, state)
            let result = try perform(command, resolved, &state, &copied)
            if !readOnly {
                if let key = args["request-key"] {
                    state.requests[key] = RequestRecord(fingerprint: fingerprint, response: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
                }
                try save(state)
            }
            try sql("COMMIT")
            return result
        } catch {
            try? sql("ROLLBACK")
            if let copied { try? FileManager.default.removeItem(at: copied) }
            throw error
        }
    }
    /// Internal reminder bridge entry: reuse update validation and hierarchy rules in the same transaction.
    public func applyReminderCompletion(id: String, expectedRevision: Int, status: String, completionDate: Date?) throws {
        lock.lock(); defer { lock.unlock() }
        try sql("BEGIN IMMEDIATE")
        var copied: URL?
        do {
            var state = try load()
            guard state.tasks.contains(where: { $0.id == id && $0.deletionID == nil }) else { throw TodoError("not_found", "待办不存在或已删除。") }
            _ = try perform("update", ["id": id, "expected-revision": String(expectedRevision), "status": status], &state, &copied)
            if status == "done", let date = completionDate, date.timeIntervalSince1970.isFinite,
               let index = state.tasks.firstIndex(where: { $0.id == id }) {
                state.tasks[index].completedAt = ISO8601DateFormatter().string(from: date)
            }
            try save(state); try sql("COMMIT")
        } catch { try? sql("ROLLBACK"); throw error }
    }
    private func resolveTaskReferences(_ command: String, _ args: [String: String], _ state: Snapshot) throws -> [String: String] {
        var resolved = args
        var fields: [String] = []
        if !command.hasPrefix("project "), command != "board place" { fields.append("id") }
        if ["add", "move", "place"].contains(command) { fields.append("parent") }
        if command == "place" { fields.append("anchor") }
        if command == "group" { fields.append("target") }
        for field in fields {
            guard let value = args[field], !(field == "parent" && value == "root") else { continue }
            let id = state.tasks[try index(value, state, deleted: command == "restore")].id
            if command != "get", value != id { throw TodoError("invalid_field", "写入请使用 get 返回的任务 ID，编号可能已被复用。") }
            resolved[field] = id
        }
        if command == "board place" {
            for field in ["key", "anchor"] {
                if let value = args[field], value.hasPrefix("t:") {
                    let id = state.tasks[try index(String(value.dropFirst(2)), state)].id
                    guard value == "t:" + id else { throw TodoError("invalid_field", "写入请使用 get 返回的任务 ID，编号可能已被复用。") }
                    resolved[field] = "t:" + id
                }
            }
        }
        return resolved
    }
    private func validateArguments(_ command: String, _ args: [String: String]) throws {
        let fields = "title description status priority color due-date due-at"
        let options: [String: String] = [
            "archive preview": "", "archive completed": "expected-token request-key",
            "board list": "", "board place": "key expected-revision expected-board-revision anchor placement",
            "project create": "name", "place": "id expected-revision anchor anchor-revision placement project parent",
            "group": "id expected-revision target target-revision project name",
            "project unbind": "id path expected-revision", "project list": "", "project bind": "path name project expected-revision", "project update": "id name path replace-path expected-revision",
            "context": "cwd limit offset", "list": "project status limit offset", "get": "id", "trash": "",
            "add": "project parent source request-key \(fields)", "update": "id expected-revision cascade \(fields)",
            "complete": "id expected-revision cascade", "move": "id project parent expected-revision",
            "delete": "id expected-revision", "restore": "id expected-revision",
            "attachment add": "id path expected-revision request-key", "attachment delete": "id attachment expected-revision",
            "attachment restore": "id attachment expected-revision"
        ]
        guard let allowed = options[command] else { throw TodoError("invalid_field", "未知命令：\(command)") }
        let keys = Set(allowed.split(separator: " ").map(String.init))
        if let unknown = args.keys.first(where: { !keys.contains($0) }) { throw TodoError("invalid_field", "不支持的字段：\(unknown)") }
        if let key = args["request-key"], key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw TodoError("invalid_field", "请求标识不能为空。") }
        for name in ["cascade"] where args[name] != nil && args[name] != "true" { throw TodoError("invalid_field", "\(name) 必须为 true。") }
    }
    private func required(_ key: String, _ args: [String: String]) throws -> String {
        guard let value = args[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TodoError("invalid_field", "缺少 \(key)。") }
        return value
    }
    private func checkRevision(_ revision: Int, _ args: [String: String]) throws {
        guard let value = args["expected-revision"], Int(value) == revision else {
            throw TodoError("revision_conflict", "内容已变化或缺少版本；请重新读取再局部更新。当前版本 \(revision)。")
        }
    }
    private func projectID(_ value: String?, _ state: Snapshot) throws -> String? {
        guard let value else { throw TodoError("project_unmatched", "请明确指定项目或 unclassified。") }
        if value == "unclassified" { return nil }
        guard state.projects.contains(where: { $0.id == value }) else { throw TodoError("not_found", "项目不存在。") }
        return value
    }
    private func index(_ id: String, _ state: Snapshot, deleted: Bool = false) throws -> Int {
        guard let i = state.tasks.firstIndex(where: { ($0.id == id || $0.shortCode == id.uppercased()) && (deleted || $0.deletionID == nil) }) else { throw TodoError("not_found", "待办不存在或已删除。") }
        return i
    }
    private func touch(_ item: inout TodoItem) { item.revision += 1; item.updatedAt = timestamp() }
    private func validate(_ item: TodoItem) throws {
        guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TodoError("invalid_field", "标题不能为空。") }
        guard ["todo", "in_progress", "done"].contains(item.status), ["high", "medium", "low"].contains(item.priority), ["none", "red", "orange", "green", "blue", "purple"].contains(item.color), ["user", "codex"].contains(item.source) else { throw TodoError("invalid_field", "状态、优先级、颜色或来源无效。") }
        guard item.dueDate == nil || item.dueAt == nil else { throw TodoError("invalid_field", "日期和具体时间不能同时设置。") }
        if let date = item.dueDate {
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
            guard let parsed = f.date(from: date), f.string(from: parsed) == date else { throw TodoError("invalid_field", "日期格式须为 yyyy-MM-dd。") }
        }
        if let date = item.dueAt, ISO8601DateFormatter().date(from: date) == nil { throw TodoError("invalid_field", "具体时间须为含时区的 ISO 8601 时间。") }
    }
    private func applyFields(_ args: [String: String], _ item: inout TodoItem) throws {
        if let value = args["title"] { item.title = value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = args["description"] { item.description = value }
        if let value = args["status"] { item.status = value }
        if let value = args["priority"] { item.priority = value }
        if let value = args["color"] { item.color = value }
        if let value = args["due-date"] { item.dueDate = value.isEmpty ? nil : value; if !value.isEmpty { item.dueAt = nil } }
        if let value = args["due-at"] { item.dueAt = value.isEmpty ? nil : value; if !value.isEmpty { item.dueDate = nil } }
        if let date = item.dueAt, let parsed = ISO8601DateFormatter().date(from: date) { item.dueAt = ISO8601DateFormatter().string(from: parsed) }
        if args["due-date"]?.isEmpty == false && args["due-at"]?.isEmpty == false { throw TodoError("invalid_field", "不能同时设置两种截止时间。") }
        try validate(item)
    }
    private func reopenAncestors(_ id: String, _ state: inout Snapshot) -> [String] {
        let ids = state.ancestors(id).filter { $0.status == "done" }.map(\.id)
        for id in ids { if let i = state.tasks.firstIndex(where: { $0.id == id }) { state.tasks[i].status = "todo"; state.tasks[i].completedAt = nil; touch(&state.tasks[i]) } }
        return ids
    }
    private func perform(_ command: String, _ args: [String: String], _ state: inout Snapshot, _ copied: inout URL?) throws -> [String: Any] {
        switch command {
        case "archive preview":
            return ["count": state.completedArchiveTasks.count, "token": state.completedArchiveToken]
        case "archive completed":
            guard try required("expected-token", args) == state.completedArchiveToken else {
                throw TodoError("revision_conflict", "已完成任务已变化，请重新确认归档范围。")
            }
            let candidates = state.completedArchiveTasks
            let completed = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
            var deletions: [String: String] = [:]
            var affected: [String] = []
            for i in state.tasks.indices where completed[state.tasks[i].id] != nil {
                var root = state.tasks[i]
                var visited = Set<String>()
                while let parent = root.parentID.flatMap({ completed[$0] }), visited.insert(parent.id).inserted { root = parent }
                let deletion = deletions[root.id] ?? UUID().uuidString
                deletions[root.id] = deletion
                state.tasks[i].deletionID = deletion
                state.tasks[i].shortCode = nil
                touch(&state.tasks[i])
                affected.append(state.tasks[i].id)
            }
            state.nextTaskNumber = 1
            return ["count": affected.count, "affected_ids": affected]
        case "board list": return ["ordered_keys": state.boardKeys, "board_revision": state.boardRevision ?? 0]
        case "board place":
            let key = try required("key", args)
            guard Int(args["expected-board-revision"] ?? "") == (state.boardRevision ?? 0) else { throw TodoError("revision_conflict", "清单顺序已变化，请重新拖动。") }
            let placement = try required("placement", args)
            guard ["before", "after", "end"].contains(placement) else { throw TodoError("invalid_field", "顶层插入位置无效。") }
            var keys = state.boardKeys.filter { $0 != key }
            var position = keys.count
            if placement != "end" {
                let anchor = try required("anchor", args)
                guard let k = keys.firstIndex(of: anchor) else { throw TodoError("invalid_field", "目标分组或任务已变化。") }
                position = k + (placement == "after" ? 1 : 0)
            }
            if key.hasPrefix("p:") {
                guard let p = state.projects.firstIndex(where: { $0.id == String(key.dropFirst(2)) }), state.boardKeys.contains(key) else { throw TodoError("not_found", "项目分组不存在。") }
                try checkRevision(state.projects[p].revision, args)
                state.projects[p].revision += 1
            } else if key.hasPrefix("t:") {
                let id = String(key.dropFirst(2)), i = try index(String(key.dropFirst(2)), state)
                try checkRevision(state.tasks[i].revision, args)
                guard state.tasks[i].status != "done" else { throw TodoError("invalid_field", "已完成任务保留在已完成分区。") }
                _ = try perform("move", ["id": id, "expected-revision": String(state.tasks[i].revision), "project": "unclassified", "parent": "root"], &state, &copied)
            } else { throw TodoError("invalid_field", "顶层对象无效。") }
            keys.insert(key, at: position)
            state.boardOrder = keys
            state.boardOrder = state.boardKeys
            state.boardRevision = (state.boardRevision ?? 0) + 1
            return ["ordered_keys": state.boardOrder!, "board_revision": state.boardRevision!]
        case "project create":
            let name = try required("name", args).trimmingCharacters(in: .whitespacesAndNewlines)
            let project = Project(id: UUID().uuidString, name: name, paths: [])
            state.projects.append(project)
            return ["project": try jsonObject(project)]
        case "place":
            let id = try required("id", args)
            let source = state.tasks[try index(id, state)]
            try checkRevision(source.revision, args)
            let placement = try required("placement", args)
            guard ["before", "after", "end"].contains(placement) else { throw TodoError("invalid_field", "插入位置无效。") }
            var destination: String?
            var parent: String?
            var anchor: TodoItem?
            if placement != "end" {
                guard args["project"] == nil && args["parent"] == nil else { throw TodoError("invalid_field", "相邻插入由目标任务确定项目与父级。") }
                let target = state.tasks[try index(required("anchor", args), state)]
                guard target.id != id else { throw TodoError("invalid_field", "不能放到自己旁边。") }
                try checkRevision(target.revision, ["expected-revision": args["anchor-revision"] ?? ""])
                guard (source.status == "done") == (target.status == "done") else { throw TodoError("invalid_field", "请在相同完成状态分区内排序。") }
                anchor = target; destination = target.projectID; parent = target.parentID
            } else {
                destination = try projectID(args["project"], state)
                parent = args["parent"] == "root" ? nil : args["parent"]
            }
            var result = try perform("move", ["id": id, "expected-revision": String(source.revision), "project": destination ?? "unclassified", "parent": parent ?? "root"], &state, &copied)
            var peers = state.children(parent).filter { $0.projectID == destination && ($0.status == "done") == (source.status == "done") && $0.id != id }
            var insertion = peers.count
            if let anchor {
                guard let position = peers.firstIndex(where: { $0.id == anchor.id }) else { throw TodoError("invalid_field", "目标已不在同级列表中。") }
                insertion = position + (placement == "after" ? 1 : 0)
            }
            peers.insert(state.tasks[try index(id, state)], at: insertion)
            for (order, peer) in peers.enumerated() {
                let k = try index(peer.id, state)
                if state.tasks[k].sortOrder != order {
                    state.tasks[k].sortOrder = order
                    if peer.id != id { touch(&state.tasks[k]) }
                }
            }
            if destination == nil, parent == nil, source.status != "done", state.boardOrder != nil {
                let key = "t:" + id
                var board = state.boardKeys.filter { $0 != key }
                var position = board.count
                if let anchor, let index = board.firstIndex(of: "t:" + anchor.id) {
                    position = index + (placement == "after" ? 1 : 0)
                }
                board.insert(key, at: position)
                state.boardOrder = board
                state.boardRevision = (state.boardRevision ?? 0) + 1
            }
            result["task"] = try jsonObject(state.tasks[try index(id, state)])
            result["ordered_ids"] = peers.map(\.id)
            result["affected_ids"] = Array(Set((result["affected_ids"] as? [String] ?? []) + peers.map(\.id))).sorted()
            return result
        case "group":
            let id = try required("id", args), targetID = try required("target", args)
            let source = state.tasks[try index(id, state)], target = state.tasks[try index(targetID, state)]
            try checkRevision(source.revision, args)
            try checkRevision(target.revision, ["expected-revision": args["target-revision"] ?? ""])
            guard id != targetID, source.projectID == nil, target.projectID == nil else { throw TodoError("invalid_field", "只能合并两条不同的未分类待办。") }
            guard !state.descendants(id).contains(where: { $0.id == targetID }), !state.descendants(targetID).contains(where: { $0.id == id }) else { throw TodoError("cycle_detected", "不能将同一分支的祖先与后代合并。") }
            guard (args["project"] == nil) != (args["name"] == nil) else { throw TodoError("invalid_field", "选择空项目或填写新项目名称，不能同时指定。") }
            let destination: String
            if let value = args["project"] {
                guard let pid = try projectID(value, state), !state.liveTasks.contains(where: { $0.projectID == pid }) else { throw TodoError("invalid_field", "请选择没有待办的项目。") }
                destination = pid
            } else {
                let result = try perform("project create", ["name": try required("name", args)], &state, &copied)
                destination = (result["project"] as! [String: Any])["id"] as! String
            }
            var affected: [String] = []
            for (order, task) in [target, source].enumerated() {
                let result = try perform("move", ["id": task.id, "expected-revision": String(task.revision), "project": destination, "parent": "root"], &state, &copied)
                affected += result["affected_ids"] as? [String] ?? []
                state.tasks[try index(task.id, state)].sortOrder = order
            }
            return ["project": try jsonObject(state.projects.first { $0.id == destination }!), "affected_ids": affected]
        case "project unbind":
            let id = try required("id", args), raw = try required("path", args)
            guard let i = state.projects.firstIndex(where: { $0.id == id }) else { throw TodoError("not_found", "项目不存在。") }
            try checkRevision(state.projects[i].revision, args)
            guard let path = state.projects[i].paths.first(where: { $0 == raw || $0 == normalizedPath(raw) }) else { throw TodoError("not_found", "该目录没有绑定到此项目。") }
            state.projects[i].paths.removeAll { $0 == path }
            state.projects[i].revision += 1
            return ["project": try jsonObject(state.projects[i]), "removed_path": path]
        case "project list": return ["projects": try jsonObject(state.projects)]
        case "project bind", "project update":
            let updating = command == "project update"
            let target = updating ? try required("id", args) : args["project"]
            var project: Project
            if let target {
                guard let existing = state.projects.first(where: { $0.id == target }) else { throw TodoError("not_found", "项目不存在。") }
                try checkRevision(existing.revision, args); project = existing
            } else { project = Project(id: UUID().uuidString, name: "", paths: []) }
            if let raw = args["path"] {
                let path = normalizedPath(raw)
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else { throw TodoError("invalid_field", "请选择存在的目录。") }
                guard !state.projects.contains(where: { $0.id != project.id && $0.paths.contains(path) }) else { throw TodoError("invalid_field", "目录已绑定到其他项目。") }
                if let old = args["replace-path"] {
                    guard project.paths.contains(old) else { throw TodoError("invalid_field", "待替换路径不存在。") }
                    project.paths.removeAll { $0 == old }
                }
                if !project.paths.contains(path) { project.paths.append(path) }
                if project.name.isEmpty { project.name = URL(fileURLWithPath: path).lastPathComponent }
            } else if !updating { throw TodoError("invalid_field", "缺少 path。") }
            if let name = args["name"] { project.name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard !project.name.isEmpty else { throw TodoError("invalid_field", "项目名称不能为空。") }
            if let i = state.projects.firstIndex(where: { $0.id == project.id }) { project.revision += 1; state.projects[i] = project } else { state.projects.append(project) }
            return ["project": try jsonObject(project)]
        case "context", "list":
            var pid: String?
            var project: Project?
            if command == "context" {
                let cwd = normalizedPath(try required("cwd", args))
                let matches = state.projects.flatMap { p in p.paths.filter { cwd == $0 || cwd.hasPrefix($0 == "/" ? "/" : $0 + "/") }.map { (p, $0.count) } }
                project = matches.max(by: { $0.1 < $1.1 })?.0
                guard let project else { throw TodoError("project_unmatched", "当前目录没有绑定项目；未读取其他项目。") }
                pid = project.id
            } else if let value = args["project"], value != "all" { pid = try projectID(value, state) }
            let limit = Int(args["limit"] ?? "100") ?? -1, offset = Int(args["offset"] ?? "0") ?? -1
            guard (1...500).contains(limit), offset >= 0 else { throw TodoError("invalid_field", "limit 为 1–500，offset 不得为负。") }
            if let status = args["status"], !["todo", "in_progress", "done"].contains(status) { throw TodoError("invalid_field", "状态无效。") }
            let filtered = state.liveTasks.filter { item in
                (command != "context" && (args["project"] == nil || args["project"] == "all") || item.projectID == pid) &&
                (command != "context" || item.status != "done") && (args["status"] == nil || item.status == args["status"])
            }.sorted(by: taskOrder)
            let page = Array(filtered.dropFirst(offset).prefix(limit))
            let tasks: Any
            if command == "context" {
                tasks = page.map { item -> [String: Any] in ["id": item.id, "short_code": item.shortCode as Any? ?? NSNull(), "parent_id": item.parentID as Any? ?? NSNull(), "title": item.title, "status": item.status, "priority": item.priority, "revision": item.revision] }
            } else { tasks = try jsonObject(page) }
            return ["project": try project.map { try jsonObject($0) } ?? NSNull(), "tasks": tasks, "total": filtered.count, "truncated": offset + page.count < filtered.count, "next_offset": offset + page.count < filtered.count ? (offset + page.count) as Any : NSNull()]
        case "get":
            let item = state.tasks[try index(required("id", args), state)]
            return ["task": try jsonObject(item), "ancestors": try jsonObject(state.ancestors(item.id)), "attachments": try state.attachments.filter { $0.taskID == item.id && !$0.deleted }.map { a -> [String: Any] in
                var value = try jsonObject(a) as! [String: Any]; value["path"] = attachmentURL(a).path; return value
            }]
        case "trash": return ["tasks": try jsonObject(state.tasks.filter { $0.deletionID != nil })]
        case "add":
            var item = TodoItem(title: try required("title", args))
            if let parent = args["parent"] {
                let p = state.tasks[try index(parent, state)]
                item.parentID = p.id; item.projectID = p.projectID
                if let value = args["project"], try projectID(value, state) != p.projectID { throw TodoError("invalid_field", "父子任务不能跨项目。") }
                guard state.ancestors(parent).count + 2 <= 10 else { throw TodoError("depth_exceeded", "最多支持十层待办。") }
            } else { item.projectID = try projectID(args["project"], state) }
            item.source = args["source"] ?? "user"
            try applyFields(args, &item)
            if item.status == "done" { item.completedAt = timestamp() }
            let orders = state.children(item.parentID).filter { $0.projectID == item.projectID && ($0.status == "done") == (item.status == "done") }.compactMap(\.sortOrder)
            if let last = orders.max() { item.sortOrder = last + 1 }
            item.shortCode = try state.allocateTaskCode()
            state.tasks.append(item)
            let reopened = item.status == "done" ? [] : reopenAncestors(item.id, &state)
            return ["task": try jsonObject(item), "reopened_ancestors": reopened]
        case "update", "complete", "delete", "restore", "move", "attachment add", "attachment delete", "attachment restore":
            let id = try required("id", args)
            let i = try index(id, state, deleted: command == "restore")
            try checkRevision(state.tasks[i].revision, args)
            var item = state.tasks[i]
            var reopened: [String] = []
            var affected: [String] = [id]
            if command == "update" || command == "complete" {
                var fields = args; if command == "complete" { fields["status"] = "done" }
                try applyFields(fields, &item)
                if item.status == "done" {
                    let unfinished = state.descendants(id).filter { $0.status != "done" }
                    guard unfinished.isEmpty || args["cascade"] == "true" else { throw TodoError("cascade_required", "仍有 \(unfinished.count) 个未完成后代；需明确一并完成。") }
                    for child in unfinished {
                        let k = try index(child.id, state); state.tasks[k].status = "done"; state.tasks[k].completedAt = timestamp(); touch(&state.tasks[k]); affected.append(child.id)
                    }
                    item.completedAt = item.completedAt ?? timestamp()
                } else { item.completedAt = nil }
            } else if command == "move" {
                let branch = state.descendants(id)
                var parent: TodoItem?
                if let value = args["parent"], value != "root" { parent = state.tasks[try index(value, state)] }
                guard parent?.id != id && !branch.contains(where: { $0.id == parent?.id }) else { throw TodoError("cycle_detected", "不能移动到自身或后代。") }
                let destination = try args["project"].map { try projectID($0, state) } ?? (parent?.projectID ?? item.projectID)
                if let parent, parent.projectID != destination { throw TodoError("invalid_field", "父子任务不能跨项目。") }
                let oldDepth = state.ancestors(id).count + 1
                let height = ([oldDepth] + branch.map { state.ancestors($0.id).count + 1 }).max()! - oldDepth + 1
                let parentDepth = parent.map { state.ancestors($0.id).count + 1 } ?? 0
                guard parentDepth + height <= 10 else { throw TodoError("depth_exceeded", "移动后分支超过十层。") }
                item.parentID = parent?.id; item.projectID = destination
                item.sortOrder = nil
                for child in branch { let k = try index(child.id, state); state.tasks[k].projectID = destination; touch(&state.tasks[k]); affected.append(child.id) }
            } else if command == "delete" {
                let deletion = UUID().uuidString
                item.deletionID = deletion; item.shortCode = nil
                for child in state.descendants(id) { let k = try index(child.id, state); state.tasks[k].deletionID = deletion; state.tasks[k].shortCode = nil; touch(&state.tasks[k]); affected.append(child.id) }
            } else if command == "restore" {
                guard let deletion = item.deletionID else { throw TodoError("invalid_field", "任务没有被删除。") }
                if let parent = item.parentID, let p = state.tasks.first(where: { $0.id == parent }), p.deletionID != nil {
                    if p.deletionID == deletion { throw TodoError("invalid_field", "请从回收站恢复分支根任务。") }
                    throw TodoError("invalid_field", "请先恢复父任务。")
                }
                let restoredIDs = state.tasks.filter { $0.deletionID == deletion }.sorted {
                    $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
                }.map(\.id)
                var occupied = Set(state.liveTasks.compactMap(\.shortCode))
                for key in restoredIDs { let k = try index(key, state, deleted: true); state.tasks[k].deletionID = nil; state.tasks[k].shortCode = try state.allocateTaskCode(occupied: &occupied); touch(&state.tasks[k]); affected.append(key) }
                item = state.tasks[i]
                let restoredProject = try item.parentID.map { state.tasks[try index($0, state)].projectID } ?? item.projectID
                for key in restoredIDs {
                    let k = try index(key, state)
                    guard state.ancestors(key).count < 10 else { throw TodoError("depth_exceeded", "恢复后超过十层，请先调整父任务位置。") }
                    state.tasks[k].projectID = restoredProject
                }
                item = state.tasks[i]
            } else if command == "attachment add" {
                let source = URL(fileURLWithPath: try required("path", args)).resolvingSymlinksInPath()
                do {
                    let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                    guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= 100 * 1024 * 1024,
                          let type = UTType(filenameExtension: source.pathExtension), type.conforms(to: .image) || type.conforms(to: .movie) else { throw TodoError("attachment_failed", "仅支持图片和视频，单文件须为 1 B–100 MB。") }
                    let aid = UUID().uuidString
                    let a = Attachment(id: aid, taskID: id, filename: source.lastPathComponent, mediaType: type.identifier, bytes: size, storedName: aid + "." + source.pathExtension.lowercased())
                    let destination = attachmentURL(a)
                    copied = destination
                    try FileManager.default.copyItem(at: source, to: destination)
                    let actualSize = try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    guard actualSize == size else { throw TodoError("attachment_failed", "源文件在复制期间发生变化，请重试。") }
                    let handle = try FileHandle(forWritingTo: destination); try handle.synchronize(); try handle.close()
                    state.attachments.append(a)
                } catch let error as TodoError { throw error }
                catch { throw TodoError("attachment_failed", "附件导入失败：\(error.localizedDescription)") }
            } else {
                let aid = try required("attachment", args)
                guard let k = state.attachments.firstIndex(where: { $0.id == aid && $0.taskID == id }) else { throw TodoError("not_found", "附件不存在。") }
                state.attachments[k].deleted = command == "attachment delete"
            }
            touch(&item); state.tasks[i] = item
            if item.deletionID == nil {
                let open = ([item] + state.descendants(id)).filter { $0.status != "done" }
                for task in open { reopened += reopenAncestors(task.id, &state) }
            }
            return ["task": try jsonObject(state.tasks[i]), "affected_ids": Array(Set(affected)).sorted(), "reopened_ancestors": Array(Set(reopened)).sorted()]
        default: throw TodoError("invalid_field", "未知命令。")
        }
    }
}

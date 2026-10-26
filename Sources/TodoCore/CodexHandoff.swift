import Foundation
import CSQLite

public struct CodexProject: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public var paths: [String]
}

/// An explicitly read-only adapter for the locally verified Codex state_5 schema.
/// Never use Store here: it owns Next One migrations and creates writable storage.
public enum CodexProjects {
    public static func databaseURL(environment: [String: String] = ProcessInfo.processInfo.environment,
                                   home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> URL {
        let root: URL
        if let custom = environment["CODEX_HOME"], !custom.isEmpty {
            guard NSString(string: custom).isAbsolutePath else {
                throw TodoError("codex_storage", "Codex 数据目录必须是绝对路径。")
            }
            root = URL(fileURLWithPath: custom, isDirectory: true)
        } else { root = home.appendingPathComponent(".codex", isDirectory: true) }
        return root.appendingPathComponent("state_5.sqlite")
    }

    public static func read(database: URL) throws -> [CodexProject] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(database.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let db { sqlite3_close(db) }
            throw TodoError("codex_storage", "无法读取 Codex 项目，请确认已安装并打开过 Codex，然后重试。")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 1000)
        func execute(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw TodoError("codex_storage", "Codex 项目暂时无法读取，请重试。")
            }
        }
        try execute("PRAGMA query_only=ON")
        try execute("BEGIN")
        defer { sqlite3_exec(db, "ROLLBACK", nil, nil, nil) }
        // Explicit column selection also verifies the required schema without reading private content.
        var statement: OpaquePointer?
        let query = "SELECT p.id, p.name, r.path FROM projects p LEFT JOIN project_roots r ON r.project_id=p.id ORDER BY p.position, p.id, r.position"
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            throw TodoError("codex_schema", "无法识别此版本的 Codex 项目数据，请更新 Next One。")
        }
        defer { sqlite3_finalize(statement) }
        var projects: [CodexProject] = []
        var indices: [String: Int] = [:]
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { break }
            guard result == SQLITE_ROW else { throw TodoError("codex_storage", "Codex 项目暂时无法读取，请重试。") }
            func column(_ index: Int32) -> String? {
                sqlite3_column_text(statement, index).map { String(cString: $0) }
            }
            guard let id = column(0), !id.isEmpty, let name = column(1), !name.isEmpty else {
                throw TodoError("codex_schema", "无法识别此版本的 Codex 项目数据，请更新 Next One。")
            }
            if indices[id] == nil {
                indices[id] = projects.count
                projects.append(CodexProject(id: id, name: name, paths: []))
            }
            if let path = column(2) {
                guard NSString(string: path).isAbsolutePath else {
                    throw TodoError("codex_schema", "无法识别此版本的 Codex 项目数据，请更新 Next One。")
                }
                let path = normalizedPath(path)
                let i = indices[id]!
                if !projects[i].paths.contains(path) { projects[i].paths.append(path) }
            }
        }
        // Rootless records are not usable local project destinations.
        return projects.filter { !$0.paths.isEmpty }
    }
}

public enum CodexHandoff {
    public static func matching(_ path: String, in projects: [CodexProject]) -> [CodexProject] {
        let path = normalizedPath(path)
        return projects.filter { $0.paths.contains { normalizedPath($0) == path } }
    }

    public static func requireDirectory(_ path: String) throws {
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &directory), directory.boolValue,
              FileManager.default.isReadableFile(atPath: path) else {
            throw TodoError("codex_path", "目录不存在或无法访问，请重新选择。")
        }
    }

    public static func message(item: TodoItem, originPath: String?, targetPath: String,
                               attachments: [(name: String, path: String)], instruction: String) throws -> String {
        guard let code = item.shortCode else { throw TodoError("codex_task", "待办编号不可用，请刷新后重试。") }
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var lines = [code + " " + item.title]
        if !item.description.isEmpty { lines.append(item.description) }
        let original = originPath.map(normalizedPath) ?? normalizedPath(targetPath)
        lines.append("选定的本地路径：" + original)
        if original != normalizedPath(targetPath) { lines.append("会话项目路径：" + normalizedPath(targetPath)) }
        lines += attachments.map { $0.name + " " + $0.path }
        let context = "<neo>\n" + lines.map(escape).joined(separator: "\n") + "\n</neo>"
        return context + (instruction.isEmpty ? "" : "\n\n" + instruction)
    }

    public static func url(message: String, targetPath: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "codex"; components.host = "threads"; components.path = "/new"
        // Percent-encode '+' as well, so form-style decoders cannot silently turn it into a space.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        guard let prompt = message.addingPercentEncoding(withAllowedCharacters: allowed),
              let path = targetPath.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw TodoError("codex_url", "无法准备 Codex 会话，请重试。")
        }
        components.percentEncodedQuery = "prompt=" + prompt + "&path=" + path
        guard let url = components.url else { throw TodoError("codex_url", "无法准备 Codex 会话，请重试。") }
        return url
    }
}

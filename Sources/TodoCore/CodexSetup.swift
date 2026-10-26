import Foundation
import Darwin

/// Explicit, user-authorized setup only. App startup never calls this manager.
public struct CodexSetup {
    let data: URL
    let skills: URL
    let codex: URL
    let fm = FileManager.default
    let start = "<!-- NEXT-ONE:BEGIN -->"
    let end = "<!-- NEXT-ONE:END -->"
    var target: URL { skills.appendingPathComponent("next-one") }
    var receipt: URL { target.appendingPathComponent(".next-one-install.json") }
    var current: URL { data.appendingPathComponent("integration/current") }

    struct Receipt: Codable {
        var dataPath: String
        var rulesPath: String
        var block: String
        var files: [String: String]
        var backupPath: String
    }
    public init(dataDirectory: URL, skillsDirectory: URL? = nil, codexDirectory: URL? = nil) {
        data = dataDirectory.standardizedFileURL
        skills = skillsDirectory ?? fm.homeDirectoryForCurrentUser.appendingPathComponent(".agents/skills")
        codex = codexDirectory ?? URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEX_HOME"] ?? fm.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path)
    }
    func fail(_ text: String) -> TodoError { TodoError("integration_conflict", verbatim: text) }
    func content(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }
    func exists(_ url: URL) -> Bool { fm.fileExists(atPath: url.path) || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil }
    func rejectLink(_ url: URL) throws {
        if (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil { throw fail("Refusing to replace a symbolic link: \(url.path)") }
    }
    func readReceipt() throws -> Receipt {
        try rejectLink(receipt)
        return try JSONDecoder().decode(Receipt.self, from: Data(contentsOf: receipt))
    }
    func validate(_ record: Receipt) throws {
        guard record.dataPath == data.path else { throw fail("This Skill is connected to another data directory. Uninstall its managed connection first.") }
        guard Set(record.files.keys) == ["SKILL.md", "run"] else { throw fail("Incomplete managed file record.") }
        for (name, expected) in record.files {
            guard ["SKILL.md", "run"].contains(name) else { throw fail("Invalid managed file record.") }
            let url = target.appendingPathComponent(name); try rejectLink(url)
            guard try content(url) == expected else { throw fail("Managed file was edited; preserve and reconcile it before setup: \(name)") }
        }
        let rules = URL(fileURLWithPath: record.rulesPath)
        guard rules.deletingLastPathComponent().standardizedFileURL == codex.standardizedFileURL,
              ["AGENTS.md", "AGENTS.override.md"].contains(rules.lastPathComponent) else { throw fail("Unexpected rules location.") }
        try rejectLink(rules)
        let text = try content(rules)
        guard text.components(separatedBy: start).count == 2, text.components(separatedBy: end).count == 2,
              text.contains(record.block) else { throw fail("Managed rules were edited or removed; reconcile them before setup.") }
    }
    func selectedRules() throws -> URL {
        let override = codex.appendingPathComponent("AGENTS.override.md")
        try rejectLink(override)
        if exists(override), !(try content(override)).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return override }
        return codex.appendingPathComponent("AGENTS.md")
    }
    func verifySource() throws {
        guard fm.isExecutableFile(atPath: current.appendingPathComponent("bin/next-one").path),
              fm.isReadableFile(atPath: current.appendingPathComponent("skills/next-one/SKILL.md").path),
              fm.isReadableFile(atPath: current.appendingPathComponent("skills/next-one/references/cli.md").path) else {
            throw fail("Open the complete Next One application once to prepare its integration resources.")
        }
    }
    func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    func templates() -> [String: String] {
        let upstream = current.appendingPathComponent("skills/next-one/SKILL.md").path
        let runner = target.appendingPathComponent("run").path
        let skill = """
        ---
        name: next-one
        description: Use Next One for direct requests beginning with neo, explicit task management, or shared project tasks during local coding work. Read context, record explicit requests, and update verified progress. Quoted neo examples and discussion do not authorize writes.
        ---
        # Next One connection

        At the beginning of each project task, read the current workflow at \(upstream).
        It is maintained by the installed Next One app and may change after an app upgrade.
        For all CLI operations use this exact runner: \(runner)
        It binds the CLI and NEXT_ONE_HOME to this app's data; do not substitute another executable or data store.
        Run it as a quoted absolute path. If resources are unavailable, report that and ask to open Next One; do not guess another database.
        Read USER.md in this directory if it exists; it contains user-owned preferences. Preserve it.
        Never change global rules or this connection during ordinary task work.
        """
        let run = "#!/bin/sh\nexport NEXT_ONE_HOME=\(quote(data.path))\nexec \(quote(current.appendingPathComponent("bin/next-one").path)) \"$@\"\n"
        return ["SKILL.md": skill + "\n", "run": run]
    }
    func rulesBlock() -> String {
        """


        \(start)
        ## Next One shared project tasks
        During local project work, before implementation read \(target.appendingPathComponent("SKILL.md").path) and its current workflow. Use its bound runner to read the current project's tasks first, then record explicit work requests and maintain progress as you work. Reuse matching tasks; preserve user edits. Mark completion only with actual evidence and leave remaining work recorded. Do not turn brainstorming into commitments. Unmatched projects, permissions or tool failures must be reported; never write to a guessed project/database. This is task-time collaboration, not background chat monitoring. User instructions take precedence.
        \(end)
        """ + "\n"
    }
    public func execute(_ operation: String) throws -> [String: Any] {
        // Read-only status must not create configuration, locks, or a task database.
        if operation == "status" {
            guard exists(receipt) else { return ["installed": false, "skill_path": target.path] }
            let record = try readReceipt(); try rejectLink(target); try validate(record); try verifySource()
            return ["installed": true, "skill_path": target.path, "rules_path": record.rulesPath,
                    "data_directory": data.path, "updates": "follow-app-current", "restart_session": true,
                    "active_rules": try selectedRules().path == record.rulesPath]
        }
        guard ["install", "uninstall"].contains(operation) else { throw fail("Use integration install, status, or uninstall.") }
        for path in [data.path, skills.path, codex.path] {
            guard !path.contains("\n"), !path.contains("\r"), !path.contains("`") else { throw fail("Unsupported control characters in setup path.") }
        }
        try rejectLink(skills); try rejectLink(codex); try rejectLink(target)
        if operation == "uninstall", !exists(receipt) { throw fail("No managed installation found; nothing removed.") }
        if operation == "install" { try verifySource() }
        try fm.createDirectory(at: codex, withIntermediateDirectories: true)
        let lockURL = codex.appendingPathComponent(".next-one-setup.lock")
        let fd = open(lockURL.path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw fail("Cannot open setup lock.") }
        defer { flock(fd, LOCK_UN); close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw fail("Another setup is running. Retry later.") }
        let old: Receipt? = exists(receipt) ? try readReceipt() : nil
        if let old { try validate(old) }
        if operation == "install", old == nil, ["SKILL.md", "run"].contains(where: { exists(target.appendingPathComponent($0)) }) { throw fail("An unmanaged next-one Skill exists. Back it up and reconcile custom instructions before installing; nothing overwritten.") }
        let rules = try old.map { URL(fileURLWithPath: $0.rulesPath) } ?? selectedRules()
        try rejectLink(rules)
        if operation == "install", try selectedRules() != rules { throw fail("The active global rules file changed. Uninstall the old connection before reinstalling.") }
        let previousRules = exists(rules) ? try Data(contentsOf: rules) : nil
        let text = previousRules.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard previousRules == nil || String(data: previousRules!, encoding: .utf8) != nil else { throw fail("Global rules are not UTF-8.") }
        if old == nil, text.contains(start) || text.contains(end) { throw fail("An unowned Next One rules block exists. Nothing overwritten.") }
        let block = rulesBlock(), files = templates()
        if operation == "install", let old, old.files == files, old.block == block {
            return ["installed": true, "changed": false, "rules_path": rules.path, "skill_path": target.path]
        }
        let newRules = operation == "uninstall" ? text.replacingOccurrences(of: old!.block, with: "") :
            (old.map { text.replacingOccurrences(of: $0.block, with: block) } ?? text + block)
        guard operation != "install" || newRules.utf8.count <= 24_000 else { throw fail("Global rules are too large for a reliable addition. Keep them below 24 KB before setup.") }
        let backup = data.appendingPathComponent("integration/setup-backups/" + UUID().uuidString)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        if let previousRules { try previousRules.write(to: backup.appendingPathComponent(rules.lastPathComponent)) }
        if exists(target) { try fm.copyItem(at: target, to: backup.appendingPathComponent("next-one")) }
        var previous: [String: Data] = [:]
        for name in ["SKILL.md", "run", ".next-one-install.json"] {
            let url = target.appendingPathComponent(name)
            if exists(url) { previous[name] = try Data(contentsOf: url) }
        }
        guard (exists(rules) ? try Data(contentsOf: rules) : nil) == previousRules else {
            throw fail("Global rules changed during setup. Retry after reviewing them.")
        }
        do {
            if operation == "install" {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                for (name, body) in files { try Data(body.utf8).write(to: target.appendingPathComponent(name), options: .atomic) }
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.appendingPathComponent("run").path)
                try Data(newRules.utf8).write(to: rules, options: .atomic)
                let record = Receipt(dataPath: data.path, rulesPath: rules.path, block: block, files: files, backupPath: backup.path)
                try JSONEncoder().encode(record).write(to: receipt, options: .atomic)
            } else {
                try Data(newRules.utf8).write(to: rules, options: .atomic)
                for name in ["SKILL.md", "run", ".next-one-install.json"] { try fm.removeItem(at: target.appendingPathComponent(name)) }
                if try fm.contentsOfDirectory(atPath: target.path).isEmpty { try fm.removeItem(at: target) }
            }
        } catch {
            // Restore only files owned by this transaction; leave unrelated custom files alone.
            try? fm.createDirectory(at: target, withIntermediateDirectories: true)
            for name in ["SKILL.md", "run", ".next-one-install.json"] {
                let url = target.appendingPathComponent(name)
                if let bytes = previous[name] { try? bytes.write(to: url, options: .atomic) } else { try? fm.removeItem(at: url) }
            }
            if previous["run"] != nil { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.appendingPathComponent("run").path) }
            if let previousRules { try? previousRules.write(to: rules, options: .atomic) } else { try? fm.removeItem(at: rules) }
            if previous.isEmpty, (try? fm.contentsOfDirectory(atPath: target.path).isEmpty) == true {
                try? fm.removeItem(at: target)
            }
            throw error
        }
        return ["installed": operation == "install", "changed": true, "skill_path": target.path, "rules_path": rules.path, "backup_path": backup.path]
    }
}

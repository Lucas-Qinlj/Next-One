import Foundation
import CryptoKit
import Darwin

struct CodexIntegration {
    let skill: URL
    let cli: URL

    /// Bundle-owned resources only. Never search the build machine's source tree.
    static func prepare(dataDirectory: URL, bundleURL: URL = Bundle.main.bundleURL) throws -> CodexIntegration {
        let fm = FileManager.default
        let sourceCLI = bundleURL.appendingPathComponent("Contents/Helpers/todo").resolvingSymlinksInPath()
        let sourceSkill = bundleURL.appendingPathComponent("Contents/Resources/CodexIntegration/todo-ai").resolvingSymlinksInPath()
        guard fm.isExecutableFile(atPath: sourceCLI.path),
              fm.isReadableFile(atPath: sourceSkill.appendingPathComponent("SKILL.md").path),
              fm.isReadableFile(atPath: sourceSkill.appendingPathComponent("references/cli.md").path) else {
            throw IntegrationError("应用包缺少接入文件，请重新构建或安装完整的 Todo-AI 应用。")
        }
        var files: [(String, URL)] = [("bin/todo", sourceCLI)]
        for relative in try fm.subpathsOfDirectory(atPath: sourceSkill.path) {
            let url = sourceSkill.appendingPathComponent(relative)
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                files.append(("skills/todo-ai/" + relative, url))
            }
        }
        files.sort { $0.0 < $1.0 }
        var hash = SHA256()
        for (path, url) in files {
            hash.update(data: Data((path + "\0").utf8))
            hash.update(data: try Data(contentsOf: url))
        }
        let version = hash.finalize().map { String(format: "%02x", $0) }.joined()
        let root = dataDirectory.appendingPathComponent("integration", isDirectory: true)
        let versions = root.appendingPathComponent("versions", isDirectory: true)
        try fm.createDirectory(at: versions, withIntermediateDirectories: true)
        var destination = versions.appendingPathComponent(version, isDirectory: true)
        func valid(_ folder: URL) -> Bool {
            fm.isExecutableFile(atPath: folder.appendingPathComponent("bin/todo").path) && files.allSatisfy {
                fm.contentsEqual(atPath: $0.1.path, andPath: folder.appendingPathComponent($0.0).path)
            }
        }
        let current = root.appendingPathComponent("current")
        let previous = current.resolvingSymlinksInPath()
        if previous.deletingLastPathComponent().resolvingSymlinksInPath() == versions.resolvingSymlinksInPath(),
           previous.lastPathComponent.hasPrefix(version), valid(previous) { destination = previous }
        if !valid(destination) {
            // Retain an old generation even if it was modified; never overwrite a running executable.
            if fm.fileExists(atPath: destination.path) { destination = versions.appendingPathComponent(version + "-" + UUID().uuidString) }
            let staging = versions.appendingPathComponent(".staging-" + UUID().uuidString)
            defer { try? fm.removeItem(at: staging) }
            for (relative, source) in files {
                let target = staging.appendingPathComponent(relative)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source, to: target)
            }
            guard valid(staging) else { throw IntegrationError("接入文件校验失败，请重试。") }
            do { try fm.moveItem(at: staging, to: destination) }
            catch { if !valid(destination) { throw error } }
        }
        if fm.fileExists(atPath: current.path), (try? fm.destinationOfSymbolicLink(atPath: current.path)) == nil {
            throw IntegrationError("接入目录中存在同名文件，已保留原内容；请检查 integration/current。")
        }
        let link = root.appendingPathComponent(".current-" + UUID().uuidString)
        defer { try? fm.removeItem(at: link) }
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "versions/" + destination.lastPathComponent)
        guard rename(link.path, current.path) == 0 else { throw IntegrationError("无法切换接入文件，请检查数据目录的写入权限后重试。") }
        return CodexIntegration(skill: current.appendingPathComponent("skills/todo-ai/SKILL.md"), cli: current.appendingPathComponent("bin/todo"))
    }

    struct IntegrationError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    func installPrompt(dataDirectory: URL) -> String {
        """
        请在这台 Mac 上为我安装并使用 Todo-AI Skill，让你能通过本地接口读取、新增、修改、完成、可恢复删除及恢复我的待办。

        Skill 源文件：\(skill.path)
        CLI：\(cli.path)
        待办数据目录：\(dataDirectory.path)

        我授权本次安装到用户级 ~/.agents/skills/todo-ai。请先读取上述 SKILL.md 和同目录 references/cli.md，再完整复制 Skill 目录（含 references）。已有同名 Skill 时先检查并备份，保留用户自定义内容，不覆盖无关文件；只安装此 Skill，不修改其他全局规则或系统设置。

        在安装后的 SKILL.md 中记录上面的 CLI 和数据目录，要求每次调用显式设置 TODO_AI_HOME 为该数据目录，并对路径做正确 shell 引用；不要使用当前工作项目中的同名程序或其他数据库。若本机无法访问这些文件，说明具体缺失位置，不猜测路径。

        安装后先用该 CLI 的 --help、project list 做只读验证，再按当前工作目录执行 context；未匹配项目时让我选择项目或未分类，不自动绑定。不要为了验证而创建、修改或删除真实待办。

        后续处理明确工作事项时，先读取相关项目待办，复用已有任务；按实际进展局部更新状态，留下未完成事项。修改前读取最新 revision，遵守层级、项目与冲突规则；删除仅使用可恢复删除，不直接操作数据库。不要把探讨当成任务，不虚报完成，也不要承诺后台监听所有聊天。

        完成后告诉我实际安装位置、只读验证结果和如何调用 todo-ai。若当前会话尚未发现 Skill，说明需要刷新或重启 Codex；不要把复制成功当作已验证自动调用。
        """
    }
}

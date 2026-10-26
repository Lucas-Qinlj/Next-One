import Foundation
import TodoCore
import CryptoKit
import Darwin

struct CodexIntegration {
    let skill: URL
    let cli: URL

    /// Bundle-owned resources only. Never search the build machine's source tree.
    static func prepare(dataDirectory: URL, bundleURL: URL = Bundle.main.bundleURL) throws -> CodexIntegration {
        let fm = FileManager.default
        let sourceCLI = bundleURL.appendingPathComponent("Contents/Helpers/next-one").resolvingSymlinksInPath()
        let sourceSkill = bundleURL.appendingPathComponent("Contents/Resources/CodexIntegration/next-one").resolvingSymlinksInPath()
        guard fm.isExecutableFile(atPath: sourceCLI.path),
              fm.isReadableFile(atPath: sourceSkill.appendingPathComponent("SKILL.md").path),
              fm.isReadableFile(atPath: sourceSkill.appendingPathComponent("references/cli.md").path) else {
            throw IntegrationError("应用包缺少接入文件，请重新构建或安装完整的 Next One 应用。")
        }
        // Keep old installed Skill commands working; only the new name is advertised.
        var files: [(String, URL)] = [("bin/next-one", sourceCLI), ("bin/todo", sourceCLI)]
        for relative in try fm.subpathsOfDirectory(atPath: sourceSkill.path) {
            let url = sourceSkill.appendingPathComponent(relative)
            if try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                files.append(("skills/next-one/" + relative, url))
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
            fm.isExecutableFile(atPath: folder.appendingPathComponent("bin/next-one").path) && files.allSatisfy {
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
        return CodexIntegration(skill: current.appendingPathComponent("skills/next-one/SKILL.md"), cli: current.appendingPathComponent("bin/next-one"))
    }

    struct IntegrationError: LocalizedError {
        let text: LocalizedText
        init(_ text: LocalizedText) { self.text = text }
        var errorDescription: String? { text.original }
    }

    func installPrompt(dataDirectory: URL, language: String = "zh-Hans") -> String {
        Localization.text("""
        请在这台 Mac 上安装或检查更新 Next One 接入，让你在明确的项目工作中主动读取待办、记录任务并维护真实进度。

        Skill 源文件：\(skill.path)
        CLI：\(cli.path)
        待办数据目录：\(dataDirectory.path)

        我授权本次安装用户级 ~/.agents/skills/next-one，并在当前 CODEX_HOME（默认 ~/.codex）生效的 AGENTS.override.md 或 AGENTS.md 中添加 Next One 专属持续工作规则；保留其他内容，不修改其他 Agent 配置或系统设置。

        先读取上述 SKILL.md 和 references/cli.md。显式设置 NEXT_ONE_HOME 为上述数据目录，使用上述 CLI 执行 integration status，再执行 integration install。路径必须正确 shell 引用。不手工覆盖已有 Skill 或整份 AGENTS 文件。若提示旧的非托管 Skill、人工修改或不同数据绑定冲突，先检查并向我说明备份与迁移方案，不删除或强行覆盖。

        安装器会保留备份，并建立稳定入口和 run 脚本。应用升级后启动一次，入口跟随 integration/current 读取新版 Skill 与 CLI，无需重新覆盖全局配置；USER.md 保存用户自定义内容。旧会话可能保留旧内容，请用新会话验证。若安装器接口或数据目录改变，再复制新版指令执行安装检查。

        安装后执行 integration status、--help、project list 做只读验证，再按当前工作目录执行 context。未匹配时由我选择项目或未分类，不自动绑定，不为了验证修改真实任务。更新前读取 revision，仅局部更新；失败如实报告。

        从新 Codex 会话进行一次普通开发请求，确认能主动读写项目待办；仅复制/安装成功不等于行为已验证。不要把探讨变成任务，不虚报完成，不承诺后台监听。需要解除接入时使用同一 CLI 的 integration uninstall，仅移除本工具管理且未被修改的入口/规则，保留自定义内容和待办数据。

        完成后报告实际安装位置、规则文件、备份、只读检查和新会话验证结果；未验证的项目明确标注。
        """, language: language)
    }
}

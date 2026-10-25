import Foundation

struct CodexIntegration {
    let skill: URL
    let cli: URL

    static func locate() -> CodexIntegration? {
        var candidates: [URL] = []
        var directory = Bundle.main.bundleURL
        for _ in 0..<6 { candidates.append(directory); directory.deleteLastPathComponent() }
        // Local development fallback, validated before offering a copyable instruction.
        candidates.append(URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())
        for root in candidates {
            let skill = root.appendingPathComponent("Skills/todo-ai/SKILL.md")
            let cli = root.appendingPathComponent(".build/debug/todo")
            if FileManager.default.isReadableFile(atPath: skill.path), FileManager.default.isExecutableFile(atPath: cli.path) {
                return CodexIntegration(skill: skill, cli: cli)
            }
        }
        return nil
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

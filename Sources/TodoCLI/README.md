# codex-integration

`main.swift` 解析命令、读取描述文件/标准输入并调用 TodoCore；只负责传输格式，不复制业务规则。成功 JSON 在 stdout，稳定错误 JSON 在 stderr，失败退出 1。多行文本不使用 shell 拼接。

实际帮助：`swift run todo --help`。完整契约与 Skill 共用 [CLI v1 参考](../../Skills/todo-ai/references/cli.md)。测试：根目录 `python3 scripts/cli-smoke.py`（先 `swift build`），通过真实子进程覆盖正常和失败路径，临时目录自动清理。

Skill 保存在项目内，不自动安装到全局目录，不修改用户 Codex 配置。当前会话可以显式读取 Skill 后调用本机 CLI；新会话发现、安装后的自动选择需要单独验证。

默认数据：debug 为 Application Support/Todo-AI，release 为 Application Support/Todo-AI-Release；TODO_AI_HOME 优先。`--help` 在不打开数据库的情况下显示解析后的目录。应用设置指令指定的 CLI 与数据路径优先，不能把开发 CLI 当作安装版 CLI 使用。

`integration install/status/uninstall` 在构造 Store 前单独分派到 CodexSetup；不写待办数据库。可选 skill-root/codex-home 仅配置安装目标，其他参数拒绝。status 不创建目录，install/uninstall 需要用户明确授权。

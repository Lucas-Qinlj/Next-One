# Todo-AI

本地 macOS 悬浮待办。SwiftUI 清单、AppKit 双窗口、系统 SQLite；应用和 `todo` CLI 共用业务规则。支持项目目录绑定、十层任务、状态/优先级/颜色/截止时间、图片与视频附件、背景透明度和锁定穿透。

当前为本机开发版本，最低目标 macOS 14，已在 macOS 26.5.1 / Apple Silicon 构建和运行。**部分窗口与跨会话验收待实机确认**，见 [验收报告](docs/acceptance/macos-floating-todo.md)。未签名公证分发、未安装全局 Skill、未启用登录启动。

## 启动

需要 Xcode 或对应 Swift 工具链；无第三方运行依赖。在项目根目录执行：

```sh
./scripts/run.sh
```

脚本构建含 CLI 和 Skill 的本地开发应用包并启动；产物在 `.build/TodoAI.app`，不安装到 Applications。单击球展开/收起，拖球移动；右键球可锁定、解锁、打开设置或退出。菜单栏可找回球，应用菜单支持 ⌘B 找回、⌘T 展开/收起、⌘, 设置、⌘Q 退出。三个非锚定角用于缩放，邻角单维度、对角双维度。

详情点“保存更改”，切页、锁定与正常退出前也会保存；冲突会保留草稿，需要重新读取后处理。任务/附件删除可恢复，保留期无限，不自动清理。附件原文件可移动；导入成功的副本留在应用目录中。视频播放能力依赖系统默认媒体应用。

默认数据在 `~/Library/Application Support/Todo-AI`。测试必须隔离：

```sh
TODO_AI_HOME="$PWD/.local/my-test" ./scripts/run.sh
TODO_AI_HOME="$PWD/.local/my-test" .build/debug/todo project list
```

同一数据目录使用一个 UI 实例；CLI 可以并发调用。退出 UI 后再切换不同的 `TODO_AI_HOME`。不要直接编辑数据库；备份时退出 UI 并停止 CLI 写入，复制整个数据目录（包括 SQLite、WAL 和附件）。

## CLI 与 Codex

```sh
swift build
.build/debug/todo --help
.build/debug/todo project bind --path "$PWD" --name Todo-AI
.build/debug/todo context --cwd "$PWD" --json
```

项目内 Skill：[Skills/todo-ai/SKILL.md](Skills/todo-ai/SKILL.md)。完整接口：[CLI v1](Skills/todo-ai/references/cli.md)。可选持续规则：[规则片段](docs/codex-rules-snippet.md)。它们没有自动安装；不会监听全部聊天或提供远程同步。

## 验证

```sh
swift test
python3 scripts/cli-smoke.py
```

前者覆盖共享业务规则、数据库并发和几何；后者通过真实 CLI 子进程验证 JSON、版本冲突、幂等、事务及文本转义。均使用临时数据，不改真实待办。窗口、锁定穿透和 Codex 行为证据单独记录，不能由单元测试替代。

- [产品 Spec](docs/spec/2026-10-24/macos-floating-todo.md)
- [项目状态](PROJECT_STATUS.md)
- [数据核心](Sources/TodoCore/README.md) · [窗口与界面](Sources/TodoApp/README.md) · [本地接口](Sources/TodoCLI/README.md)

## 接入资源与可移植应用包

`./scripts/package-app.sh debug`（或 `release`）生成 `.build/TodoAI.app`，包含应用程序、`Contents/Helpers/todo` 和完整 Skill 资源。本地启动使用 `./scripts/run.sh`；不要只复制裸可执行文件。

应用启动时，接入文件自动准备到当前用户数据目录的 `integration/current/`：`bin/todo` 和 `skills/todo-ai/SKILL.md`（包括 references）。默认数据目录由系统生成，为 `~/Library/Application Support/Todo-AI`；`TODO_AI_HOME` 可用于隔离测试。版本内容先完整校验再原子切换 current 链接，旧版本保留；不会覆盖正在执行的 CLI、真实待办或用户级 Skill。

设置里的复制指令使用上述实际路径，可在源码目录不存在时工作。该能力已在本机移动应用包及模拟用户目录中验证，不代表完成签名、公证、跨架构或另一台 Mac 的正式分发验证。

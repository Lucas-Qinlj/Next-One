<div align="center">

# Next One

安装并让 Coding Agent 发现新版 `next-one` Skill 后，可直接说 **`neo 明天早上八点我要出门寄快递`**。`neo` 帮助 Agent 选择 Next One，再将自然语言解释为新增、查询、修改或完成操作。生活事项默认归入未分类，项目任务沿用明确项目上下文；按用户时区解析日期。它是 Skill 的触发约定，不是终端命令，也不承诺定时通知或后台监听。

**你和 Coding Agent，共同维护一份待办上下文。**

为 Vibe Coding 而生的本地 macOS 悬浮待办，让计划、进度和下一步始终在眼前。

[English](../../README.md) · **简体中文** · [日本語](README.ja.md) · [한국어](README.ko.md)

macOS 14+ · SwiftUI + AppKit · 本地存储 · Codex Skill + CLI

</div>

**置顶伴随开发，透明度按需调整，现成指令复制给 Agent 即可开始接入。**

## 为什么需要 Next One？

和 AI 一起写代码很快，但跟上项目进度并不总是那么容易。

“这个以后再做”埋进了聊天记录；换一个会话，又要重新解释背景；你自己的清单和 Agent 理解的进度逐渐脱节；几个项目来回切换后，很难记清哪些真正完成了，哪些还需要验证。

**Next One 让你与 Coding Agent 共同维护一份持久化、按项目组织的待办。** 你在悬浮应用里查看和编辑，Agent 通过 CLI 读写同一份本地数据。目标、进度、验收条件和剩余工作都留在任务里，下次会话可以直接读取。

它面向独立开发者、个人创作者，以及通过与 Coding Agent 对话来构建软件的人。目前内置 **Codex** 接入；其他本地 Agent 可以使用公开的 CLI 接口，但尚未验证专用集成。

## 界面预览

<table>
<tr><th align="left">工作进度，随时可见</th><th align="left">上下文，留在任务里</th></tr>
<tr>
<td width="50%"><img src="../assets/screenshots/zh-CN/task-list.jpg" alt="真实悬浮清单：项目分组、分层待办、完成进度和优先级" width="480"></td>
<td width="50%"><img src="../assets/screenshots/zh-CN/task-detail.jpg" alt="真实任务详情：目标、已完成工作、下一步、状态和子任务" width="480"></td>
</tr>
</table>

截图来自实际运行的 macOS 应用，使用虚构演示任务。应用支持简体中文、英文、日文和韩文。在设置顶部选择语言或跟随系统，即时生效并记住选择；待办和项目内容保持原文。

## 主要功能与亮点

| 功能 | 带来的价值 |
| --- | --- |
| **人与 Agent 共用上下文** | 应用和 CLI 读写同一份待办。Agent 的更新会显示在运行中的应用里；应用关闭时 CLI 仍可工作。 |
| **按项目接续工作** | 绑定项目文件夹，根据工作目录读取对应任务；同一项目的其他 worktree 可显式追加绑定。 |
| **置顶伴随开发** | 让清单留在编辑器或 Agent 对话旁，查看下一步不用反复切换待办应用；可移动、缩放，也可收起为悬浮球。 |
| **透明度自由调整** | 背景不透明度支持 30%–100%，减少面板的视觉遮挡，文字和悬浮球仍保持清晰。 |
| **复制即用的接入指令** | 设置里一键复制当前语言的 Codex 安装指令，自动带上实际 Skill、CLI 和数据路径，无需自己拼接接入提示词。 |
| **任务承载完整背景** | 最多十层子任务，支持描述、状态、优先级、颜色及截止日期或时间。 |
| **灵活整理** | 折叠项目组，拖动任务与项目排序，移动整条分支，将未分类待办合并成项目。 |
| **自动保存与冲突保护** | 停止编辑后自动保存；不同字段的修改可以合并，同字段冲突保留草稿并请求处理。 |
| **参考资料与恢复** | 图片和视频保存为本地托管副本，单文件最大 100 MB；删除的任务和附件可以恢复。 |
| **本地优先** | SwiftUI、AppKit 与系统 SQLite，无需 Next One 账号、云端后端或额外 AI API Key。 |

锁定模式让面板忽略鼠标输入，悬浮球仍可用于解锁。部分跨应用与桌面组合还需要人工验证，见下方“当前状态与限制”。

## 少切窗口，少配置，把注意力留给开发

**待办置顶，下一步随时可见。** 点击图钉，让清单显示在当前桌面的普通窗口之上，写代码、查看 Agent 回复时都能随手看进度。需要更多空间时收起成悬浮球，不必来回寻找另一个待办窗口。

**透明度按需调整，保留清晰文字。** 在设置里将**背景不透明度调为 30%–100%**，让面板更融入工作区。透明度只作用于背景，文字和悬浮球保持清晰；置顶与透明度可以分别调整。

**现成指令，一键复制给 Agent。** 打开**设置 → Codex 接入**，点击复制图标，把完整指令粘贴到本机 Codex 对话中发送。应用已准备好实际路径、安装步骤、保留已有 Skill 自定义内容的要求和只读验证方式，省去自己查路径、拼指令的过程。指令跟随当前界面语言；发送后才由 Codex 执行安装，单纯复制不会安装。当前内置指令面向 Codex，其他 Coding Agent 可通过公开的本地 CLI 接入。

<p align="center"><img src="../assets/screenshots/zh-CN/settings.jpg" alt="中文设置：语言切换、背景不透明度滑块、置顶按钮和可复制的 Codex 安装指令" width="480"></p>

## 你与 Agent 如何一起工作

1. **记录目标。** 创建项目、绑定目录，写下目标、约束和验收条件。
2. **带着上下文开工。** 让 Codex 先读取当前项目未完成的任务。
3. **共同维护进度。** 你在应用里调整优先级和备注，Agent 通过 CLI 记录真实进展。
4. **留下可接续的交接。** 把完成结果与待验证事项写回任务。后续本机会话可以读取同一份清单，不必从聊天中重新整理。

完成接入后，可以这样说：

> 先读取当前项目的 Next One 待办，继续开发新用户引导流程。把明确的后续工作记成子任务，根据实际验证结果更新进度，保留我已有的备注。

```text
你 ───────── macOS 应用 ────┐
                           ├── 共享业务校验 ── 本地待办与附件
Coding Agent ─ Skill / CLI ─┘
```

这是明确指令驱动的协作：Next One 不监听全部聊天，不在后台运行 Agent，也不自动同步远程环境。

## 快速开始

### 从源码构建并运行

需要 **macOS 14 或更高版本**、**Swift 6.0+ 工具链**（例如兼容的 Xcode）以及打包脚本使用的 Python 3。没有第三方运行依赖。

```sh
git clone https://github.com/Lucas-Qinlj/Next-One.git
cd Next-One
./scripts/run.sh
```

脚本构建并启动 `.build/Next One.app`，包含 CLI 与 Skill 资源，不安装到 Applications。这是本地开发构建，尚非签名、公证后的分发版。

- 单击悬浮球展开或收起，拖动球移动窗口。
- 点击 **+** 新建任务，点击任务标题编辑详情，修改自动保存。
- 在 **设置** 中绑定项目文件夹，并找到 **Codex 接入**。
- 右键球可以锁定、解锁或退出；菜单栏入口可以找回悬浮球。
- 快捷键：`⌘B` 找回球、`⌘T` 展开/收起、`⌘,` 设置、`⌘Q` 退出。

### 接入 Codex

1. 启动 Next One，打开 **设置 → Codex 接入**。
2. 复制安装指令，发送到**同一台 Mac 上的本地 Codex 会话**。指令要求该会话安装应用携带的 Skill，保留已有自定义内容，并通过只读命令验证 CLI。
3. 绑定项目目录后，让 Codex 读取项目的 Next One 上下文；额外 worktree 需要显式绑定。

仅复制指令不会安装任何内容。应用启动只会在自身数据目录准备接入资源，不修改全局 Skill 或 Codex 配置。安装后的自动发现仍需在新的目标会话中验证。

详细说明：[内置 Skill](../../Skills/next-one/SKILL.md) · [CLI 接口](../../Skills/next-one/references/cli.md) · [可选持续规则](../codex-rules-snippet.md)。这些详细参考文档当前以中文提供。

### 直接使用 CLI

构建后在仓库根目录执行：

```sh
.build/debug/todo --help
.build/debug/todo project bind --path "$PWD" --name "Next One"
.build/debug/todo context --cwd "$PWD" --json
```

绑定命令为当前仓库目录创建或关联项目；绑定其他项目时改用其目录。命令返回结构化 JSON，失败返回明确错误码和非零退出状态。

更新需要任务最新的 `revision`，创建支持稳定请求键以避免重试产生重复任务。两种入口遵守同一套层级、项目与状态规则；Agent 应使用 CLI，不直接编辑数据库。

## 数据与隐私

- Release 安装版及其 CLI 使用 `~/Library/Application Support/Next-One-Release`；debug 开发版使用 `~/Library/Application Support/Next-One`。待办、附件、语言、窗口设置和接入资源全部独立。安装版自身目录不存在时为空清单，后续升级保留自身数据，不导入或删除开发版数据。
- 从旧的共用数据库安装包升级后，请从新版设置复制 Codex 接入指令重新接入。已有全局 Skill 不会自动改写，应使用新指令中的 CLI/数据路径。`NEXT_ONE_HOME` 可显式覆盖两种默认目录。
- 附件导入时复制到托管目录，原文件移动不会影响副本；视频播放依赖系统默认媒体应用。
- 已删除的任务和附件可恢复，不自动清空回收站。
- Next One 不自动上传待办或附件。你明确让 Coding Agent 读取的内容会进入该 Agent 的上下文，并遵循其数据处理方式。
- 备份前退出 UI 并停止 CLI 写入，再复制完整数据目录，包括 SQLite/WAL 文件和附件。

演示或测试使用隔离目录，应用与 CLI 必须设置**相同的** `NEXT_ONE_HOME`：

```sh
NEXT_ONE_HOME="$PWD/.local/demo" ./scripts/run.sh
# 在另一个终端中，进入同一仓库后执行：
NEXT_ONE_HOME="$PWD/.local/demo" .build/debug/todo project list
```

同一数据目录只运行一个 UI 实例；CLI 可并发调用。

## 开发

```sh
swift build
swift test
python3 scripts/cli-smoke.py
python3 scripts/drag-cli-smoke.py
./scripts/package-app.sh release
```

最后一条命令生成优化后的本地应用包 `.build/Next One.app`，不会签名、公证、安装或发布。移动时保留完整应用包及其中的 CLI、Skill 资源。

| 模块 | 职责 |
| --- | --- |
| [TodoCore](../../Sources/TodoCore/README.md) | 持久化、事务、任务规则与冲突校验 |
| [TodoApp](../../Sources/TodoApp/README.md) | 悬浮窗口、任务界面与本地接入资源准备 |
| [TodoCLI](../../Sources/TodoCLI/README.md) | 面向 Agent 和脚本的结构化接口 |
| [Skills/next-one](../../Skills/next-one/SKILL.md) | Codex 读取和更新待办的约定 |

本机试装可执行 `./scripts/package-dmg.sh`，生成可拖入 Applications 的 DMG 和 SHA-256 校验文件，位于 `.local/releases/`。详见[本机安装说明](../distribution/local-install.md)。试装包尚未进行 Developer ID 签名或 Apple 公证。

## 当前状态与限制

原生应用和 CLI 已实现，并在 Apple Silicon 上构建运行。目前仍是早期本地开发版本，尚未通过全部验收场景。

- 签名公证下载包、跨机器分发及跨架构验证尚未完成。
- 背后应用实际接收穿透输入、多显示器变化、Spaces、全屏与 Stage Manager 尚未完成全面验证。
- 部分媒体交互及新会话发现 Skill 仍需端到端检查。
- 不提供云同步、多人工作区或远程 Agent 自动访问本机数据的保证。
- `docs/` 下的像素鱼缸实验是独立原型，不是原生应用已有功能。

实际证据及剩余工作见[项目状态](../../PROJECT_STATUS.md)、[验收报告](../acceptance/macos-floating-todo.md)与[产品 Spec](../spec/2026-10-24/macos-floating-todo.md)。

## 参与贡献

欢迎提交问题复现、文档改进和范围清晰的修改。反馈问题时提供 macOS 版本、构建步骤、预期与实际结果，使用演示数据，并移除私人待办、路径和凭据。

修改前阅读 [AGENTS.md](../../AGENTS.md) 和相关 Spec。保持产品面向单人、本机以及人与 Coding Agent 协作的简单方向；行为变化按需验证相关测试和真实 macOS 交互。

## 许可证

许可证尚未选定，仓库目前没有 `LICENSE` 文件。正式以开源软件发布前，需要补充明确的开源许可证。

Next One 默认使用 `Next-One` / `Next-One-Release` 路径。同渠道旧目录存在且新路径不存在时，新路径链接到原存储，保留任务、附件和偏好，不复制或合并数据；已有新目录优先。`NEXT_ONE_HOME` 优先于兼容的旧变量 `TODO_AI_HOME`。Skill 已更名 `next-one`，需要时从新版设置复制指令安装。

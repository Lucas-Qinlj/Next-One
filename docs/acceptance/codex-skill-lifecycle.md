# Codex 接入生命周期验收

日期：2026-10-26。范围见[Spec](../spec/2026-10-26/codex-skill-lifecycle.md)。仅本机隔离验收，不代表所有 Agent 宿主、模型和用户配置均已验证。

## 自动与原生检查

- debug/release 全量 XCTest 各 35 项通过，包含 6 项 CodexSetupTests：备份、重复安装、应用资源切换、固定 runner、用户规则/USER.md 保留、卸载后重装、编辑冲突、不受管理的旧 Skill、不同数据连接、override 优先和变化、缺资源、只读 status、symlink 与未拥有规则块。
- 真实 CLI smoke 通过；新增 integration 命令不创建待办数据库，使用统一 JSON/非零失败协议。
- Skill quick_validate 通过；四语言资源键、插值和安装/更新指令测试通过。
- 原生设置确认“复制 Codex 安装/更新指令”、持续规则授权、状态/安装/卸载接口和正确数据路径。仅隔离应用，未安装目标机器的真实全局 Skill。

## 三个真实 Codex 新会话

环境：ChatGPT 应用自带 Codex CLI `0.164.0-alpha.11.1`，沿用用户模型 GPT-6 Astra / medium。独立 CODEX_HOME 配置、独立测试 Git 项目、独立 Todo 数据目录。生成的全局 AGENTS 规则位于测试 profile，Skill 用安装器的 `--skill-root` 放在测试项目 `.agents/skills`，由 Codex 原生项目 Skill 发现机制加载；没有修改真实用户级 `~/.agents/skills` 或全局 AGENTS。使用现有 ChatGPT 登录，验收结束移除临时认证文件链接。

因此验证的是安装器生成的规则/Skill 在真实新会话中的执行效果，不是声称已在用户真实全局配置中启用；实际用户环境安装后仍需验证。

| 会话 | 请求（不提 Todo-AI） | 实际结果 |
| --- | --- | --- |
| `01a176a4-10a2-73d0-865f-6eab7195ea2c` | 实现 CommonJS slugify、编写并运行 Node 内置测试，Unicode 留作后续 | 先读 context；创建当前任务与独立延期任务；实际实现并通过 7 项测试后完成当前任务，延期任务保持 todo。5 条任务相关命令成功 |
| `01a176a5-ae99-7960-8c3a-eae0fd0406d0` | 阅读项目、重跑测试、说明已完成和剩余事项，不改代码 | 读取已有任务；创建本次独立审核事项并完成，没有重复创建原实现/延期任务；7 项测试通过。5 条任务相关命令成功 |
| `01a176a8-04a0-7110-92cf-5a09c6497178` | 纯讨论 Unicode 规范化取舍，尚未决定实施，不作承诺 | 读取 context，给出解释，无 add/update/complete；前后任务快照完全一致。1 条任务相关命令成功 |

已核对 JSONL 中真实 CLI 调用及退出码、磁盘代码/测试、最终 Store 数据，不仅采用模型最后回答。最终有 2 项完成、1 项延期，UI 显示一致。原始本地证据保留于执行 worktree 的 `.local/e2e/`，不提交真实认证、日志或数据库。

初次使用系统独立 CLI 0.144.1 时，服务端明确拒绝 GPT-6 Astra，提示升级 CLI；没有降级模型，改用本机已安装的较新内置 CLI 后通过。

## 应用更新与解除接入

- 第一次实际应用启动准备 current → CLI 安装 → 完成前两个会话 → 启动包含更新代码/资源的应用副本。
- 核对 current 实际目标版本发生变化；测试 profile 的 AGENTS、安装入口 SKILL.md、run 和 USER.md SHA-256 均未变化。新版 CLI 可通过旧 runner 使用，第三个新会话读到当前资源且保持用户偏好。
- 真实 `integration uninstall` 成功，移除自己管理的区块/入口文件，保留 USER.md 和任务数据；测试 profile 的原全局规则内容恢复。验收应用已退出。

## 限制

- 仅真实 Codex CLI 的代表性任务；未逐一验证其他 Coding Agent、桌面会话自动发现、所有权限设置或全部语言组合的行为。
- 规则会受用户指令、项目级覆盖、模型行为、权限和 Skill 启停影响。安装与更新不是聊天监听器，不能保证每一轮都记录。
- 旧会话可能已经读入旧内容，更新后应新开会话。入口协议变化、数据目录更换或人工修改冲突需要重新执行设置指令并处理，不自动覆盖用户文件。

## 最终安装包检查

0.1.0 build 4：`Todo-AI-0.1.0-local-managed-skill-arm64-4600a54.dmg`。已生成并通过 CRC/SHA-256；从最终映像复制的 release 应用以隔离目录启动，实际生成的 CLI 完成 status → install → status → 幂等 install → uninstall，全流程成功，无真实配置变更。四语资源、图标、完整 Skill 和 Applications 链接检查通过。产物另复制到主仓库忽略的 `.local/releases/` 供用户试装，文件哈希一致；最终验收应用已退出。

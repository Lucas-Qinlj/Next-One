# Codex Skill 安装、持续规则与更新

- 日期：2026-10-26
- 状态：已实现，自动测试及代表性隔离 Codex CLI 新会话验收通过
- 来源：用户明确要求补齐持续规则安装、新会话验证，并提供 Skill 更新指令或自动更新机制。
- 目标：本机 Codex 在明确项目工作中主动读取/维护 Next One；应用升级后 Skill 与 CLI 可跟随更新，不覆盖用户配置。

## 范围与默认值

1. 内置 CLI 提供 integration install/status/uninstall。仅这些显式操作写入用户级 Skill 与 Codex 工作规则；应用启动不写全局配置。
2. 首次安装生成稳定的 next-one 入口 SKILL.md 和绑定当前数据目录的 run 脚本。入口每次任务读取 integration/current 内最新上游 Skill。用户自定义内容放入口目录的 USER.md，不由软件更新覆盖。
3. 在 CODEX_HOME（默认 ~/.codex）实际生效的 AGENTS.override.md（非空）或 AGENTS.md 中维护带边界标记的短规则：开始读取，明确工作才记录，进度按实际结果更新，未匹配不跨项目写。保留文件其余内容。
4. 安装操作先校验目标、备份并记录自己拥有的内容；已有不受管理的同名 Skill、改动过的管理文件/区块、路径绑定冲突不静默覆盖。重复安装同配置幂等；卸载只移除本工具拥有且未被修改的文件/规则，保留 USER.md 及其他文件。
5. 更新软件并启动后复用现有 current 原子切换，上游 Skill、CLI 和持续规则正文从该稳定位置读取。无需每次更新全局文件。旧会话可能保留已读内容，新会话重新读取；不承诺后台监听、不保证绝不遗漏。
6. 四语安装/更新指令明确授权范围、数据路径、保留自定义内容及只读验证；提示用户启动新会话验证。其他 Agent 仍只承诺 CLI 可接入，不改其配置。
7. 本轮使用独立 worktree，不修改现用软件/真实全局配置。用隔离 Codex profile 和一次性项目测试；用户授权补齐“新会话验证”覆盖有限真实 Codex CLI 验收调用，不将其作为委派开发或创建 sidebar chat。

## 接口与验收

- CLI integration 命令不初始化待办数据库；数据来源为 Store.defaultDirectory。测试可显式 --skill-root 与 --codex-home 指向隔离目录。
- 安装校验上游 Skill、references 与可执行 CLI；生成 shell runner 固定 NEXT_ONE_HOME 和 CLI，安全引用路径。
- XCTest：首次/重复安装、其他规则和 USER.md 保留、修改冲突/拒绝、卸载、override 优先、路径含空格、损坏资源、升级切换不重写全局入口、无数据库副作用。
- 真实 CLI：安装/状态/卸载 JSON 与非零错误；四语指令和应用设置实际检查。
- 新 Codex 会话：普通开发请求（不提示使用 Next One）触发读待办、新建/开始/完成；第二会话读既有任务不重复；讨论不创建承诺任务。检查实际 CLI 事件和数据结果，不能只看模型最后声称。
- 构建/测试：swift test；python3 scripts/cli-smoke.py；打包脚本。核心 Swift/Foundation/CryptoKit，无新运行依赖。不会自动发布或修改其他全局设置。

## 计划

先实现稳定入口与规则管理 → 修改 Skill/四语安装指令 → 测试安全与升级 → 隔离 Codex 新会话实测 → 文档与安装包交付。

## 结果与限制

debug/release 各 35 项测试、CLI smoke、Skill 校验、原生设置检查通过。三个真实新会话分别验证普通开发主动记录/完成、后续会话接续、纯讨论不写；实际应用升级后 current 改变而全局测试入口/规则/USER.md 哈希不变。见[验收报告](../../acceptance/codex-skill-lifecycle.md)。

未写入用户真实全局 Skill/规则，未自动发布或替换现用应用。正式安装由用户复制新指令授权执行；仅本机隔离 Codex CLI 的代表性场景通过，不声称所有 Agent 或会话都必定触发。

## Merge adaptation (2026-10-26)

Merged into current main with Next One branding, next-one Skill/CLI paths, NEXT_ONE_HOME, neo routing, and current archive/short-code rules preserved. Historical acceptance above describes the original branch; no new Codex chat was launched during this merge. Automated setup/localization tests and isolated CLI install/status/uninstall are rechecked. No real global installation is performed.

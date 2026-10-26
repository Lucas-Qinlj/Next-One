# 安装版与开发版数据隔离

- 日期：2026-10-26
- 状态：已实现并验证，已生成本机试装 DMG；未推送/替换现用应用
- 来源：用户明确要求正式发布版本的数据库与开发版独立。
- 目标：安装新版 Release 后不再默认读取开发版任务；保留现有所有数据。

## 范围与规则

- Swift Package debug 构建默认使用 Application Support/Todo-AI，release 构建默认使用 Application Support/Todo-AI-Release；编译期标识放在共享 TodoCore，应用与 CLI 一致，复制到 integration 后仍保持选择。
- TODO_AI_HOME 继续拥有最高优先级，用于显式接入与隔离测试；不根据当前目录、可执行文件路径或是否存在旧库猜测归属。
- 独立整个数据目录，包括数据库/WAL、附件、语言、窗口设置和 integration。无迁移、无复制、无删除；安装版目录不存在时自然创建空清单，存在时沿用自身数据。
- 安装版 bundle ID 与开发版区分，后续安装版更新保持稳定。包内 CLI、设置生成的安装指令必须与安装版数据一致；已安装的旧全局 Skill 不自动改写，用户需要从新版设置复制新接入指令。
- 不修改业务 schema，不改变任务逻辑，不签名公证或推送发布，不替换用户正在运行的应用。

## 实施与验收

1. TodoCore 编译配置选择默认目录；应用和 CLI 同源。原生 API 保持不变，CLI 帮助说明自身默认目录。
2. 打包配置隔离 bundle ID，更新安装说明和四语 README 中旧“沿用开发数据”的表述。
3. `swift test` 与 `swift test -c release` 验证配置、Store 读写隔离；真实 debug/release CLI 子进程核对默认目录（只读计算，不读取真实数据库）及 TODO_AI_HOME 覆盖。
4. 制作新 DMG，校验图标、资源、CLI；从包复制的安装版在隔离环境启动，设置指令显示实际隔离数据目录。不得为验证创建或清空用户正式任务。

普通工程细节采用上述最简默认值，用户本轮实施授权覆盖；无阻塞决策。源码职责：Package.swift/Store 默认目录，CLI 帮助，scripts 打包，Tests 针对性测试。沿用 Swift 四空格风格与现有 XCTest。仅本地提交本轮内容。

## 验证结果

- debug/release 全量测试各 29 项通过（各新增 2 项目录选择/隔离测试）。实际 debug/release CLI --help 解析路径分别为 Todo-AI / Todo-AI-Release，不打开真实数据库；临时目录覆盖与空库查询通过。
- release DMG 校验通过，bundle ID 为 local.todo-ai.release，图标、四语资源与 Skill 完整。应用复制到含空格的隔离安装目录，从 `/` 启动，实际 UI 空清单、项目绑定为空；设置显示隔离数据内正确的 Skill/CLI 路径。
- 移到 integration/current 后的 CLI 在无覆盖时仍解析 Todo-AI-Release；显式覆盖时查询隔离空库成功。没有修改旧任务或全局 Skill，验收实例已退出。
- DMG：`.local/releases/Todo-AI-0.1.0-local-isolated-arm64-3086de3.dmg`，build 3；未签名/公证、未正式发布。本次是小范围默认路径修正，在现有工作目录实施，没有合并其他 worktree。

# Next One 接入路径统一

- 日期：2026-10-26
- 状态：实现、隔离测试与本机安装验证完成
- 需求来源：用户截图指出数据与 Skill 路径仍含 Todo-AI，要求改为 Next-One。

## 目标与范围

默认数据目录改为 Next-One（debug）和 Next-One-Release（release），Skill 名称及目录为 next-one，导出的 CLI 为 bin/next-one，主环境变量 NEXT_ONE_HOME。同步四语指令、打包、测试与当前接口文档。Swift 内部模块和 bundle ID 保持稳定，本地源码目录和历史证据不批量改名；不自动安装或覆盖全局 Skill。

## 数据规则与接口边界

解析路径无磁盘副作用。首次打开默认存储时，若新目录不存在而同渠道旧目录存在，则以新目录符号链接到旧目录，保留同一份数据库、附件和偏好，避免旧进程/CLI 与新版本写入两份数据。已有新目录不覆盖、不合并；失效链接或旧路径不是目录时明确报错。显式目录不触发兼容链接。NEXT_ONE_HOME 优先于兼容的 TODO_AI_HOME；新安装提示仅使用新名称。开发与 release 始终隔离。语言设置须在存储准备完成后加载。

## 实施与验收

1. 共享 Store 路径选择和兼容链接；验证旧数据及附件/偏好不变、重复调用、已有新目录、显式目录、环境变量优先级。
2. 重命名项目内 Skill，更新 CLI 包内名称和接入生成，四语键值同步；用 integration/localization 测试验证。
3. debug/release 构建与测试，隔离原生设置检查新路径，真实 CLI 调用，重新生成并校验 DMG。

命令：`swift test`、`swift test -c release`、`./scripts/package-dmg.sh`。原生验证使用 NEXT_ONE_HOME 隔离数据。无新增依赖、不改数据库 schema，不用真实任务作测试。

- 设置安装指令中的默认路径使用 Next-One[-Release]/integration/current/skills/next-one/SKILL.md 与 bin/next-one。
- 新安装提示、Skill 调用名及环境变量无 todo-ai/TODO_AI_HOME；旧目录作为内部兼容目标保留，不谎称物理搬迁。
- 旧数据不复制、不丢失、不跨渠道混用；新目录和自定义目录不被覆盖。
- 最新安装包包含正确资源并可独立启动。

## 未决事项与变更记录

无未决事项。已有全局 Skill 的自定义内容不自动修改，用户可从新版设置复制新安装指令进行安装。

- 2026-10-26：本规则取代产品初次更名时保留全部接入路径的决定。
- 兼容补充：导出版本保留隐藏的 bin/todo 入口供旧全局 Skill 使用，新提示仅展示 bin/next-one。
- 验证：debug 全量 30 项与新增目录/本地化/接入检查通过；release 全量 32 项、真实 CLI smoke、Skill 校验通过。隔离及现用 release 设置确认新路径，新旧目录为同一存储。build 4 安装包 CRC/SHA-256、资源与 CLI 检查通过，包内主程序/CLI 与已验证运行版本一致。未修改已有全局 Skill。

# 可移植的本机 Codex 接入资源

- 日期：2026-10-25
- 状态：2026-10-26 本地实现与可移植性验证完成
- 需求来源：安装指令不应引用开发者源码路径；不同电脑/用户名安装后，接入文件应位于实际用户数据目录。
- 目标：应用包独立携带 CLI 与完整 Skill，启动时准备到当前 Store.directory/integration，复制指令只引用该目录。
- 非目标：签名、公证、发布安装包、自动安装全局 Skill、迁移数据库、自动更新服务。

## 路径和更新规则

- 包内 CLI 位于 Contents/Helpers/todo，Skill 位于 Contents/Resources/CodexIntegration/todo-ai。
- 当前用户数据目录仍由系统 Application Support API 生成；测试遵守 TODO_AI_HOME。接入资源为 integration/versions/<内容摘要>/bin/todo 与 skills/todo-ai，稳定入口 integration/current。
- 完整复制并校验后原子切换 current 符号链接；更新不覆盖正在运行的二进制，不删除旧版本或用户级 Skill，不写真实任务。
- 同内容重复启动复用完整版本；缓存损坏时重新准备。源资源缺失/无执行权限/写入失败时清晰提示，不回退源码路径，不显示失效复制按钮。
- 普通启动准备资源失败不能阻止待办应用打开；设置提供重试。源码直接 swift run 不保证资源完整，使用打包启动脚本。
- 复制指令仍明确授权接收会话安装用户级 Skill、保护既有内容，并记录准确数据目录。新安装/新版本的应用不自动改变已安装全局 Skill。

## 实施与验收

1. 可重复的本地应用打包脚本（debug/release）包含 CLI/Skill；run.sh 使用此脚本。
2. 以 bundle URL 读取资源，按当前 Store.directory 准备；删除 #filePath 与源码祖先搜索。
3. 测试含空格/不同用户模拟路径、移动应用、重复启动、资源更新/损坏、缺失资源、数据保持；复制提示不包含源码目录。
4. 在隔离目录运行真正打包的应用，检查设置路径和复制后 CLI --help/project list。不修改系统用户名或全局设置，不冒充跨机器/签名分发验收。

无阻断决策；以既有本地接入指令为基础修复可移植性。

## 验证结果（2026-10-26）

- IntegrationTests 两项通过：模拟其他用户名/空格路径、应用包移动、重复启动复用、版本升级、损坏恢复、资源缺失不破坏旧入口、保留同名用户目录及无关文件。测试中修复了 /var 与 /private/var 路径别名导致的相对资源路径错误，改用文件管理器返回的相对路径。
- 真正打包的应用复制至临时 Installed Apps/Todo AI.app，从 `/` 启动，TODO_AI_HOME 指向临时 Users/Guest Space/Library/Application Support/Todo-AI。原生设置显示新目录下的 Skill/CLI；复制的完整 references 与真实 CLI 内容一致，已从生成的 current/bin/todo 成功调用 --help 和 project list，原数据标记保留。
- 此为本机模拟安装路径与实际可执行文件检查，未改变系统用户名、未安装全局 Skill，未做签名公证、跨机器/架构分发验证。

- 全量 swift test 22 项通过。回归时发现旧拖动测试误以为同秒任务一定按创建调用顺序排序，修正夹具为明确的优先级基线，未改排序业务逻辑。最终本机开发版已重新打包启动，设置显示真实用户数据目录下的接入资源。

## 后续渠道隔离（2026-10-26）

用户后续要求安装版独立数据，见[隔离 Spec](../2026-10-26/release-data-isolation.md)。release 默认 Todo-AI-Release、debug 保留 Todo-AI；本页“数据目录不变”描述原始实施范围，后续以隔离 Spec 为准。integration/current 仍位于实际 Store.directory 内，复制出的 CLI 保持对应编译渠道，TODO_AI_HOME 显式覆盖。

## 后续安装与持续规则（2026-10-26）

见[接入生命周期 Spec](../2026-10-26/codex-skill-lifecycle.md)：首次显式安装稳定入口和专属全局规则，后续沿用本页 current 原子切换读取新版 Skill/CLI，不在应用启动时改写全局配置。旧复制式安装指令已被带备份/冲突检查的安装器替代。

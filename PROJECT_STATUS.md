# Next One 项目状态

- 更新日期：2026-10-27
- 当前阶段：首版本地实现完成，自动验证与部分原生交互通过；**尚未全部验收**
- 协作规范：[AGENTS.md](AGENTS.md)
- 产品 Spec：[macOS 悬浮待办与 Codex 共享上下文](docs/spec/2026-10-24/macos-floating-todo.md)
- 证据与限制：[AC01–AC15 验收报告](docs/acceptance/macos-floating-todo.md)
- 使用方法：[README](README.md)

## 2026-10-27 03:33 | codex-composer-focus-restore | C3 跳转后自动恢复清单试验

- 状态：实现、9 项针对性测试及 release 打包通过；真实焦点待用户测试。
- 需求与范围：用户要求打开并预填后自动重开浮窗；本轮先做可测试实现，不自动发送或增加权限。
- 改动：URL 打开返回成功后等待 800 ms，非激活、非 key 恢复原先展开的清单；等待期间手动切换或新交接取消恢复。失败恢复草稿不变。
- 验证与证据：9 项 CodexHandoffTests 通过，新增自动恢复可见且非 key、输入能力恢复、手动操作取消延迟恢复；release 构建、资源及 CLI --help 校验通过。验收包 `.local/releases/c3-restore-20261027/Next One.app`，日志在同目录；主程序 SHA-256 `a7874b927fabb576f24331fdc5d40e5af192c0fa8ead01020e841f29a3ea7a1d`。未正式签名公证。
- 未完成/阻塞/下一步：深链接无预填完成回执，800 ms 为试验默认值，不代表已确认预填完成；真实 Codex 焦点和冷启动需用户验收。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[UI 模块](Sources/TodoApp/README.md)；main 小修复；本轮准备独立验收包，不覆盖上一轮已验收安装包。

## 2026-10-27 03:30 | codex-composer-focus-install | C3 验收与应用替换

- 状态：用户确认真实流程无需点击输入框即可打字；备份、替换、重启和数据校验通过。
- 需求与范围：用户明确授权推送、替换；不发布 DMG、不安装全局 Skill。
- 改动：安装已验收 release 包至 Applications，保持原 bundle ID、数据目录及兼容链接；正常退出后完整备份旧应用与数据。
- 验证与证据：安装包逐文件与验收包一致，主程序 SHA-256 `40f35c9d84ef4ba5b002d95c97290225cfaf94a549a00dde23077a20b28f5df3`；替换期间数据未变，重启后待办、项目、回收站、附件及偏好一致；启动进程位于 Applications。备份与 verification.txt：`.local/backups/before-c3-focus-20261027-033055/`。
- 未完成/阻塞/下一步：冷启动 Codex、Spaces、多屏未新增验收；沿用现用 linker ad-hoc 身份，未正式签名公证。无安装阻塞。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[验收](docs/acceptance/codex-task-handoff.md)；main；按用户授权推送 origin/main。

## 2026-10-27 03:22 | codex-composer-focus | C3 隐藏面板后交接实现

- 状态：实现完成、9 项针对性测试及 release 打包通过；真实 Codex 焦点待用户验收。
- 需求与范围：用户确认 D 隔离实验可输入后授权修改；沿用 03:09 验证记录。打开 Codex 前收起清单、保留球，不自动发送或增加权限。
- 改动：准备 URL 与打开分离，在 sheet onDismiss 后 orderOut 清单；成功保持收起，失败恢复同一草稿和展开状态；取消和校验错误不跳转。
- 验证与证据：9 项 CodexHandoffTests 通过，包含真实 AppKit 面板可见状态与注入 opener 下的成功/失败恢复；不冒充 Codex 端到端。
- 未完成/阻塞/下一步：本地验收包 `.local/releases/c3-focus-20261027/Next One.app` 已生成，资源和 CLI --help 校验通过；先退出旧版后打开该包验收。未替换现用应用、未推送、未正式签名公证或发布。主程序 SHA-256：`40f35c9d84ef4ba5b002d95c97290225cfaf94a549a00dde23077a20b28f5df3`；日志位于同目录。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[验收](docs/acceptance/codex-task-handoff.md)、[UI 模块](Sources/TodoApp/README.md)；main 小修复，仅提交本任务文件。

## 2026-10-27 03:09 | codex-composer-focus | C3 无权限焦点方案对照验证

- 状态：A/B/C 未通过；用户授权继续 D 隐藏面板验证，结果待观察。
- 需求与范围：用户授权验证第一种无新增权限方案；不自动发送，不替换正式应用。
- 改动：仅本地隔离测试工具及验收记录；产品代码未修改。工具从普通窗口调整为匹配生产关键属性的非激活悬浮面板，复用生产输入框。
- 验证与证据：用户反馈直接深链接、普通窗口 A/B 均可输入 x，真实 Next One 不可；用户随后确认新版非激活面板 A/B 均失败，已复现；C 原生交还焦点实验编译通过，用户确认同样无法输入。见关联验收记录。
- 未完成/阻塞/下一步：面板 A/B 及 C 均失败，不作为修复；D 改用 orderOut(nil) 后打开深链接，已编译并打开测试窗口，待用户观察；正式功能未实现。Codex UI 工具禁止访问，不绕过；根因尚未确认，其他无权限方案未被穷尽，不据此声称必须增加权限。
- 关联文档与 Git 状态：[验收记录](docs/acceptance/codex-task-handoff.md)、[原 Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅提交本轮证据文档，不推送；实验文件保存在已忽略的 .local/codex-focus-probe/。

## 2026-10-27 02:53 | codex-task-handoff-install | 推送并替换 B9 开发版本

- 状态：release 构建、推送、备份、安装替换及启动校验完成，等待用户功能验收。
- 需求与范围：用户明确授权推送并替换现用应用，替换后由用户验证；不发布 DMG、不安装全局 Skill。
- 改动：基于 d767193 构建 release，推送 origin/main；正常退出旧版，备份旧应用和完整 release 数据后替换 Applications 中 Next One 并启动。保留 local.todo-ai.release 与原数据目录/兼容链接。
- 验证与证据：新包资源 bundle、灰色 Logo、产品 Skill、内置 CLI 校验通过；安装文件逐文件哈希与构建一致，替换期间数据逐文件不变，重启后待办/项目/回收站快照、附件及 language/reminder-sync/window 偏好全部一致。主程序 SHA-256 `483c2c54296017556310500e1181c9725e9c4b909db0617349729c31e8b5f29b`，启动进程确认。日志 `.local/codex-handoff-install/verification.txt`。
- 未完成/阻塞/下一步：等待用户验证实际右键入口、预填和换行；Codex UI 与新会话 Skill 端到端限制不变。全局 Skill 未改，应用随包上游资源已更新。本轮沿用现用 linker ad-hoc 本地构建方式，未新增 Developer ID 签名、公证或对外分发。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[验收](docs/acceptance/codex-task-handoff.md)；main；备份 `.local/backups/before-codex-handoff-20261027-025102/`，构建 `.local/releases/codex-handoff-20261027-025102/`。本条记录提交后按本轮授权推送。

## 2026-10-27 02:43 | codex-task-handoff | B9 本地开发与验证

- 状态：本地实现完成，自动及标准窗口交互验证通过；真实悬浮面板与 Codex 端到端待补验。
- 需求与范围：用户明确授权当前会话独立开发；首版仅已有项目，菜单首行灰色 ChatGPT Logo/分隔线，支持多行可选指令和易读 neo 上下文。
- 改动：独立只读 Codex 项目适配、项目/目录流程、提交前新鲜度校验、附件路径和 URL 编码、原生 sheet/输入按键、四语资源、仓库 Skill、Logo 与打包资源。无新依赖，不改 Codex 数据或自动发送。
- 验证与证据：全量 65 项通过后补充附件测试，整合最新主分支后受影响 15 项通过；release build、debug 打包及 Skill 结构校验通过。新代码真实只读 66 项目/67 目录；标准窗口同生产视图的深浅菜单、选择、换行、取消、失效目标和草稿保留实测通过。详见验收记录。
- 未完成/阻塞/下一步：工具无法操作 Codex UI，真实悬浮面板定位受限；完整跳转/冷启动/焦点、真实中文候选和新会话 Skill 生效需人工补验。普通文件导入仍受既有图片/视频规则限制。B9 不标完成。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[验收](docs/acceptance/codex-task-handoff.md)；codex/codex-task-handoff worktree，已保留双方修改、复测并安全合并 main；不推送、不安装替换或发布，产物保存在 .local/codex-handoff-acceptance/。

## 2026-10-27 02:42 | scrollbar-visible | 贴边滚动滑块持续可见

- 状态：修复、相关验证、备份及现用应用替换完成。
- 需求与范围：用户反馈滚动条几乎看不到，要求贴边且明显粗于边框，并授权提交、推送和替换现用应用；延续 01:12 scrollbar-gutter 的无占位布局。
- 改动：保留 3 pt（约 1 pt 边框的三倍）和原生 overlay 布局/输入机制；独立无命中绘制层避免原生渐隐，颜色增强为 labelColor 65%，无溢出隐藏。同步 Spec、模块说明及通用偏好。
- 验证与证据：2 项 ScrollbarLayoutTests 通过，覆盖四页面 340/520 pt、嵌套滚动区、深浅色空闲渲染、纵横 3 pt、贴边命中、位置更新及无溢出隐藏；release 构建通过。原生窗口截图及已安装清单确认常显，AX 滚动值更新通过。初轮发现绘制层尺寸及可见滑块命中问题，均已修复后复验；证据 `.local/scrollbar-visible/`。
- 未完成/阻塞/下一步：坐标拖动返回 windowNotFoundAtPosition，不报告物理拖动通过；多屏/Spaces 未新增验收。完整备份 `.local/backups/before-scrollbar-visible-20261027-024500/`，替换包哈希一致，重启后任务/项目/回收站快照及附件不变。保持现用本地构建签名方式，未正式签名公证或公开发布。
- 关联文档与 Git 状态：[产品 Spec](docs/spec/2026-10-24/macos-floating-todo.md)、[UI 模块](Sources/TodoApp/README.md)；main 小修复，用户授权提交、推送及替换，本轮仅暂存相关文件。应用主程序 SHA-256 `f15395916e426d3b9ca39266971a8e43f1d44e39273ad92847fea20dc683e182`。

## 2026-10-27 02:22 | codex-task-handoff | 补充创建会话菜单样式

- 状态：Spec 已更新，未实施。
- 需求与范围：用户要求“创建 Codex 会话”位于右键菜单第一行，前置灰色 ChatGPT Logo，下方灰线分隔。
- 改动：补充入口位置、图标样式、分隔线及原有选项顺序保持规则，同步示例文案和 AC01。
- 验证与证据：正文/示例/验收文案一致性、相对链接及 git diff --check；纯文档不运行代码测试。
- 未完成/阻塞/下一步：无文档阻塞；菜单视觉与实际交互待实施验证。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅提交本轮文档，不推送。

## 2026-10-27 02:17 | codex-task-handoff | 首版仅支持已有 Codex 项目

- 状态：用户确认范围调整，Spec 已同步；未实施。
- 需求与范围：用户选择方案 2，首版暂缓无项目聊天，仅支持已有本机 Codex 项目。
- 改动：移除聊天选项；未分类、无绑定路径和路径未匹配时选择已有项目；补充零项目处理、目标多目录选择、原路径与最终跳转目录区分，同步 AC03/AC05 及预验证结论。
- 验证与证据：检查当前规则与验收条件一致性、相对链接及 git diff --check；纯文档不运行代码测试。
- 未完成/阻塞/下一步：无项目入口不再阻塞首版；只读适配、完整消息及真实交互仍待实施验证。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)；main，仅本轮文档提交，不推送。

## 2026-10-27 02:13 | codex-task-handoff | 确认项目数据方案并核对聊天目录

- 状态：项目列表读取方案已写入 Spec；指定聊天归属只读核对完成。
- 需求与范围：用户确认采用只读数据库建议，并授权检查截图中“调研 monid 平台”的路径和归属。
- 改动：新增 Spec 7.1 数据库只读适配规则，扩展 AC03；记录指定会话 cwd 与项目归属的区别。
- 验证与证据：只读查询 name 精确匹配截图；project_id 为 NULL，cwd 为 Documents 下独立任务目录且未在 project_roots 登记；未读取聊天正文或目录内容。文档一致性与差异检查。
- 未完成/阻塞/下一步：该存储目录不证明新建 path 参数可强制无项目；无项目入口继续待验证。未开发产品或改 Codex 数据。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/codex-task-handoff.md)、[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)；main，仅相关文档提交，不推送。

## 2026-10-27 02:04 | codex-task-handoff | 本地 Codex 项目数据读取验证

- 状态：本机项目名称/目录只读获取验证通过，尚未产品化。
- 需求与范围：用户明确授权调查配置/数据库读取；仅项目字段，不读聊天正文或凭据，不修改 Codex 数据。
- 改动：同步预验证记录和 Spec，区分公共接口未找到与内部数据实际可读。
- 验证与证据：SQLite mode=ro + query_only 查询 projects/project_roots，66 项目/67 目录；Next One 精确匹配；JSON local-projects 名称/目录集合相同，但 ID 不同；config projects 段为 127，不能代替项目列表。
- 未完成/阻塞/下一步：正式适配需处理内部 Schema 变化、只读错误与多路径；无项目聊天入口仍未解决。未实施产品读取代码。
- 关联文档与 Git 状态：[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)、[Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅本轮文档提交，不推送。

## 2026-10-27 02:02 | codex-task-handoff | 无项目聊天入口专项调研

- 状态：公开资料和源码调研完成，未找到满足无项目+预填的原生外部入口。
- 需求与范围：用户反馈显式空 path 也无效，并明确授权一个子代理查官方开源实现；仅调研。
- 改动：更新预验证记录与 Spec，记录空路径失败、独立聊天快捷键和开源桌面启动器证据。
- 验证与证据：子代理检查官方仓库 c21153b 的 CLI desktop_app：mac.rs 构造带 path 深链接，未找到桌面接收路由；官方文档未列 projectless 参数，快捷键为人工入口。文档链接结构及差异检查；未创建/发送会话或操作 Codex UI。
- 未完成/阻塞/下一步：无项目聊天接口仍阻塞；项目列表来源另待解决。手动独立聊天+粘贴或暂缓该选项仅为替代建议，未更改范围。
- 关联文档与 Git 状态：[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)、[Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅本轮文档提交，不推送。

## 2026-10-27 01:56 | codex-task-handoff | 用户跨项目深链接验证

- 状态：已有项目切换与两行预填经用户手测确认；无项目聊天仍未解决。
- 需求与范围：接续 01:49 预验证，用户从另一项目点击两个入口并提供截图。
- 改动：更新 Spec 和预验证记录，明确显式 path 切回 Next One，省略 path 沿用原项目；不再将后者视为无项目入口。
- 验证与证据：用户反馈及截图分别显示 Next One 和 customer-acquisition，输入框均有两行测试文本；文档一致性、相对链接与差异检查通过。不是 Agent UI 自动化证据。
- 未完成/阻塞/下一步：无项目聊天入口、原生应用项目列表来源、完整消息和冷启动仍待验证；未开发产品。
- 关联文档与 Git 状态：[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)、[Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅提交本轮文档，不推送。

## 2026-10-27 01:51 | release-workflow-skill | 项目打包签名 Skill 与本地证书目录

- 状态：流程规范与本地资料整理完成；正式签名、公证流水线尚未实施／验收。
- 需求与范围：用户要求制定打包 Skill、在 AGENTS 引用并隔离签名资料；仅文档与本地配置，不执行打包、签名、公证、安装或发布。
- 改动：新增项目级 next-one-release Skill，规定身份检查、由内到外签名、App／DMG 公证票据、校验与授权边界；AGENTS 引用；补充证书／CSR／p8 忽略规则。公开证书、CSR 与非秘密元数据复制到 .local/signing/，私钥继续留在登录钥匙串，未导出。
- 验证与证据：本机 security find-identity 确认为有效 Developer ID Application 身份；证书属于 LIJIAN QIN（5C58V84WF7），到期 2027-11-26（Asia/Singapore）。Skill quick_validate、相对链接、AGENTS 大小、Git 忽略规则与 git diff --check 均通过；没有运行产品代码测试或正式签名测试。
- 未完成/阻塞/下一步：无文档阻塞；现有 package-dmg.sh 会重建 App，正式自动化仍需改造；本轮未配置或验证公证 profile，权限跨重启／更新保留未实测。未验证新会话自动发现 Skill，AGENTS 已提供显式读取入口。
- 关联文档与 Git 状态：[Skill](.agents/skills/next-one-release/SKILL.md)、[AGENTS](AGENTS.md)、[本机安装说明](docs/distribution/local-install.md)；main 文档／配置维护，仅提交本任务，不推送；.local/signing/ 不入库。

## 2026-10-27 01:49 | codex-task-handoff | Codex 接口预验证

- 状态：官方契约与本机协议核对完成，桌面交互验证受工具限制。
- 需求与范围：用户授权提前验证 B9 所需 Codex 接口；不开始产品开发、不发送测试消息。
- 改动：新增接口预验证记录，同步 Spec 授权及已验证/未验证边界。
- 验证与证据：CLI 0.144.1；生成 experimental Schema，检查 122 个请求方法与 thread/start、turn/start 参数；未发现桌面项目列表方法。官方确认深链接仅预填。cua.getApp 对 Codex 返回安全限制拒绝，未绕过。
- 未完成/阻塞/下一步：需人工观察新会话预填、项目归属和无项目聊天；原生应用读取桌面项目列表接口仍未找到。未创建会话、未发送消息、未改配置。
- 关联文档与 Git 状态：[预验证记录](docs/acceptance/codex-task-handoff-preflight.md)、[Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅提交相关文档，不推送；本地 Schema 位于 .local/codex-handoff-probe/。

## 2026-10-27 01:44 | codex-task-handoff | 简化 B9 上下文格式

- 状态：Spec 修订完成，未实施。
- 需求与范围：用户要求上下文使用外层 neo 标签和易读文本，去掉复杂字段结构；接续下方 01:34 Spec 记录。
- 改动：移除消息内 UUID、内部标签和属性；短编号与标题首行，备注、项目目录和附件路径按行展示；补充指令在标签外空一行追加。同步 Skill 契约及 AC06。
- 验证与证据：检查示例与正文/验收条件一致性、相对链接及 git diff --check；纯文档不运行代码测试。
- 未完成/阻塞/下一步：无文档阻塞；原接口实测事项不变，尚未开发。
- 关联文档与 Git 状态：[B9 Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main，仅提交本轮 Spec 与状态记录，不推送。

## 2026-10-27 01:34 | codex-task-handoff | B9 从待办打开 Codex 会话 Spec

- 状态：需求已对齐，Spec 已形成；尚未实施。
- 需求与范围：用户要求把 B9 及批注形成 Spec；本轮仅文档。首版打开新会话并预填，由用户发送。
- 改动：明确项目/聊天选择、单/多路径匹配、Enter 与 Shift+Enter、无默认指令、XML 上下文和附件路径、Skill 边界及验收条件。
- 验证与证据：核对现有菜单、Store 附件接口、Swift Package 和测试命令；文档结构、相对链接与差异检查。本轮不运行代码测试、不创建测试会话；运行能力未验证。
- 未完成/阻塞/下一步：开发前核实外部读取 Codex 项目列表、无项目聊天和目标版本跳转预填；无文档阻塞，不将会话内工具视为原生应用公共接口。
- 关联文档与 Git 状态：[B9 Spec](docs/spec/2026-10-27/codex-task-handoff.md)；main 文档维护，仅提交本轮 Spec 和状态记录，不推送。

## 2026-10-27 01:12 | scrollbar-gutter | 移除全页面滚动条占位空白

- 状态：公共修复、验证及现用应用替换完成。
- 需求与范围：用户指出清单和设置右侧留白过大，要求所有页面检查；根因是此前只调整ThinScroller绘制，传统scroller仍占内容宽度。
- 改动：宿主统一NSScrollView.scrollerStyle为overlay，保留3 pt贴边滑块、原生命中区和现有内容padding，不改系统偏好；覆盖清单、详情、设置、回收站与嵌套滚动区。同步Spec、模块说明和通用边距规范。
- 验证与证据：ScrollbarLayoutTests在340/520 pt两种宽度遍历四页面及嵌套NSScrollView，强制legacy后验证恢复overlay、clip宽度等于容器宽度；测试通过。release打包通过；隔离原生清单／详情／设置／空回收站截图确认边距，证据 `.local/scrollbar-gutter/`。复制的隔离数据触发同步身份／接入保护提示，未绕过；接入框实际界面未在该实例重验，共用滚动策略覆盖该入口。
- 未完成/阻塞/下一步：无修复阻塞；物理滚轮／拖拽及全系统组合未新增验收。备份旧应用与全量数据后替换，启动后任务／项目／回收站快照、附件及保存透明度不变；备份 `.local/backups/before-scrollbar-gutter-20261027-011151/`。
- 关联文档与 Git 状态：[产品Spec](docs/spec/2026-10-24/macos-floating-todo.md)、[UI模块](Sources/TodoApp/README.md)；main小修复，沿用本会话提交推送和替换授权，安装校验见 `.local/scrollbar-gutter-install/verification.txt`。

## 2026-10-27 00:59 | readme-screenshot-refresh | 四语README更新当前应用实拍

- 状态：12张新截图拍摄、替换及视觉检查完成。
- 需求与范围：用户指出README截图旧，要求重新截图；更新英／中／日／韩的清单、详情和设置。
- 改动：当前release副本配独立演示数据，拍摄短编号、统一完成区、日期与日历同步设置；替换12张JPEG，更新四语图片说明／alt及素材来源记录，删除历史截图提示。
- 验证与证据：12张原生截图逐张目视检查，格式JPEG、960×1480；相对图片链接及差异检查通过。日历同步默认关闭，未申请权限或向系统写入演示提醒，未改真实任务、应用设置或安装。截图脚本／目录指针在 `.local/readme-refresh/`。
- 未完成/阻塞/下一步：无；生成的neo输入示意图保持原有说明，本轮不把静态图作为同步或穿透验收。
- 关联文档与 Git 状态：[截图来源](docs/assets/screenshots/README.md)、[中文README](docs/readme/README.zh-CN.md)；main，仅提交截图和相关文档，沿用本会话推送授权。

## 2026-10-27 00:50 | readme-recent-features | 四语README补充提醒事项同步与近期功能

- 状态：文档更新、事实核对与链接检查完成。
- 需求与范围：用户要求将近期功能特别是提醒事项与日历同步明确写入README；同步维护英／中／日／韩版本。
- 改动：功能亮点置首新增提醒事项同步，独立介绍开启步骤、iCloud与系统版本条件、字段方向、手机完成回传、删除／归档／关闭行为、附件及Urgent限制；补充锁定悬停、贴边滚动条、短编号与完成归档、默认一般优先级。修正旧隐私／云同步表述，标明当前main与旧预览包差异。
- 验证与证据：对照ReminderSyncView、App/Core ReminderSync实际实现、语言资源和同步验收记录；核对Apple日历官方说明。四语README相对链接、图片路径、代码块闭合及git diff --check通过；纯文档不重跑代码测试。
- 未完成/阻塞/下一步：无文档阻塞；未新增系统同步或交互验收，不重打包／替换应用、不更新公开DMG。
- 关联文档与 Git 状态：[英文README](README.md)、[中文README](docs/readme/README.zh-CN.md)、[日文README](docs/readme/README.ja.md)、[韩文README](docs/readme/README.ko.md)；main，仅提交本轮文档，沿用本会话明确推送授权。

## 2026-10-27 00:44 | locked-hover-install | 推送并替换滚动条与锁定淡化版本

- 状态：release构建、8项针对性测试、备份、应用替换及启动核验完成。
- 需求与范围：用户明确要求提交推送并替换当前应用，包含滚动条贴边47d7dc6与锁定悬停淡化60d0b82。
- 改动：正常退出旧版，完整备份release数据及旧应用；替换 /Applications/Next One.app 并重新启动。使用原release标识及数据目录，不安装全局Skill。
- 验证与证据：release打包及8项相关测试通过；安装文件与构建逐文件哈希相同，替换期间数据逐文件不变；重启后任务／回收站／项目快照及附件一致，不透明度／置顶／折叠／尺寸／语言保留。位置与展开方向在启动后变化，未覆盖当前窗口几何值。证据 `.local/locked-hover-install/verification.txt`。
- 未完成/阻塞/下一步：无替换阻塞；原物理悬停／背后输入及多屏验收限制不变。旧应用与数据备份 `.local/backups/before-locked-hover-20261027-004343/`；不发布DMG。
- 关联文档与 Git 状态：[锁定Spec](docs/spec/2026-10-27/locked-hover-fade.md)；main，功能已提交，本轮交付记录提交后一并按授权推送origin/main。

## 2026-10-27 00:40 | locked-hover-fade | 锁定面板悬停淡化

- 状态：本地实现完成，自动及原生属性验证通过；物理交互待补验。
- 需求与范围：锁定时鼠标进入面板，背景0%、其他内容50%；移出恢复，悬浮球不变，不覆盖用户保存的透明度。
- 改动：锁定展开时启用50 ms鼠标位置读取；临时状态控制根背景、面板alpha与阴影；移出／解锁／取消置顶恢复，收起停timer，展开／移动重算。保留穿透、焦点和球入口，无新权限或依赖。同步产品Spec及UI说明。
- 验证与证据：debug打包通过；相关7项测试通过，追加原生鼠标位置与timer测试后LockedHoverTests两项通过。原生内容渲染空白背景RGBA=(0,0,0,0)，窗口alpha=0.5，证据 `.local/locked-hover-fade/evidence/hover-content.png`（不含窗口合成系数）；真实隔离清单／设置打开及锁定成功。
- 未完成/阻塞/下一步：CUA锁定窗口坐标点击报windowNotFoundAtPosition，无法完成物理连续悬停／背后输入复验；多屏、Spaces和辅助功能组合未实测。无代码阻塞，测试实例已退出；不替换现用应用、不推送。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-27/locked-hover-fade.md)；codex/locked-hover-fade完成后安全快进合并main，仅提交本任务。

## 2026-10-27 00:34 | scrollbar-edge-alignment | 滚动条贴容器边界

- 状态：公共绘制修复完成，构建与原生离屏渲染验证通过；未替换现用应用。
- 需求与范围：用户截图指出清单滑块与右侧边界留缝，要求项目滚动条紧贴边界；覆盖共用 ThinScroller 的所有滚动容器。
- 改动：3 pt 纵向滑块从原生滑块区域居中改为贴 bounds 右边，横向贴底边并兼容翻转坐标；保留内容间距、原生 frame、命中区与滚动逻辑。同步协作规范、产品 Spec 和 UI 模块说明。
- 验证与证据：`swift build --product TodoAI` 通过；隔离 AppKit 渲染脚本 `.local/scrollbar-edge/main.swift` 检查真实 ThinScroller 绘制，2× 位图纵向 x=24…29/宽30，横向 y=24…29/高30，均占6像素即3 pt且接触外边缘；图片为同目录 `vertical.png`、`horizontal.png`。初次横向断言因离屏画布未采用视图翻转坐标失败，修正验证画布后双向通过。
- 未完成/阻塞/下一步：现用安装包未替换；实际应用各页视觉、物理拖动和滚轮未在本轮复验，离屏检查不替代这些交互验收。无数据或系统设置修改。
- 关联文档与 Git 状态：[产品 Spec](docs/spec/2026-10-24/macos-floating-todo.md)、[UI 模块](Sources/TodoApp/README.md)；main 上的小修复，仅提交本任务内容，不推送、不安装。

## 2026-10-27 00:14 | default-priority-low | 新建待办默认一般

- 状态：实现、验证和现用应用替换完成。
- 需求与范围：用户要求默认优先级从比较紧急改为一般，仅影响以后新建任务，不批量调整已有待办。
- 改动：共享 TodoItem 默认值改为 low，UI／Quick Add／子任务／CLI 复用同一入口；同步产品 Spec 与 CLI 参考。
- 验证与证据：release打包通过；用旧版CLI在隔离目录创建medium任务，再用新版包内CLI确认其保持原值、新建根任务和子任务均为low、显式medium/high和无关更新保留优先级。替换前备份应用与完整数据，应用与构建一致，任务快照不变；只读SQLite校验产生的shm变化不当作数据丢失。证据 `.local/default-priority/verification.txt`。
- 未完成/阻塞/下一步：无；原系统权限／同步验收边界不变，不新增任务数据迁移。备份 `.local/backups/before-default-priority-20261027-001341/` 的实际目录以 `.local/default-priority/backup-path.txt` 为准。
- 关联文档与 Git 状态：[产品Spec](docs/spec/2026-10-24/macos-floating-todo.md)、[CLI参考](Skills/next-one/references/cli.md)；main小修复，本地提交并按本会话授权推送、替换现用应用。

## 2026-10-27 00:09 | calendar-list-refresh | 设置页每2秒刷新目标清单

- 状态：实现、验证及现用应用替换完成。
- 需求与范围：用户反馈系统清单修改后设置下拉框滞后，要求打开设置期间每2秒刷新。
- 改动：视图生命周期绑定轮询，离开自动取消；保留选择ID，无变化不重置列表，被动刷新不重复授权或禁用控件，授权／同步忙时跳过本次读取。同步Spec与模块说明同步更新。
- 验证与证据：同步／本地化12项定向测试、release打包及差异检查通过。备份原应用和完整数据后替换；用户重新允许系统权限后，原生下拉显示最新 Next One List，旧测试清单消失且选择保留。未更改用户清单进行破坏性测试。
- 未完成/阻塞/下一步：无修复阻塞；系统权限仍由用户决定。备份 `.local/backups/before-calendar-list-refresh-20261027-000727/`；默认每2秒读取，无系统送达时延承诺。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/calendar-reminders-sync.md)；main小修复，按本会话授权更新现用版并提交推送。

## 2026-10-27 00:00 | calendar-sync-install | 合并日历同步并替换现用应用

- 状态：按用户授权完成快进合并、GitHub 推送、现用 release 应用替换与验证；功能与规则已推送至 e03a0f2，本条完成状态随文档提交同步。
- 需求与范围：合并日历同步、推送 GitHub、替换现用应用；AGENTS 新增本项目默认安全自动合并，遇无法安全处理的冲突／问题先说明，不自动扩大为后续推送、安装或发布授权。
- 改动：main 快进至功能提交 e358cf4；使用相同 release 标识和数据渠道打包替换。旧应用及完整数据已备份到 `.local/backups/before-calendar-sync-20261026-235919/`。同步保持默认关闭，无测试数据／映射导入。
- 验证与证据：release 构建与18项针对性测试通过；新应用与构建逐文件一致，替换前数据逐文件一致，启动后任务快照和附件哈希与备份一致。原生设置确认“同步到日历”入口且关闭，证据 `.local/calendar-sync-install/verification.txt`；AGENTS 大小与差异检查通过。
- 未完成/阻塞/下一步：用户可在设置主动启用并选择自己的 iCloud 提醒事项清单；未自动授权系统提醒事项访问、安装全局 Skill或发布新 DMG。自动 Urgent 仍不支持，原验收限制不变。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/calendar-reminders-sync.md)、[验收](docs/acceptance/calendar-reminders-sync.md)、[协作规则](AGENTS.md)；main，本轮仅提交规则与安装记录，并按授权推送。

## 2026-10-26 23:12 | calendar-reminders-sync | 日历提醒同步开发

- 状态：本地实现完成，自动测试及主要 Mac/iPhone 链路通过；未覆盖的系统边界见验收记录。
- 需求与范围：按已授权 Spec 独立实施；手机验证集中在 Mac 自动与原生验证之后，提前通知用户。
- 改动：EventKit 协调器、独立持久化 UUID 映射与互斥、双向完成状态、删除恢复、冲突暂停／恢复、清单迁移、四语设置／问号与权限用途。按用户纠正实际标题为 A1-待办1；附件不同步，普通网络延迟静默。
- 验证与证据：Swift 全量55项、最终同步／本地化12项及真实CLI smoke通过；debug打包与原生设置、系统读写、失效ID恢复、启动接收完成、级联确认、清单迁移和暂停恢复实测。用户确认手机日历显示、A4完成、A5取消完成及23:38通知；Mac读回状态核验，手动Urgent在改标题后保留。证据见验收文档。
- 未完成/阻塞/下一步：自动 Urgent 开关仍不支持；真实断网／合盖／权限撤销和全部跨账户／附件属性边界未验证。8条受管测试提醒已移除，空测试清单保留，隔离测试应用已退出；现用应用未替换。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/calendar-reminders-sync.md)、[验收](docs/acceptance/calendar-reminders-sync.md)；codex/calendar-reminders-sync，本地提交，不合并或推送。

## 2026-10-26 22:54 | calendar-reminders-sync | 日历提醒同步 Spec

- 状态：Spec 编写完成，尚未实现／验收；本轮仅文档。
- 需求与范围：按用户确认采用系统提醒事项并在日历展示；标题编号格式、稳定 UUID 映射、修改／删除联动、手机完成状态回传、目标清单下拉与问号说明；附件均不同步、断网静默补偿、允许系统桌面通知。
- 改动：新增独立 Spec，区分已确认需求、建议默认、权限／持久化／冲突边界和实机验收；自动开启 Urgent 闹钟保留为公开 API 尚未满足项，不用普通提醒替代。
- 验证与证据：核对当前代码、现有编号／归档规则及本轮已查 Apple 资料；文档结构、仓库相对链接与差异检查通过。未运行代码测试、未申请权限、未创建系统提醒事项；双设备验证未执行，届时提前通知用户配合。
- 未完成/阻塞/下一步：等待明确实施指令；无写 Spec 阻塞。实施可沿用 Spec 的建议默认值；Urgent 自动开启未支持，其他平台与双设备行为仍待实测。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/calendar-reminders-sync.md)；main，仅本地提交本文档及状态记录，不推送；未修改开工时已有的 Views.swift、Windows.swift 和总体 Spec 差异，它们在本轮期间由其他工作提交。

## 2026-10-26 22:49 | zero-background-opacity | 背景不透明度下限与现用替换

- 状态：已提交同步并替换现用应用，验证完成。
- 需求与范围：最低背景不透明度改为 0%；用户授权合并、同步后替换现用应用。
- 改动：滑块与偏好恢复范围统一为 0%–100%，默认 90%；四语文档与模块说明同步。
- 验证与证据：前轮隔离副本 32 项测试与实际控制器 0% 保存恢复检查通过；本轮合并后的 release 48 项测试全部通过；release 打包通过，安装文件逐文件一致。现用设置实测 30%→20%→0%，验证后恢复原来的 30%；数据库与附件哈希保持一致。
- 未完成/阻塞/下一步：无；旧应用和完整数据已备份至 `.local/backups/before-zero-opacity-20261026-225131/`，新版已在 `/Applications/Next One.app` 运行；不更新全局 Skill 或公开 DMG。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-24/macos-floating-todo.md)；已有各分支由 57f277a 合并并同步，透明度修改 ab094f0 已推送，本条替换记录继续提交同步。

## 2026-10-26 18:53 | merge-all-branches | 整合所有已提交分支到 main

- 状态：分支整合与验证完成。
- 需求与范围：用户要求将尚未合并分支合并到 main 并推送 GitHub；多语言已在 main 历史中，待办功能链快进合并，Skill 生命周期分支合并适配。
- 改动：保留现有品牌、neo、归档/编号和安装版本；整合 integration install/status/uninstall，迁移至 next-one 路径和 NEXT_ONE_HOME，四语提示、英文 Skill/接入文档与历史验收记录同步。主目录并行的不透明度0%修改保留为未提交，不纳入合并。
- 验证与证据：Swift全量48项通过，安装器/本地化定向11项复验通过；debug打包及真实包内CLI隔离安装/状态/重复安装/runner/卸载通过，不创建待办数据库、不改真实全局规则。Skill校验通过。全量测试期间目录中有并行不透明度修改，其未暂存差异不属于本合并提交；另将精确暂存树导出到临时目录，独立构建并通过安装器/本地化/完成分区/后台归档13项定向测试。
- 未完成/阻塞/下一步：推送 main；不删除工作树或分支，不安装此次额外合并的Skill生命周期代码，不重新执行历史新会话验收。
- 关联文档与 Git 状态：[生命周期Spec](docs/spec/2026-10-26/codex-skill-lifecycle.md)；main，用户已授权合并/推送。

## 2026-10-26 18:47 | install-archive-completed | 安装长编号归档版本

- 状态：用户授权的本机替换完成，新版已运行。
- 需求与范围：现用 Next One release 升级为 725ac85 的归档版本；不执行归档。
- 改动：正常退出旧应用，主仓库 `.local/backups/before-archive-20261026-184504/` 备份旧应用与完整 release 数据，逐文件比对后替换 /Applications/Next One.app。启动完成存储 v2→v3 迁移，内置 integration/current CLI/Skill 同步更新。
- 验证与证据：release 42项测试通过；安装文件与构建一致。升级后的快照符合仅清除回收站占号的迁移规则，现有4条任务及编号/状态原样保留，附件哈希相等，删除任务数量不变；原生清单核对A1–A4仍在，编号未达到4位时不显示提示。验证记录 `.local/install/verification.txt`。
- 未完成/阻塞/下一步：无安装阻塞；未操作真实归档、未改全局Skill。回退必须同时恢复旧应用与对应数据；未合并main或制作DMG。
- 关联文档与 Git 状态：[归档 Spec](docs/spec/2026-10-26/archive-completed.md)；codex/archive-completed，按用户提交推送授权保存安装记录。

## 2026-10-26 18:41 | archive-completed | 长编号提示与完成归档

- 状态：实现、自动测试、隔离真实 CLI/原生流程验证完成。
- 需求与范围：全局长编号固定提示、完成任务归档回收站、从头跳号分配、恢复重新编号。
- 改动：独立分支，存储 v3、原子归档/候选校验、清理回收站占号、编号查询后 UUID 写入及顶部固定提示。
- 验证与证据：全量41项通过，新增后台归档/本地化定向6项通过；50k合成样本归档49,999条成功（debug预览/归档/读取/新建约25.13秒，不等于全应用50k性能通过）。原生取消/确认/回收站恢复及CLI跳号A2、恢复AAA1→A3验证通过；截图 `.local/archive-data/notice.png`。Skill校验及debug打包通过。
- 未完成/阻塞/下一步：无功能阻塞；大存量归档需要等待，已改后台进度并暂停轮询。未替换现用应用、更新全局Skill或归档真实任务；全应用50k交互性能未验收。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/archive-completed.md)；codex/archive-completed，基于 1b8f216，不合并或推送。

## 2026-10-26 18:30 | install-task-short-codes | 替换现用 Next One 安装版

- 状态：按用户授权完成替换并启动。
- 需求与范围：现用 /Applications/Next One.app 升级至本分支 1bf3fe6，包含统一完成区、全局编号/项目数量和 2 pt 灰线，保持 release 身份及数据渠道。
- 改动：正常退出旧版，备份原应用与完整数据至主仓库 `.local/backups/before-task-codes-20261026-182854/`；逐文件校验新版后替换。首次启动将 release 存储 v1 升级 v2，运行时 integration/current 的 CLI/Skill 同步为包内新版；未安装全局 Skill。
- 验证与证据：release 打包及 38 项测试通过；安装文件与产物逐字节一致。升级前后去除新增 shortCode/nextTaskNumber 后完整存储快照相等、附件哈希相等；原生现用窗口确认编号、项目数量和加粗灰线。`.local/install/verification.txt` 记录验证结果。
- 未完成/阻塞/下一步：无替换阻塞；应用已运行。全局 Skill 未更新，未合并、推送或重制 DMG；回退需同时恢复备份应用及升级前数据，不用旧版写入新库。
- 关联文档与 Git 状态：[编号 Spec](docs/spec/2026-10-26/task-short-codes.md)、[完成区 Spec](docs/spec/2026-10-26/unified-completed.md)；codex/task-short-codes，本轮记录本地提交。

## 2026-10-26 18:26 | completed-line-width | 已完成分隔线加粗

- 状态：已完成，本地构建通过。
- 需求与范围：用户要求已完成组件灰线大小加倍，按线宽从 1 pt 调为 2 pt。
- 改动：标题左右两段灰线同步加粗，文字与长度不变。
- 验证与证据：swift build --product TodoAI 与 git diff --check 通过；确认仅两段灰线由 1 pt 改为 2 pt，未新增测试、未重新做原生截图验收。
- 未完成/阻塞/下一步：无实现阻塞；未替换现用应用。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/unified-completed.md)；沿用 codex/task-short-codes，不合并或推送。

## 2026-10-26 18:24 | task-short-codes | 全局任务编号与项目数量

- 状态：实现、自动测试、真实 CLI 与本机隔离原生验证完成。
- 需求与范围：全局稳定短编号、对话/CLI 精确引用、标题前样式及项目父子总数；继承上一轮统一完成区。
- 改动：独立 codex/task-short-codes 分支，模型/Store/视图/Skill 同步。
- 验证与证据：最终 38 项测试通过；打包 CLI 验证编号查询/父级/幂等/完成恢复及旧 CLI 拒绝 v2；Skill 校验通过。原生窗口验证编号样式、父子计数、独立完成区与收起后计数保留；截图 `.local/codes-data/codes-expanded.png`。
- 未完成/阻塞/下一步：无本轮实现阻塞；未安装全局 Skill或验证新会话自动路由，未升级真实库、替换现用应用、合并或推送。真实升级须退出旧应用/CLI，使用匹配新版。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/task-short-codes.md)；本地开发，不合并、推送或安装。

## 2026-10-26 18:06 | unified-completed | 统一底部已完成区域

- 状态：实现、自动测试及本机隔离原生交互验证完成。
- 需求与范围：已完成根任务统一到底部，灰线嵌入标题，无箭头；展开后按项目彩色框分组。未完成父任务的已完成子任务保留原位。
- 改动：独立 worktree 实施展示分区和折叠状态，复用已有项目框；不改业务数据。
- 验证与证据：debug 构建、33 项测试及打包通过；隔离原生窗口验证灰线总区开合、项目独立折叠、父级子任务保留、父任务完成整支下移及恢复后返回上方。截图 `.local/completed-data/expanded.png`；测试用数据通过 CLI 创建。
- 未完成/阻塞/下一步：无本轮实现阻塞；未合并主分支、未替换现用安装、未推送。多显示器/Spaces 等无关窗口行为未重新验证。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/unified-completed.md)；codex/unified-completed，本地实施，不合并、推送或安装。

## 2026-10-26 15:32 | english-skill | Next One Skill 全英文说明

- 状态：英文文档、接口核对和现用内置资源更新完成。
- 需求与范围：用户要求 Next One Skill 全部使用准确英文；保留多语言用户请求和原有操作约束。
- 改动：SKILL.md、references/neo.md、references/cli.md 及可选持续规则全部改为英文，四语 README 更新语言说明；核对 CLI 参数、返回结构、存储渠道及 group 行为，移除不符合实现的未完成状态限制。neo 参考补充现有 Vibe Coding 场景，未新增应用能力。
- 验证与证据：Skill frontmatter 校验、全文英文与引用检查通过；与 CLI/Store 实现交叉核对。release 打包通过，包内文档及 LICENSE/NOTICE 与源码一致；现用应用内置 Skill 已备份到 .local/backups/before-english-skill-2026-10-26/ 并更新，正常重启后 current 导出文档与源码逐文件一致。无业务代码变更，不重复运行无关业务测试。
- 未完成/阻塞/下一步：不自动覆盖已有全局 Skill；已发布 v0.1.0-preview.1 的安装包仍含旧版中文 Skill，不悄悄替换已发布附件。
- 关联文档与 Git 状态：[Skill](Skills/next-one/SKILL.md)、[neo 规则](Skills/next-one/references/neo.md)、[CLI 参考](Skills/next-one/references/cli.md)；main，提交并同步 GitHub。

## 2026-10-26 15:28 | readme-logo | README 标题上方展示 Logo

- 状态：已完成。
- 需求与范围：用户要求在 README 标题上方醒目展示软件 Logo。
- 改动：四语 README 顶部居中放置 180 × 180 的黑底白色回形针图标，复用应用图标的圆角透明边缘版本，保存为 docs/assets/logo.png。
- 验证与证据：四语图片相对路径及标题前位置检查通过，git diff --check 通过；纯文档和素材修改，不运行应用测试。
- 未完成/阻塞/下一步：无；不重打安装包。
- 关联文档与 Git 状态：[README](README.md)；main，本轮提交并推送 GitHub。

## 2026-10-26 15:21 | github-preview-release | 首个公开安装包 Release

- 状态：公开预览版 Release 已发布，匿名下载验证通过。
- 需求与范围：用户授权公开仓库，并重新打包上传 GitHub Releases 供他人下载；保留非商业许可。
- 改动：0.1.0 build 6、标签 v0.1.0-preview.1，包含许可证与 neo Skill；发布 arm64 DMG 与相对文件名 SHA-256，四语 README 增加下载入口。
- 验证与证据：GitHub 设置页已显示 public（身份验证后）；主线 28 个提交/300 个文件版本的常见凭据模式及敏感文件名检查无命中，并非全面安全审计。release 构建、CRC/SHA-256、挂载资源/许可/CLI 检查通过；主程序和 CLI 与实测运行版一致，完整 Skill 与源码一致。
- 未完成/阻塞/下一步：无发布阻塞。匿名 API 确认仓库 public、Release 非草稿且 prerelease；无需登录下载 DMG（4,502,728 字节）及 SHA-256，与本地逐项哈希一致。未签名公证，不宣称生产就绪；未替用户安装、未修改全局 Skill。
- 关联文档与 Git 状态：[版本说明](docs/distribution/releases/v0.1.0-preview.1.md)、[公开下载](https://github.com/Lucas-Qinlj/Next-One/releases/tag/v0.1.0-preview.1)；产物源码 2799e2a，main 与标签已推送。页面截图 `.local/public-release/github-release.png`。

## 2026-10-26 15:09 | noncommercial-license | 非商业许可证与 GitHub 同步

- 状态：许可证及全部主线待同步内容已提交并推送。
- 需求与范围：用户要求提交并推送当前成果到 GitHub，增加不得商用的许可证。
- 改动：采用官方原文 PolyForm Noncommercial License 1.0.0，添加 LICENSE/NOTICE，四语 README 同步非商业限制；应用打包与独立分发 Skill 均携带许可及声明，挂载检查验证两处内容。
- 验证与证据：LICENSE 与官方 1.0.0 原文逐字节一致；release 打包通过，应用与 Skill 两处 LICENSE/NOTICE 均与源码一致；四语文档链接与 git diff --check 通过。GitHub 推送成功，origin/main 从 8346817 前进至许可证提交 79583d2，未强推。
- 未完成/阻塞/下一步：不合并两个独立工作树中的未交付任务、不修改仓库可见性、不发布 GitHub Release；既有 DMG 不追溯修改。
- 关联文档与 Git 状态：[LICENSE](LICENSE)、[NOTICE](NOTICE)；main；本交付记录也随主线推送，最后核对远端 HEAD。

## 2026-10-26 14:57 | readme-vibe-scenarios | README 聚焦 Vibe Coding 痛点

- 状态：四语文档及配图更新完成，检查通过。
- 需求与范围：用户要求替换生活化示例，聚焦开发者从需求拆待办、按架构排优先级，以及产品经理记录想法和老板交办事项。
- 改动：四语 README 改为场景/指令/保存价值三列表，覆盖需求拆分、依赖排序、想法留存、临时插单、会话交接和演示查漏；四张主图同步改为 PRD 任务规划，保留模型与完整底栏。明确架构判断由 Agent 完成，依赖记录在备注，不新增自动调度能力。
- 验证与证据：四张生成图文字与底栏已逐张检查；四语各六类场景、生活示例移除、图片/文档链接、提示词版本及 git diff --check 均通过。仅文档和素材修改，不运行无关业务测试。
- 未完成/阻塞/下一步：示例为使用建议，不是六类场景全部端到端验收；未修改 Skill、应用、安装包或真实任务。
- 关联文档与 Git 状态：[中文 README](docs/readme/README.zh-CN.md)、[英文 README](README.md)、[图片提示词](docs/assets/neo-examples/generation.json)；main，本地提交，不推送。

## 2026-10-26 14:49 | neo-installer | 包含 neo 的最新本机安装包

- 状态：本机安装包生成并验证完成。
- 需求与范围：用户明确选择重新打包供本机安装，不发布 GitHub Release。
- 改动：0.1.0 build 5，源码 13ab22b，包含最新 next-one Skill 的 neo 入口与参考文档、新路径和回形针品牌资源。
- 验证与证据：release 构建、镜像 CRC/SHA-256、挂载四语/图标/布局/CLI 检查通过；包内 Skill 全部文件与源码一致并含 references/neo.md，主程序/CLI 与已验证运行版本逐字节一致。产物 Next-One-0.1.0-local-isolated-arm64-13ab22b.dmg，4,498,544 字节。
- 未完成/阻塞/下一步：交付本机 arm64 DMG 和 SHA-256；不自动覆盖现用应用、全局 Skill，不签名公证或对外发布。
- 关联文档与 Git 状态：[安装说明](docs/distribution/local-install.md)；main，本轮修改已保存，因并行合并尚未提交，不推送。

## 2026-10-26 14:41 | readme-neo-examples | 四语 README 与 neo 输入示例

- 状态：四语文档与配图更新完成，检查通过。
- 需求与范围：用户要求更新全部四语 README，参考 Coding Agent 输入框生成本地化 neo 示例；补充要求保留完整底栏及 GPT-6 Astra 模型名称。
- 改动：中英日韩 README 增加靠前的 neo 示例图与新增/查询/改期/完成用法、安装前提和边界；统一数据路径兼容说明，保留原生实拍并注明旧设置路径。四张生成图包含模型、权限、推理程度和发送控件，明确标为未发送输入示意。
- 验证与证据：逐张视觉检查文字、GPT-6 Astra 及底栏完整性；四语文档链接、图片路径、PNG 尺寸、保留实拍、命名/数据规则和提示词清单检查通过，git diff --check 通过。无应用代码变更，不运行无关业务测试。
- 未完成/阻塞/下一步：不将生成图视为成功执行或自动路由证据；不推送、不重打安装包。
- 关联文档与 Git 状态：[英文 README](README.md)、[中文 README](docs/readme/README.zh-CN.md)、[素材与提示词](docs/assets/neo-examples/README.md)；main，本轮仅提交文档与图片。
## 2026-10-26 14:31 | neo-shortcut | neo 自然语言快捷入口

- 状态：Skill、产品文档及应用内置资源更新完成；新会话自动发现未验证。
- 需求与范围：记录用户关于短前缀降低 Skill 选择和任务录入成本的产品判断，并为 Next One Skill 添加 neo 显式入口。
- 改动：description 标记触发前缀，正文链接自然语言规则；明确生活事项默认未分类、日期与时区、唯一匹配、完成依据、幂等和真实成功反馈；复用原 CLI，不新增解析服务或终端命令。
- 验证与证据：Skill 校验通过；按固定测试时钟在隔离数据执行示例新增、查询、改期、完成、幂等重试和纯日期写入，通过后清理临时数据，证据 `.local/neo-check/cli-evidence.json`。release 打包通过，现用应用的内置 Skill 已备份并更新，正常重启后导出资源与源码逐文件一致；设置页保持打开。
- 未完成/阻塞/下一步：全局 Skill 未改，需从新版设置复制安装指令更新已安装 Skill；未验证新会话自动发现，不能将规则检查等同自动路由成功。本轮未重制 DMG，前一版 DMG 不含 neo 规则。
- 关联文档与 Git 状态：[产品方向与 Spec](docs/spec/2026-10-26/neo-shortcut.md)；main，本地提交，不推送。

## 2026-10-26 14:12 | next-one-paths | 接入路径统一更名

- 状态：实现、本机安装与新 DMG 验证完成。
- 需求与范围：用户要求数据目录、Skill 和 CLI 接入路径统一使用 Next-One 品牌。
- 改动：默认目录 Next-One / Next-One-Release，next-one Skill 和导出 CLI，NEXT_ONE_HOME；旧数据以兼容链接继续使用同一存储，显式路径不自动链接。
- 验证与证据：debug 全量 30 项及补充目录 4 项、最终本地化 5 项/接入 2 项通过；release 全量 32 项通过；两套真实 CLI smoke 与 Skill 校验通过。隔离及现用安装版设置实际确认新路径；替换后启动前数据库/附件哈希一致，启动后新旧路径指向同一数据库文件，附件哈希仍一致，旧 CLI 隐藏兼容入口一致。正常启动会写 SQLite 状态，不宣称启动后数据库字节不变。
- 未完成/阻塞/下一步：现用 release 应用已备份并替换，设置页保持打开；新包 `Next-One-0.1.0-local-isolated-arm64-4e28be1.dmg`（build 4）及 SHA-256 已生成，CRC、挂载资源/CLI 和二进制一致性通过。不自动覆盖全局 Skill，不清理旧数据目录或历史接入版本。未签名公证、未对外发布。
- 关联文档与 Git 状态：[Spec](docs/spec/2026-10-26/next-one-paths.md)；main，本轮修正既有更名功能，未推送。

## 2026-10-26 14:00 | next-one-installer | 最新 Next One 安装包

- 状态：打包及本机验证完成。
- 需求与范围：用户要求重新打包最新版本；基于源码 59ea3a2，包含 Next One 名称与黑底白色回形针。
- 改动：复用现有 release/DMG 流程生成 `Next-One-0.1.0-local-isolated-arm64-59ea3a2.dmg`（约 4.5 MB，0.1.0 build 3），附 SHA-256 文件；不覆盖现用应用。
- 验证与证据：release 构建、hdiutil CRC 与 SHA-256、包内四语/Skill/CLI、release 标识、图标资源一致性均通过；Finder 实际打开确认 Next One 名称、回形针与左右拖拽布局，截图见安装说明。映像完整复制到独立目录逐文件比对通过，以隔离数据启动成功后正常退出。
- 未完成/阻塞/下一步：无阻塞；安装窗口保留打开供用户试装。未替用户安装、未改真实任务或全局 Skill；未签名公证、未公开发布或验证其他机器。
- 关联文档与 Git 状态：[安装说明](docs/distribution/local-install.md)；main，安装包保存在忽略的 `.local/releases/`，交付记录本地提交，不推送。

## 2026-10-26 13:53 | product-rename | 产品更名 Next One

- 状态：已完成本地应用更名及远端仓库改名。
- 需求与范围：用户确认应用名 Next One，并要求同步产品需求和 GitHub 仓库名 Next-One。
- 改动：同步应用显示、四语文案、打包、当前使用文档；内部接口、数据目录及历史记录保留兼容名称。
- 验证与证据：debug 构建与打包通过；本地化/数据目录 7 项测试通过；原生应用标题、无障碍名称和菜单均显示 Next One；GitHub 页面显示 Lucas-Qinlj/Next-One（仍为私有），截图 `.local/next-one/github-renamed.png`。
- 未完成/阻塞/下一步：无阻塞。已安装并打开 `/Applications/Next One.app`，旧应用保存在 `.local/backups/before-next-one-2026-10-26/`，替换时数据库/附件哈希未变。未重制或发布 DMG，既有文档截图保留历史样貌；已有全局 Skill 保持不变。
- 关联文档与 Git 状态：[产品 Spec](docs/spec/2026-10-24/macos-floating-todo.md)、[新仓库](https://github.com/Lucas-Qinlj/Next-One)；origin 已更新，main 本地提交本轮内容，未推送代码（远端操作仅仓库改名）。

## 2026-10-26 13:45 | status-record-template | 统一开发状态记录模板

- 状态：已完成。
- 需求与范围：按用户要求统一每次功能开发和修改的状态记录，便于新会话按时间与功能检索；不重排历史记录。
- 改动：AGENTS 规定统一标题、Asia/Singapore 时间、稳定 feature-id、六个固定字段及新增/更新规则；本条采用该模板。
- 验证与证据：已检查模板字段、标题格式、文档链接与规范一致性；纯文档修改，不运行代码测试。
- 未完成/阻塞/下一步：无阻塞；后续功能开发与修改沿用该模板。
- 关联文档与 Git 状态：[协作规范](AGENTS.md#文档与状态维护)；本轮仅修改 AGENTS.md 与 PROJECT_STATUS.md，在 main 本地提交，不推送。

## 回形针 Logo 试用（2026-10-26）

- 按用户要求替换为白色竖向回形针、炭黑背景。保留生成原图，AppKit 转换圆角多尺寸 ICNS；悬浮球显示同源 PNG，菜单栏改为系统单色回形针，锁定保留锁标识。软件名称仍为 Todo-AI。
- `scripts/package-app.sh debug .local/paperclip-brand/TodoAI.app` 构建打包通过；检查 256 px 图标，实际启动后截图确认 44 pt 悬浮球显示新标识。此轮只改视觉资源与加载，不重复无关业务测试；未声称 Finder 图标缓存或锁定交互重新验收。
- 已备份 `/Applications/TodoAI.app` 至 `.local/backups/before-paperclip-logo-2026-10-26/TodoAI.app`，以相同 debug 身份替换并打开。安装后二进制与两份图标资源逐字节一致；启动前检查任务数据库与附件哈希未变，没有改名、迁移数据、更新全局 Skill、推送或制作新 DMG。

## 顶部空白区拖动（2026-10-26）

- 按用户截图，清单/详情/设置/回收站共用顶部工具栏及其上下留白支持按住拖动，保留控件点击；通过原生背景视图接收首次输入，超过 4 pt 后复用球与面板联动及位置保存，不触发清单折叠。锁定穿透不变，无新增权限或依赖。
- `swift build --product TodoAI` 和 `swift test --filter HeaderDragTests` 通过；测试覆盖阈值、两窗联动、松手清理/保存及不误折叠。隔离应用实际验证返回按钮和项目选择菜单可操作。
- 原生坐标拖动在中心留白和顶部上沿两次均返回 `windowNotFoundAtPosition`，未发出有效拖动；不能以测试模拟事件替代实际顶部拖动验收。需手动检查顶部留白联动、按钮不被拦截、其他应用有焦点时首次拖动及锁定穿透。
- 沿用当前会话替换现用应用的授权，正常退出并备份 `/Applications/TodoAI.app` 到 `.local/backups/before-header-drag-2026-10-26/`。核对发现旧安装包仍为 local.todo-ai.dev、使用 Todo-AI 数据目录，因此最终以 debug 构建保持相同身份与数据目录；未启动中途生成的隔离 release 包。新版已原位替换并启动，二进制与构建一致，数据库及附件哈希未变，隔离测试实例已退出。未推送或生成新 DMG。

## Release 安装版数据隔离（2026-10-26）

- 按用户明确要求，debug 开发版保留 Application Support/Todo-AI，release 安装版与其 CLI 改用 Application Support/Todo-AI-Release；隔离数据库、附件、语言、窗口偏好和接入资源。TODO_AI_HOME 优先覆盖；不迁移、复制或清空旧数据，后续安装版升级仍沿用自己的目录。
- TodoCore 使用 release 编译标识统一选择，包内/复制后的 CLI 不依赖路径位置；release bundle ID 改为 local.todo-ai.release。帮助可只读显示解析路径，Skill、接口说明、四语 README 和[安装说明](docs/distribution/local-install.md)同步更新；旧全局 Skill 不自动改写，需要用户用新版设置指令重新连接。
- [隔离 Spec](docs/spec/2026-10-26/release-data-isolation.md)已完成。debug/release 全量测试各 29 项通过；真实 CLI 默认路径、显式临时目录覆盖、空库及复制后 CLI 检查通过。原生安装包副本在隔离目录启动，确认空清单、无旧项目、接入路径一致。
- 新 DMG：`.local/releases/Todo-AI-0.1.0-local-isolated-arm64-3086de3.dmg`，0.1.0 build 3；完整性、SHA-256、资源、图标及安装版标识通过验证。保留旧包和真实数据，未安装替换现用软件、未修改全局 Skill、未推送/公证/对外发布；隔离验收实例已退出、镜像已推出。

## DMG 拖拽安装窗口与发布流程参考（2026-10-26）

- 用户反馈旧包只是普通文件夹，要求正式拖拽窗口并寻找专业发布 Skill。本轮检索并阅读 macos-release、release-mac-app 等 Skill，与 Apple 官方分发文档交叉核对；[比较与发布流程](docs/research/2026-10-26-macos-release-tools.md)记录适用边界。未安装全局 Skill、采用 Sparkle 或执行其推送/发布步骤。
- 将镜像构建改为 dmgbuild 1.6.7（独立本地 Python 环境，三个 MIT 纯 Python wheel 版本及 SHA-256 锁定），保留原生 release 应用构建。新增固定图标布局、Retina 背景、四语拖拽文案和正式清单 ICNS，移除可见的 Install.txt。普通应用启动无新增第三方依赖。
- 新产物：`.local/releases/Todo-AI-0.1.0-local-drag-install-arm64-244add0.dmg`，0.1.0 本机试装 build 2，约 3.2 MB。旧包保留；不覆盖现用应用，不操作真实待办。
- 已验证：release 构建与 DMG CRC/SHA-256 通过；Finder 实际双击打开后只有左侧 TodoAI 与右侧 Applications，背景、箭头、四语文字和图标正常，无侧栏/工具栏占位；截图见[安装说明](docs/distribution/local-install.md)。初次 Retina 图形重复缩放在实机检查中发现并修正，最终图无裁切。
- `verify-mounted.py` 只读验证四语资源、完整 Skill、应用图标、Applications 链接、DSStore 左右位置/背景和真实 CLI --help；包内应用/CLI 哈希与原 release 二进制一致。仅改打包和资源，未重复运行无关业务测试。新版安装窗口保留打开供用户拖入试装；未替用户安装到 Applications。
- 未执行 Developer ID 签名、公证、真实下载后 Gatekeeper 路径、跨机器/架构测试或对外发布；安装窗口外观完成不等同于正式发行完成。

## 本机 DMG 试装包（2026-10-26）

- 用户要求制作安装包在当前电脑试装；交付 0.1.0 本地试装版（build 1、arm64、源码 `8346817`），产物 `.local/releases/Todo-AI-0.1.0-local-arm64-8346817.dmg`，约 1.2 MB，附 SHA-256 校验文件。未进行 Developer ID 签名、Apple 公证或对外发布。
- 新增 `scripts/package-dmg.sh`：复用 release 构建、独立临时应用输出、Applications 快捷方式、中英安装说明、DMG 校验与 SHA-256；拒绝同名产物覆盖。`package-app.sh` 增加可选输出路径，默认行为保持不变，制作安装包不覆盖现用开发应用。四语 README 增加入口，详见[本机安装说明](docs/distribution/local-install.md)。
- 验证：release 构建成功，脚本语法检查通过，最终脚本完整运行退出 0；DMG CRC 校验、挂载、复制、Applications 符号链接及 SHA-256 检查通过。最终映像内应用文件哈希与已实际启动检查的副本一致。
- 从 DMG 复制到含空格的隔离安装目录，从 `/` 启动成功；原生悬浮球与设置正常，四语言选项存在，中英文切换及安装指令实际加载正常。四套语言资源、完整 Skill references 齐全；包内 CLI --help 与启动生成的 CLI project list 真实调用通过。
- 未将应用安装到 Applications，留给用户手动试装；未替换现用开发版、修改真实待办或全局 Skill。隔离验证实例已退出，验证映像已推出。正式分发、其他机器/架构、Gatekeeper 下载路径和历史待验收窗口组合不计为通过。本轮只提交脚本与文档，不提交生成的二进制，不推送。

## 悬浮球首次按下拖动修复（2026-10-26）

- 用户反馈其他软件有焦点时必须第二次按住球才能移动。`BallView` 原来仅声明键盘 first responder，缺少 `acceptsFirstMouse`；补充返回 true，与现有任务拖动视图的处理一致，保留原有 4 pt 阈值、联动几何及单击/右键行为。
- `swift build --product TodoAI` 通过。在 `.local/ball-first-click/` 隔离数据与独立应用包验证：实际拖动后锚点由 (2450, 1310) 变为 (2370, 1260)，右键仍显示“收起清单”，未误触折叠；单击后显示“展开清单”，右键菜单正常。测试实例已退出。
- UI 工具定向操作可能处理焦点，因此上述实拖不等于验证了系统非焦点窗口的首次输入。仍需手动检查：先点击其他软件，再直接按住球移动，分别覆盖展开、收起和锁定状态。未新增系统权限、未改真实待办或替换正在使用的应用；当前源码需重新构建启动后使用。未推送。
- 后续用户明确授权推送及替换：`d2f9e01` 已推送至 origin/main；通过球菜单正常退出旧进程，备份应用和数据至 `.local/backups/before-ball-first-click-2026-10-26/`，debug 打包成功并原位替换现用 `.build/TodoAI.app`。新版启动后原生悬浮球可见，可执行文件与最新构建逐字节一致；数据库及现有附件哈希核对未变。首次跨应用物理拖动仍保留上述手动补验边界。

## README 四语截图与核心卖点更新（2026-10-26）

- 按用户要求，基于已合并多语言功能的主分支 `9284ffc` 重新打包，在四个隔离演示数据目录分别拍摄英/中/日/韩清单、详情、设置，共 12 张真实原生截图；各语言 README 引用对应图片，英文仍为默认首页。虚构任务也分别准备为对应语言，不暗示应用自动翻译用户内容。
- 四语同步突出置顶伴随开发、背景不透明度 30%–100%、现成 Codex 安装指令一键复制及当前语言输出，并解释减少窗口切换、视觉遮挡与手动拼接路径/指令的价值。设置截图展示控件和指令，清楚区分复制与实际安装、Codex 内置接入与其他 Agent 的 CLI 接入。
- 验证：本地打包成功；12 张截图逐张检查语言与可读性；四语本地链接、图片文件及命令一致性检查通过。设置截图使用 100% 背景不透明度保证文字清晰，本次不新增透明叠加、穿透和跨桌面的验收结论。
- 仅更新 README、截图及相关状态/素材说明；未修改应用源码、真实待办、全局 Skill 或系统语言。演示实例已退出；未推送或更改仓库可见性。

## README 与公开展示准备（2026-10-26）

- 用户要求面向 Vibe Coding 用户整理项目介绍。根 README 改为英文默认，新增[简体中文](docs/readme/README.zh-CN.md)、[日文](docs/readme/README.ja.md)、[韩文](docs/readme/README.ko.md)，四语互链，覆盖痛点、人与 Agent 共享上下文、功能、接入、源码启动、数据隐私、开发和已知限制。
- 当前源码本地打包成功；独立演示数据通过 CLI 创建，真实原生应用截图纳入 [screenshots](docs/assets/screenshots/README.md)。未改真实待办、生产源码或全局 Skill；没有将鱼缸原型描述为原生功能。
- 修正旧 README 的手动保存说明，按现有实现写为自动保存及冲突处理。该次文档维护时 UI 仍为中文；之后的四语 UI 已按下方多语言记录合并。Codex 为内置接入，其他 Agent 仅可使用 CLI，未声称全面验证。
- GitHub 连接只读确认账户 Lucas-Qinlj；本轮维护本地文档，没有推送或更改仓库可见性。仓库尚无 LICENSE，许可证与正式公开发布需另行明确。
- 验证：四语文档本地链接、图片引用、结构与命令一致性检查；截图逐张视觉检查。纯文档任务，不重复执行业务测试，也不把本次打包/截图当作全部产品验收。

## 设计完成 / 尚未实施

- 像素鱼缸第二版（2026-10-25）：用户提供五张实拍参考，并确认“保留像素风，空间和运动更真实”。完成[详细设计](docs/design/2026-10-25/pixel-aquarium-scene-design.md)与[公开项目/原生能力比较](docs/research/2026-10-25/aquarium-rendering-options.md)，同步[功能 Spec](docs/spec/2026-10-25/pixel-aquarium.md)。方案覆盖三套候选景观、前中后水层、局部遮挡、叶隙、实体避让、换层、鱼体/水草/水光动作、素材拆分、原生集成和 V01–V13 验收。建议 SpriteKit + GameplayKit，尚未采纳或实施；本轮只做文档和本地参考归档，未安装依赖、重做素材、修改旧原型或真实数据。新版视觉/性能未验证。

## 代码托管

- 2026-10-25：用户授权创建 GitHub 仓库并上传当前项目，已初始化本地 main 分支、创建私有仓库 [Lucas-Qinlj/Todo-AI](https://github.com/Lucas-Qinlj/Todo-AI)。首次源码提交 edf3328 已成功推送到 origin/main，推送前 swift test 20 项全通过；下方历史记录中的“无 Git 仓库/无提交”仅描述当时状态。
- 托管源码、测试、Skill、文档和轻量原型资源；排除 .build、.local、数据库、环境/凭据、参考原图及验收截图。本机排除文件不删除，部分设计/验收文档中的本地图片证据不会随代码仓库提供。

## 已实现

- 多语言合并与现用替换（2026-10-26）：用户明确授权后，以 `dc4090f` 合并到 main；保留新 README、四语文档与截图，解决 README 冲突并更新四份文档的 UI 语言说明。合并后 27 项测试通过，主目录 debug 打包成功。正常退出旧进程后备份旧应用和用户数据至 `.local/backups/before-multilingual-2026-10-26/`，原位替换 `.build/TodoAI.app` 并重新启动。数据库/附件文件哈希保持一致；现用设置页实机确认跟随系统、中文、English、日本語、한국어 五个选项，保留既有透明度和项目绑定，当前仍跟随系统。未推送远程，未改全局 Skill 或系统设置。

- 多语言（2026-10-26）：在独立 `codex/multilingual` worktree 完成中文、英文、日文及用户追加的韩文，设置支持跟随系统与即时切换、重启记忆；菜单、确认框、提示、业务错误、日期显示和 Codex 安装指令同步本地化。每种语言 215 个模板，保留用户内容、草稿及 CLI 中文错误契约；无新依赖。27 项测试、真实 CLI smoke、四语言资源/参数审计通过；隔离原生应用完成四语言设置、英日韩 340 pt 详情、英日回收站、日文重启恢复、日/韩菜单、韩文无效标题错误/保留输入验证；移开构建目录资源后，复制出的应用仍正常运行。未改系统语言验证 OS 通知、未做母语者审校；系统文件面板内部文案由 macOS 决定。后续已按用户授权合并并替换现用应用，见下方交付记录；未推送。见[Spec 与验收记录](docs/spec/2026-10-26/multilingual.md)。

- 接入资源可移植化（2026-10-26）：应用包携带 CLI/完整 Skill，启动时按系统数据目录或 TODO_AI_HOME 准备 integration/versions 内容版本，并原子切换 current；设置指令只引用数据目录下的接入文件。删除编译期源码/祖先目录搜索，缺资源或写入失败可在设置重试。新增独立 debug/release 打包脚本，run.sh 复用。
- 验证：全量 swift test 22 项通过；修正旧拖动测试在同秒创建任务时依赖随机 UUID 顺序的夹具（用明确优先级建立基线，未改变业务逻辑）。两项 IntegrationTests 覆盖不同用户名/空格路径、应用移动、复用、升级/损坏恢复及失败保留；独立移到临时安装路径的完整应用从 / 启动成功，原生设置显示模拟用户数据目录，生成的真实 CLI --help/project list 通过，完整 Skill references 正确，无关数据保留。未安装全局 Skill、未发布签名公证包，跨机器/架构仍未验收。已重启本机开发版，原生设置确认所有接入路径改为当前用户数据目录，并复制新指令供验收。

- Codex 接入指令与复制入口（2026-10-25）：设置显示可滚动的完整安装指令和 doc.on.doc 图标，携带经检查存在的本机 Skill/CLI 及当前数据目录；指令授权接收会话安装用户级 Skill、保留已有内容、配置安装副本的 CLI/数据路径及只读验证。路径缺失时不提供失效复制入口；开发脚本同时构建 CLI 与应用。编译及原生复制/粘贴验证通过，实际剪贴板全文与显示内容逐字一致。没有执行全局安装、发送聊天消息或修改 Codex 配置，目标 Codex 会话安装/发现尚未验收。

- 目录解除绑定（2026-10-25）：每条路径重绑按钮右侧新增中性 trash 图标，点击确认仅解除绑定；保留项目、待办及磁盘文件，允许移除最后一个目录并后续重绑。UI/CLI 共用 project unbind 的项目版本及路径校验。编译与针对性 ProjectUnbindTests 通过；隔离原生设置页实点图标确认额外路径消失，真实 CLI 核对项目/任务/文件夹保留，并验证最后一条路径解除。未改动用户真实绑定作为测试数据。

- 项目分组跟手预览修复（2026-10-25）：旧实现按 boardKey 取首个区域，可能误取同键的 6 pt 透明插槽；现明确只取 slotPlacement=nil 的完整分组。改用原 ProjectTaskGroup 直接渲染预览，移除 NSHostingView 位图缓存依赖，并按完整分组计算鼠标偏移。编译通过，隔离面板实拖整组重排成功；本地专用测试入口将真实拖动生成的预览内容在松手后展示出来，确认包含项目名、边框和任务，截图 `.local/board-drag-data/actual-group-preview.png`。该测试展示逻辑仅在 .local，不在生产源码。已更新开发版，真实数据未作测试。

- 清单间距收紧（2026-10-25）：全部视图取消顶层重复 4 pt spacing，组间插槽由 10 改为 6 pt，移除分组外部底边 6 pt；组内间距 4→2 pt、顶部 4→2 pt、底部 10→6 pt，任务行纵向内边距 5→3 pt。普通相邻待办中心距约 54→38 pt，保留原控件大小和 8 pt 落点邻近容错。编译通过；隔离原生截图检查组/任务混排与相邻待办，并实际拖动 Free 到两组间成功。证据 `.local/board-drag-data/compact-spacing.png`。已更新开发版，未改真实数据，未重复无关业务测试。

- 项目整组拖动与顶层混排（2026-10-25）：项目标题按住拖动时使用完整可见分组预览，项目连同内部任务一起换位置，内容归属/内部顺序不变；顶层 boardOrder/boardRevision 让项目和未分类根任务交错排序并持久化，项目颜色保持稳定。组间独立插槽显示对应位置亮线，移除全部视图已完成区下方的旧末尾落点，允许任务移出项目并留在两组之间。
- 验证：全量 19 项测试通过；最后边界/CLI 同步调整后 6 项受影响测试通过；扩展后的真实 drag CLI smoke 通过。原生产悬浮面板实拖 Todo-AI 整组到 Kolfit 后，再将 AAA 移到两组之间，UI 与 CLI 的精确顶层顺序及 BBB 保留归属均确认。截图 `.local/board-drag-data/between-projects.png`；已更新开发版，无真实数据测试、无 Git 提交。

- 拖动位置最终修复（2026-10-25）：替代前两次系统拖放方案，改为窗口内直接追踪鼠标，浮动预览卡片跟随位置；按任务行真实边界及可见区域交集计算落点，松手提交。隔离普通原生窗口实际拖动验证精确排序、合并浮窗触发；原生产 FloatingController/TaskPanel 非激活悬浮窗口实际验证首项移至末尾、未分类任务插入已有项目，CLI 核对真实顺序，截图 `.local/drag-source-data/floating-cross-project.png`。3 项 DraggingTests 与编译通过，已更新本机开发版。跨屏、长列表及拖动中 Escape 未逐项实测；没有修改真实待办作为测试数据。本条取代此前拖动不能完整验证的阶段说明。

- 拖动入口修复（2026-10-25）：根据用户“按住不能拖动”反馈，改由标题和留白上的原生 NSView 区分单击与 4 pt 拖动，直接启动 AppKit 拖动会话；结束/取消由 NSDraggingSource 回调清理，移除外层 onDrag/provider 析构逻辑。编译及两项 DraggingTests 通过；隔离普通原生窗口的实际鼠标拖动已观察到系统 began 回调，日志 `.local/drag-source-data/preview.log`。工具未完成系统松手落点/结束回调，不能宣称完整拖放或悬浮面板验收通过。已更新本机开发版，真实数据未作为测试夹具。

- 拖动排序与项目合并（2026-10-25）：实现原生拖动卡片预览、行边缘插入亮线、仅两条未分类任务的中部合并边框/选择浮窗、跨项目同级插入及项目标题/未分类末尾落点。项目可先只填名称，在设置中后绑定目录。手动顺序持久化，分支移动/两条任务合并共用事务校验；空项目按全部未删除任务判断，拒绝版本冲突、循环、超深及非法合并。
- 验证：`swift test` 16 项全通过；原 CLI smoke 与新 drag CLI smoke 通过。隔离原生浮窗实际操作验证取消、新项目确认、现有空项目确认及名称校验（测试入口设置待合并状态）。实际鼠标拖动两次被工具 windowNotFoundAtPosition 阻断，卡片跟手、悬停反馈和拖动触发尚未实测通过；需要用户做一次真实拖放验收。准确范围、证据与最少步骤见[Spec](docs/spec/2026-10-25/task-drag-grouping.md)。未使用真实数据做测试；本项目无 Git 仓库、没有提交。

- 项目展开收起动效（2026-10-25）：0.45 秒 easeInOut 动画改变内容可见高度，保留实际任务视图并裁掉超出区域；边框同步收拢、线宽从 1 pt 变为 2 pt，标题缺口保留。折叠时禁止隐藏内容点击和辅助功能访问，减少动态效果时改为 0.01 秒。编译通过；隔离原生窗口观察到收拢中的边框中间态及最终横线、展开恢复。最后将动画事务提升到点击操作，使邻接布局同步移动；已更新本机开发版。减少动态效果分支未切换系统设置实测，未宣称全部动画帧逐帧验收。

- 项目收起横线（2026-10-25）：收起时边框变为带项目名缺口的 2 pt 横线，去掉左右边和底边及多余底部空间；展开恢复 1 pt 边框。编译及隔离原生收起/重新展开检查通过，截图 `.local/project-group-check/collapsed-line.png`；已更新本机开发版，无任务数据变更。

- 项目框内外任务行对齐（2026-10-25）：项目框横向外扩 10 pt，抵消框内 10 pt 留白，不再压缩任务行；同层勾选框、色条、标题起点和优先级右边缘对齐。编译通过，340 pt 隔离原生窗口多项目与未分类混排截图确认，证据 `.local/project-group-check/aligned-rows.png`。只改布局，未更改数据或运行无关业务测试；已更新本机开发版。无 Git 仓库，无提交。

- 详情自动保存与备注高度（2026-10-25）：备注从单行增长到最高 152 pt（旧高度两倍），超限内部滚动、删减缩回；移除保存更改、读取最新内容及已保存占位。全部详情字段 400 ms 防抖自动保存，离开/退出立即保存；成功静默，失败保留草稿，不同字段并发合并，同字段冲突要求确认。
- 本轮编译及 `swift test --filter AutosaveTests` 的 2 项测试通过，覆盖自动保存、并发合并/冲突、空标题保护、离开保存与取消延迟任务。隔离原生 340 pt 检查空备注/三行/20行上限内部滚动/缩回，CLI 确认修改自动落盘；截图 `.local/autosave-check/max-height.png`。未使用真实数据测试；仍无 Git 仓库。

- 详情页提醒事项视觉调整（2026-10-25）：只借鉴用户截图样式，不增加功能。标题与备注合为圆角组，标题可换行；现有状态/优先级/颜色/截止改为图标、名称、右侧原生选择器的横向行，附件/子任务/移动/回收站操作统一圆角分组、中性底色及细分隔线。保留原业务接口、草稿、冲突恢复和保存机制；清单样式未改。该边界已写入 AGENTS 与用户记忆补充。
- 本轮验证：`swift build --product TodoAI` 通过；隔离数据原生深色 340/430 pt 截图检查、中文标题与备注编辑、⌘S 保存、截止切换具体时间、底部操作及滚动条滚动可达、重启读取与真实 CLI 核对已通过。证据 `.local/detail-style-check/detail-340.png`、`detail-bottom-340.png`、`detail-430.png`。工具定向滚轮返回 windowNotFoundAtPosition，改为原生滚动条设置位置成功；不声称物理滚轮测试通过。浅色模式未实机验证，未重跑无关业务/附件流程。没有写入真实任务或新增系统设置；已正常退出旧开发版、替换构建并重新打开现有任务详情确认新版生效。目录仍无 Git 仓库，无提交。

- 全部项目分组与优先级（2026-10-25）：仅全部范围按项目用 1 pt 彩色透明框分组，项目名称 9 pt（从 13 pt 缩小约 30%）嵌在顶边真实缺口，无展开箭头，点击名称折叠/展开并保存偏好。没有未删除任务的项目隐藏；仅已完成任务仍保留。未分类任务直接展示，无边框和标题。优先级改为一般/比较紧急/紧急，绿/黄/红圆角背景白字，详情和右键选项同步，底层 low/medium/high 和默认 medium 保持兼容。
- 本轮 `swift build --product TodoAI` 通过；340 pt 隔离原生窗口确认最终标题、断线边框、空项目隐藏、未分类无框和三色标签；标题收起/恢复、单项目无框、详情新名称已实测。截图保存在本地 `.local/project-group-check/expanded.png`。深色环境实测，浅色分支仅代码检查，未宣称实机通过；未重复无关数据测试。未修改真实任务数据，开发版已替换为新构建；仓库仍未初始化，无 Git 提交。

- 页面样式统一（2026-10-25）：按用户要求以待办详情为基准，将 13 pt 正文、小尺寸 bordered 按钮和中性 tint 提升为根视图默认，移除全局绿色强调色；设置页同步圆角输入框、13 pt 小节标题、14/12 pt 内容边距与紧凑分组，回收站同步按钮和边距。保留保存蓝色、删除红色、任务颜色与反馈语义色。`swift build --product TodoAI` 通过；隔离数据下实测 430 pt 设置/详情/回收站和 340 pt 设置页上下滚动，按钮不再呈绿色，内容无横向裁切。没有修改真实待办数据；未新增业务逻辑或重复运行无关数据测试。
- 本次更新开发应用时，直接覆盖已运行过的可执行文件后启动退出 137；改为复制到临时文件并重命名替换后成功启动。`scripts/run.sh` 同步采用该替换方式，未增加签名、公证或系统设置操作。实际用户开发版已打开新版设置页。

- KF 协作规范补齐（2026-10-25）：参考 make-a-book 的 KF 条款，明确新会话默认 GPT-6 Astra / 中度推理（创建参数 `model: gpt-6-astra`、`thinking: medium`），用户临时指定优先，并要求核验实际配置。融合固定交接开头、独立开发、不递归派发、完整交付标准、持续执行及阻断证据要求。GOAL、合并、推送和发布仍遵循 Todo-AI 自身授权，不继承参考项目的授权。已核对当前创建工具支持上述模型和参数；本次仅维护文档，没有创建新会话、启动 GOAL 或修改全局配置。

- 添加区顶部留白与加号修正（2026-10-25）：已将“容器顶部留白紧凑，不得用过大固定高度/底对齐/空占位制造空白”明确写入 AGENTS。添加区由 88 pt 底对齐改为 72 pt 紧凑布局、顶部 6 pt；加号图标改为 26 pt（原约 13 pt 的两倍），点击区 44×44 pt。编译通过；独立 340 pt 窗口中已检查展开/收起视觉、输入行与加号对齐，以及点击加号创建成功后收起。未改动像素鱼缸探索或真实待办。

- 像素鱼缸探索（2026-10-25）：完成[独立动效原型](docs/prototypes/pixel-aquarium/README.md)与[Spec](docs/spec/2026-10-25/pixel-aquarium.md)。已确认只奖励顶层 Todo、统计全部层级后代、同一任务只奖励一次且重开保留鱼、寿命按自然时间。生成三种背景、六种鱼与三种前景水草/软珊瑚；预览包含鱼摆尾/游动/转向、水面波动/光纹、水草摇曳、入缸和到期淡出。浏览器已验证三档触发、重开不重复、切景、尺寸、六天到期、暂停及 320 px 窄屏；规则边界与换算检查通过。仅独立原型，尚未接入原生应用或真实待办，真实鱼种寿命与部分产品边界待讨论。

- 添加入口与空状态调整（2026-10-25）：默认仅右下角加号，约 0.42 秒从按钮向左/上展开，反向收起；去掉输入区叉按钮，点击区域外或面板失去键盘焦点时收起，保留本次运行中的标题和归属草稿，成功后清空缩回、失败保持展开。新增子任务复用同一入口。空状态标题 14 pt、说明 12 pt，在可用清单区域居中。隔离原生 UI 已检查展开/收起、连续动效截图、区域外工具栏与焦点切换、草稿重开、项目菜单、子任务归属及失败保留；普通空白处的坐标点击仍受工具定位限制。

- 缩放光标方向调整（2026-10-25）：三个非锚定角改为对应轴的双向箭头，宽度角左右、高度角上下、对角随展开方向切换两种斜向，不再使用十字光标。macOS 15+ 使用系统 frame resize 光标，macOS 14 使用兼容斜箭头；编译通过，已渲染并检查四种锚点 × 三个角共 12 种组合和两种兼容图像。保留原缩放几何与无常驻图标设计。

- 全应用细滚动条（2026-10-25）：在原生宿主层统一应用 3 pt 滑块绘制，覆盖纵横滚动条和嵌套描述编辑框，去掉粗轨道并保留原生命中区域/滚动机制。构建通过；隔离实例已截图检查清单、详情、描述框、设置及回收站，并验证设置/描述滚动与回收站滚动条翻页。原生坐标拖动测试仍受工具定位限制，不报告物理拖动验收通过。

- 详情页布局与配色调整（2026-10-25）：根任务不再渲染空父级路径，缩短标题上方留白；四个属性采用两列布局，统一标签、内容边距与描述区。普通按钮使用中性色，待保存主操作为蓝色，删除为红色，“已保存”为次级文字。`swift build` 通过，隔离原生 UI 验证 430/340 点宽度、子任务路径、修改前后按钮状态和 ⌘S 保存正常；未修改用户正在运行的实例或真实数据。

- 悬浮球遮挡修复（2026-10-25）：球固定高于面板一个窗口层级，点击编辑、打开设置或重新展开面板不会盖住球。构建通过；隔离实例中在启动、设置、输入框聚焦、取消/恢复置顶与收起再展开后，窗口服务器均记录球在面板前方（球层级 4，面板 3 或 0）。

- 界面跟进完成（2026-10-25）：收紧顶部项目选择器和任务行左侧留白，底部文字统一 13 pt，移除三角常驻图标但保留缩放命中区；操作提示统一为底部上滑的绿/红/黄覆盖浮层，3 秒自动关闭、右侧叉按钮可手动关闭，新提示重新计时。确认对话框不受影响。
- 真实隔离 UI 验证：空/有任务布局与字号、无角落图标、三色提示、自动消失和手动关闭（0.912 秒内）均观察到；出现/消失前后底栏分隔线保持相同位置。提示验证中同时修复任务从已完成分组迁回待办时的旧行状态，父子重新打开后显示一致。`swift build` 通过；用户正在运行的原实例与真实数据未修改，重新运行启动脚本加载新构建。

- Swift Package，macOS 14 目标，SwiftUI + AppKit + 系统 SQLite，无第三方运行依赖。
- 项目目录绑定、嵌套最长匹配、worktree 额外绑定、失效路径重绑、未分类与全部范围。
- 最多十层任务、分支移动、父子状态规则、优先级/色条/日期/具体时间、稳定 ID 与来源、可恢复删除。
- 多行描述、图片缩略图、视频文件信息、文件选择/图片粘贴/拖入附件；托管副本，100 MB 上限，软删除与恢复。
- 独立球/面板、展开收起、拖动、固定锚点三角约束缩放、置顶、背景透明、系统锁定穿透、右键/菜单栏恢复入口、窗口偏好保存。
- 共享事务校验、SQLite WAL、revision 冲突保护、创建幂等键、CLI JSON/错误结构、外部更新刷新与草稿保护。
- 项目内 [todo-ai Skill](Skills/next-one/SKILL.md) 与 [可选持续规则](docs/codex-rules-snippet.md)，未安装全局内容。

## 已验证

- `swift test`：9 组、0 失败；路径、层级、循环、跨项目移动、父子状态、事务回滚、并发、幂等、附件恢复与窗口几何。
- `python3 scripts/cli-smoke.py`：真实 CLI 子进程通过，覆盖 JSON、失败退出、版本竞争、文本保留和幂等。
- Skill frontmatter/命名/链接检查通过；当前真实 Codex 会话显式读取 Skill 后，读取绑定项目、创建当前/后续工作、局部更新完成状态，并看到 UI 同步。
- 原生 UI 成功创建英文/中文待办；CLI 更新无需重启可见；应用关闭期间写入，重启可见。
- UI 草稿与 CLI 并发时拒绝旧版本保存，保留草稿；确认重新读取后保留 CLI 的新描述。
- 340×480 点窄面板可打开第十层详情，完整父级路径可见；分支展开/收起与详情返回保留滚动位置实测通过。
- PNG/MP4 真文件导入后移动源目录，副本保留；PNG 已在系统 Preview 打开。
- 球菜单锁定、锁定下收起/展开保留状态、设置先解锁；球拖动更新位置且不误触单击；背景不透明度由 90% 调到 76% 并跨重启保留。

## 未验证 / 待补验

- 最终三个非锚定角的全套缩放、置顶后与普通应用切换的整屏可见性。
- 锁定后点击、滚轮等由背后实际应用收到：当前工具按应用定向操作且移动后坐标定位失败，不能作为系统真实穿透证明。
- 视频实际播放、图片粘贴与拖放的完整交互；QuickTime 工具连续两次超时。
- 双屏在线环境已记录；未拔屏/改分辨率，未测试 Spaces、全屏、Stage Manager。
- 未额外创建新 Codex 会话，未验证安装后的自动发现/持续工作规则触发。

## 本地交付与边界

- `./scripts/run.sh` 可构建并启动本机开发应用；`.build/TodoAI.app` 可重复生成，不是签名公证分发包。
- 默认数据在 Application Support/Todo-AI；所有验收使用 `.local/acceptance` 或临时目录。未改变真实清单。
- 采用 KF 已授权的建议默认值，具体记录于 Spec 第 13 节；删除内容无限保留，不自动清理。
- 当前目录仍未初始化 Git：没有 worktree、提交、合并或推送；没有远程仓库配置。
- 没有修改全局 Skill、Codex 配置、登录启动、权限或显示系统设置。下一步按验收报告的最小人工步骤补齐剩余实机证据。

## Codex 持续规则、Skill 更新与新会话验证（2026-10-26）

- 按用户授权在独立 `codex/codex-skill-lifecycle` worktree 实施；[Spec](docs/spec/2026-10-26/codex-skill-lifecycle.md)与[验收报告](docs/acceptance/codex-skill-lifecycle.md)。没有委派开发、创建 sidebar chat 或修改真实全局配置。
- 新增原生 CLI integration install/status/uninstall：安装用户级稳定 Skill 入口和固定数据 runner，在当前生效 Codex AGENTS 文件添加专属持续规则，备份并保留其他内容；未知旧 Skill、人工修改和不同数据绑定不静默覆盖。卸载保留 USER.md 与任务，支持重新安装。
- 应用现有 current 原子切换承担升级：首次授权连接后，启动新版应用即可让新任务读取新 Skill/CLI，不每次写全局配置；个人偏好放 USER.md。四语设置安装/更新指令、Skill/接口/模块文档与四语 README 已同步。
- 验证：debug/release 全量各 35 项、CLI smoke、Skill quick_validate 通过。实际原生设置文案与路径正确；实际应用升级切换 current 后，连接入口、run、专属规则及 USER.md 哈希不变。
- 三个真实 GPT-6 Astra / medium 的 Codex CLI 新会话（使用隔离 profile 与测试项目）分别验证主动记录开发并完成、后续读取接续不重复原任务、纯讨论不新增/修改待办；核对 CLI 调用、7 项实际 Node 测试和任务快照。系统旧 CLI 被模型服务拒绝后改用已安装的应用内新版 CLI，没有降级模型。完整证据与测试范围见验收报告。
- 本轮产物为 0.1.0 build 4 本机试装包 `Todo-AI-0.1.0-local-managed-skill-arm64-4600a54.dmg`，已复制到主仓库 `.local/releases/`，保留独立 Release 数据。最终包 CRC/SHA-256、完整资源与复制启动后的安装/状态/幂等/卸载检查通过。仍未签名/公证/对外发布；真实用户环境需发送新版安装/更新指令后新开会话验证，不能把隔离验收当作用户已安装。

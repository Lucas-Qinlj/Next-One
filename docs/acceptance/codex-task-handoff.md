# B9 本地实现验收记录

- 日期：2026-10-27
- Spec：[codex-task-handoff](../spec/2026-10-27/codex-task-handoff.md)
- 状态：本地实现完成；自动检查和标准测试窗口交互通过；尚未全部实机验收。

## 实现

- Core 只读读取 Codex projects/project_roots；处理绝对 CODEX_HOME、结构不兼容、读取失败和真实空列表，不读取会话/凭据，不写数据库。
- 原生菜单第一行“创建 Codex 会话”，灰色 ChatGPT Logo 和分隔线；原有选项顺序保留。
- 按 Spec 匹配路径、选择已有项目/目录；指令可为空、Shift+Enter 换行、Escape 取消；失败/重选保留输入。
- 提交前复核目标和最新任务/附件；纯文本 neo 包装、独立 URL 编码，用户指令原样追加；只打开，不发送、不改状态。
- 仓库 Skill 新增任务交接识别；四语资源、打包资源和模块说明同步。

## 自动与只读检查

1. `swift test`：全量 65 项通过（在补充最后一个附件测试前运行）。
2. 合并前 `swift test --filter 'CodexHandoffTests|LocalizationTests|ScrollbarLayoutTests'`：14 项通过，其中 8 项交接测试，覆盖：
   - 缺失数据库不创建、schema 不兼容、空列表、多路径、同名与精确/符号链接匹配；
   - 活动 WAL 的已提交数据、数据库忙碌失败、读前后主库字节不变；
   - 特殊字符/换行/加号 URL 往返、无默认指令、无 UUID、不同原路径/目标路径；
   - 最新任务标题、目标变化、任务删除、附件持久化路径/缺失、失败草稿保留、取消阻止 opener；
   - 单/多源路径、未匹配回退、合成 Enter/Shift+Enter/marked text/Escape、Logo 资源加载。
3. 整合 main 最新常显滚动条修改后，同一筛选共 15 项通过（新增的滚动条检查也通过）。`swift build -c release` 通过。
4. `scripts/package-app.sh debug .local/handoff-delivery/NextOne.app` 通过；应用/核心资源 bundle、Logo、更新 Skill 均携带。
5. `skill-creator/scripts/quick_validate.py Skills/next-one` 通过。这是结构检查，不是新模型会话行为验证。
6. 用新 Core 代码实际只读核对用户 Codex 数据：66 个项目、67 条目录，Next One 精确匹配 true；不修改真实数据、不输出完整列表。

## 原生交互证据

先尝试隔离的实际悬浮应用，电脑工具只能定位悬浮球，无法定位清单面板，未将其视为通过。随后用独立 bundle ID 的标准 NSWindow 测试宿主承载**同一生产 ContentView/Session/Editor**，使用一次性 Next One 存储和 Codex 项目夹具，完成：

- 深色/浅色截图确认菜单首行、灰色 Blossom、分隔线及旧选项顺序。
- 菜单触发后先选项目，再出现指令框，焦点自动进入编辑器。
- 实际输入“第一行”，Shift+Enter，再输入“第二行”；AX 确认两行且未提交。
- Escape 返回列表。
- 在指令框打开后移除测试目标目录记录，空输入 Enter 触发重新核对并显示“Codex 项目目录已变化，请重新选择”，未调用 Codex 打开。
- 输入补充指令后重新选择其他项目，AX 确认原指令仍在。

截图与 AX 结果保留在当前开发聊天工具输出。测试宿主强制外观仅影响测试进程，没有修改系统主题。已退出测试实例。测试宿主不等同于浮动 NSPanel 实机验收，合成 marked text 不等同于真实中文输入法候选测试。

## AC 对照与未完成项

| 项目 | 状态 |
| --- | --- |
| AC01 菜单/选择顺序 | 标准窗口实测通过；真实悬浮面板待复测 |
| AC02 按键/输入法 | 标准窗口 Shift+Enter、Escape、空 Enter 失败路径通过；真实中文候选及成功打开待补 |
| AC03–AC05 读取/匹配/归属 | 夹具与新代码真实只读查询通过；生产完整跳转待补 |
| AC06–AC07 文本契约 | 自动检查通过 |
| AC08 附件 | 图片记录持久化路径/缺失自动检查通过；格式组装不依赖文件类型。既有导入仅接受图片/视频，未新增普通文件导入；真实视频路径交接未单独实测 |
| AC09 唤起/预填/焦点 | 本轮未自动操作 Codex。此前用户两行深链接实测见预验证记录，不冒充完整消息、冷启动和焦点验收 |
| AC10 错误/取消/状态 | 自动检查、实际失效目标与草稿保留通过；成功打开只表示系统接收 URL，不报告持久化会话完成 |
| AC11 新会话 Skill | 仓库 Skill 已更新并结构检查；全局安装和独立新会话验证未执行 |
| AC12 样式/本地化 | 四语资源测试、滚动条回归和标准窗口深浅样式通过；其余平台组合不扩大声称 |

Codex UI 自动化此前明确被工具拒绝：`Computer Use is not allowed to use the app 'com.openai.codex' for safety reasons.` 本轮没有用其他自动化或数据修改绕过。最少人工补验是使用待安装版本右键打开一个已存在项目，检查完整 neo 内容、附件路径及焦点，并在用户授权更新 Skill 后验证真实新会话读取；冷启动应在不打断现有工作时做。

## Git 与交付范围

本轮在独立 worktree 实现并提交。初次合并检查遇到 main 的另一轮未提交修改；待其独立提交后合并主分支，保留双方状态记录及滚动条修复，最终受影响的 15 项测试和开发包构建通过，再安全合并回 main；未推送、未安装替换现用应用、未安装全局 Skill、未签名公证或发布。B9 保留进行中，避免把待人工验收当作全部完成。

本地构建日志和生产开发包保存到主仓库 `.local/codex-handoff-acceptance/`，不提交生成产物。此前调研见[预验证记录](codex-task-handoff-preflight.md)。

## 安装交付补充（2026-10-27 02:53）

用户随后授权推送并替换现用应用，由用户验收。基于 d767193 的 release 构建已安装并启动，代码已推送 origin/main；所有文件与构建一致，启动后任务、项目、回收站、附件与语言/同步/窗口偏好一致。旧应用及完整数据备份在 `.local/backups/before-codex-handoff-20261027-025102/`，日志在 `.local/codex-handoff-install/verification.txt`。沿用原本本地构建身份，不声称正式签名公证。全局 Skill 未改；产品包与 integration/current 的上游 Skill 已更新，不能据此宣称现有静态全局副本自动更新。功能验收仍等用户结果。

## C3 输入框焦点对照（2026-10-27 03:09）

本轮仅验证无新增权限的窗口交接方案，尚未修改或替换产品。用户依次反馈：直接点击深链接能输入 x；普通 NSWindow 测试工具的先打开后关闭（A）、先关闭后打开（B）均能输入 x；真实 Next One 右键交接后无法直接输入。上述均为用户手动观察，不是自动化焦点读回，也未发送测试消息。

代码核对发现真实窗口使用 accessory 应用、borderless/nonactivatingPanel、floating 层级及主动获取焦点的 NSTextView，与普通窗口实验不同。普通窗口 A/B 不能排除真实面板的关闭时序问题。已编译并打开 `.local/codex-focus-probe/C3 Panel Probe.app`，采用相同关键窗口属性并复用生产输入框实现，继续比较两种顺序；该工具仍不是完整生产流程，结果待用户反馈。工具仅预填固定测试文字，不读取待办、不请求辅助功能权限。

Codex UI 观察仍被 Computer Use 明确拒绝，未绕过；最终输入焦点需要用户观察。根因和修复均未确认，冷启动、跨 Spaces 等尚未验证。

后续用户确认：非激活悬浮面板 A/B 均无法直接输入 x，实验已复现真实问题；在该实验条件下仅改变关闭顺序无效。下一项 C 保持相同面板及输入框，sheet 的 onDismiss 后调用宿主面板 makeFirstResponder(nil)、resignKey()，然后打开相同深链接。C 工具编译通过并已打开，结果待用户反馈；不将候选处理写为修复成功。

用户随后反馈 C 仍无法输入 x。结论：本轮已测试的“调整 sheet 关闭顺序”及“关闭后 makeFirstResponder(nil) + resignKey()”均未解决非激活面板交接问题。停止本轮交互探针验证，保留负面结果；不将普通窗口成功推广为产品成功，也不能据此断言所有无权限方案均不可能。正式应用未修改或替换，未发送测试消息、未授予新权限。冷启动及跨 Spaces 未测试。

用户明确授权继续验证隐藏面板方案。新增 D 隔离实验：沿用 C 的非激活面板和生产输入框，在 sheet onDismiss 中以 orderOut(nil) 替代 makeFirstResponder(nil)/resignKey()，随后调用 NSWorkspace.open；打开失败则恢复面板。无额外激活、延时或权限，成功打开后不自动重新显示面板，以单独验证隐藏的作用。`.local/codex-focus-probe/C3 Hide Panel Probe.app` 编译通过且窗口已打开；实际输入结果待用户反馈。正式应用未变更。

## C3 正式接入（2026-10-27 03:22）

本地验收包：`.local/releases/c3-focus-20261027/Next One.app`；release 构建、两份 SwiftPM 资源 bundle、随包 Skill、CLI --help 校验通过，日志 tests.log/build.log/verification.txt 在同目录。未安装替换或正式签名公证；先退出正在运行的正式版再由用户打开此包，避免两个 UI 访问同一 release 数据目录。用户验收：从真实待办打开 Codex，清单收起但球保留，不点输入框能直接输入；指令不自动发送；点球可重开清单。最终焦点、冷启动、跨 Spaces 均不提前标通过。

用户确认 D 可直接输入 x，随后授权修改正式实现、由用户验收。实现采用先校验、关闭 sheet、onDismiss 隐藏清单、打开 URL；保留球，成功不自动展开，系统拒绝 URL 时恢复清单和同一草稿。9 项 CodexHandoffTests 通过，新增生产 FloatingController 的面板隐藏／球可见／失败恢复／重试成功／重复回调／重新展开检查；这些使用注入 opener，不发送消息，不代表 Codex 焦点验收。真实流程与冷启动、Spaces 待用户验证。

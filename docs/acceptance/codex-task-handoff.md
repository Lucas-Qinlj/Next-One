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

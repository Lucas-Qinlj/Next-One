# B9 Codex 接口预验证

- 日期：2026-10-27
- 状态：官方契约和本机协议核对完成；用户手动验证已有项目切换与两行文本预填。无项目聊天及完整功能仍未验收。
- 关联：[Spec](../spec/2026-10-27/codex-task-handoff.md)
- 本轮授权：提前验证接口；不开发产品、不发送测试消息、不启动 Agent 任务、不修改 Codex 配置或私有数据库。

## 结果

| 能力 | 证据 | 结论 |
| --- | --- | --- |
| 打开新页面并预填 | 官方 deep-links 文档列出 threads/new、prompt、path | 用户截图确认测试文本及换行预填；完整消息仍待测 |
| 自动发送 | 官方明确 prompt 只预填 | 深链接不支持自动发送，符合首版用户手动发送方案 |
| 项目路径 | 官方 path 为本机绝对目录 | 用户从其他项目点击带 path 入口后返回 Next One；此已有项目切换通过 |
| 无项目聊天 | 文档未提供明确的 projectless 查询参数 | 用户从其他项目点击不带 path 入口仍在原项目；不能用省略 path 实现无项目聊天 |
| 原生应用读取桌面项目列表 | 本机 CLI 0.144.1 的 experimental ClientRequest Schema 共 122 个请求方法，未发现项目/工作目录列表方法 | 已检查接口中未找到；不代表所有其他接口都不存在 |
| 自动创建/运行协议 | Schema 有 thread/start 和 turn/start；前者有 cwd/runtimeWorkspaceRoots 等字段，无 projectId | 协议存在，不等于桌面项目归属与页面导航支持；本轮未调用 |
| Codex 桌面 UI 读取与验证 | cua.getApp('com.openai.codex') 返回明确拒绝 | 无法自动观察页面、输入框、焦点，不绕过限制 |

工具原文：`Computer Use is not allowed to use the app 'com.openai.codex' for safety reasons.`

没有用 shell、AppleScript、其他 UI 自动化或私有应用状态读取绕过此限制。Agent 未发送深链接或创建测试会话，未退出/重启用户的 Codex 应用。后续由用户手动点击入口并提供截图，见下文。

## 可复现的只读检查

```sh
codex --version
codex app --help
codex app-server --help
codex app-server generate-json-schema --experimental --out .local/codex-handoff-probe/schema
```

本次输出版本为 `codex-cli 0.144.1`。Schema 为本机 CLI 版本，不假定与桌面应用版本完全一致。

本地检查产物：`.local/codex-handoff-probe/schema/` 及 `.local/codex-handoff-probe/method-inventory.json`（不提交生成文件）。检查 `ClientRequest.json` 方法枚举以及 `v2/ThreadStartParams.json`、`v2/TurnStartParams.json`。

- 请求列表有 `account/workspaceMessages/read`，它是账号工作区消息，不是桌面项目列表。
- `config/read` 为配置读取，不等于桌面项目列表；未据此读取用户配置或把信任目录当项目列表。
- 未连接 app-server、不调用模型；生成 schema 不启动常驻服务。

## 最小人工验证

在当前已打开项目聊天时，依次手动打开以下链接对应的 URL（所有测试内容均为无敏感占位文本，勿点击发送）：

1. `codex://threads/new?prompt=B9%20interface%20probe%0Aline%202`：观察是否进入新页面、预填两行，以及目标是“聊天”还是沿用当前项目。
2. 相同 URL 追加 `&path=` 和当前已存在的项目目录编码：观察是否选择准确项目，文本是否完整、页面是否停留在新页面。
3. 补充中文、`<neo>`、`&` 和附件路径文本的 URL 编码检查；未指定 path 时将未匹配目录放在 prompt 正文，确认不新增项目。
4. 在不会打断现有工作的条件下再验证应用未运行的唤起场景；本轮不要求退出应用。

前两项已由用户手动执行，结果见下文；第 3、4 项仍待测。不能据此声称已解决原生应用枚举项目列表的问题。

## 2026-10-27 用户实测补充

证据来源：当前聊天用户明确反馈和截图，不是 Agent 自动化测试。初次两个入口均显示 Next One；随后用户切到其他项目做对照：

- 带 Todo-AI 目录 path 的第二入口返回 Next One，截图显示 Next One／此计算机。
- 不带 path 的第一入口仍在另一个项目，截图显示 customer-acquisition／此计算机。
- 两张截图均显示输入框中的 `B9 interface probe` 和下一行 `line 2`。

结论：当前安装环境支持显式 path 切换到已有 Next One 项目，并支持这段两行文本预填；省略 path 会沿用当前项目，不能实现 Spec 的无项目“聊天”。截图仅证明输入框预填与显示的项目，不证明消息已发送、任务已执行或持久化会话已创建。不推断未知目录行为、冷启动、全量附件文本或所有项目均已通过。

## 下一步与决策边界

优先解决无项目聊天的明确入口，再补齐完整消息与冷启动观察。项目列表外部接口仍是实现前的独立待决技术问题；若没有受支持来源，应向用户提出替代方案，不私自删除项目选择、不自动增加项目、不擅自读取桌面私有数据库作为正式依赖。

## 官方资料

- [Deep links](https://learn.chatgpt.com/docs/reference/commands#deep-links)：新会话、prompt/path 参数及不自动发送的说明。
- [Codex App Server](https://learn.chatgpt.com/docs/app-server)：thread/start、turn/start、config/read 的职责。

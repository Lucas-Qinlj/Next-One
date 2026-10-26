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
| 无项目聊天 | 文档未提供明确的 projectless 查询参数 | 用户从其他项目点击不带 path 入口仍在原项目；省略 path 和显式空 path 均未实现无项目聊天 |
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
- 用户随后测试显式 `path=`，明确反馈仍不行；不将空字符串作为清除项目的方案。
- 两张截图均显示输入框中的 `B9 interface probe` 和下一行 `line 2`。

结论：当前安装环境支持显式 path 切换到已有 Next One 项目，并支持这段两行文本预填；省略 path 会沿用当前项目，不能实现 Spec 的无项目“聊天”。截图仅证明输入框预填与显示的项目，不证明消息已发送、任务已执行或持久化会话已创建。不推断未知目录行为、冷启动、全量附件文本或所有项目均已通过。

## 无项目入口专项调研

用户明确授权一个子代理进行只读调研。结论限于检查过的官方文档与公开仓库，不宣称任何版本都不存在其他入口。

- 官方 [Open Source](https://learn.chatgpt.com/docs/open-source) 列出 CLI、SDK、App Server 等组件；不能把这些开源组件等同于桌面应用完整 UI/路由源码。
- 官方 [Commands](https://learn.chatgpt.com/docs/reference/commands#keyboard-shortcuts) 提供 New standalone chat 的 macOS 快捷键 `⌘⌥O`；这是人工界面入口，不是本项目可直接调用的公开 URL。
- Deep links 文档只列 prompt/path/originUrl，未声明 standalone/projectless 参数；结合用户实测，省略或留空 path 都不能满足需求。
- 子代理检查官方仓库 commit `c21153bd920a514809e58d9bd10326267ab2ca36`：[mac.rs 第 151–156 行](https://github.com/openai/codex/blob/c21153bd920a514809e58d9bd10326267ab2ca36/codex-rs/cli/src/desktop_app/mac.rs#L151) 只构造带 path 的 `codex://threads/new` URL；[app_cmd.rs](https://github.com/openai/codex/blob/c21153bd920a514809e58d9bd10326267ab2ca36/codex-rs/cli/src/app_cmd.rs#L5-L19) 的 PATH 默认为当前目录，并规范化后打开。这不是桌面 URL 接收器，不能据此推导隐藏清除参数。
- 本次公开源码检索没有找到桌面深链接接收/路由实现；没有得到可推荐给 Next One 原生应用的 projectless+prompt 外部入口。

建议保持无项目功能为接口阻塞，不降低验收。可选替代需用户决定：由用户手动打开独立聊天并粘贴上下文，或首版暂不提供“聊天”选项。两者均未被本轮自动采纳；不模拟快捷键绕过 Codex UI 工具限制，不把 App Server cwd 为空当作无项目桌面会话的证明。

## 用户授权的本地项目数据只读验证

2026-10-27 用户明确要求调查直接读取 Codex 配置/数据库的可行性。本轮仅提取项目相关结构与字段，不读聊天正文、凭据或附件，不修改 Codex 数据；这不是绕过 UI 访问限制来操控界面。

发现并实际读取：

- Codex 数据目录下 `state_5.sqlite`：`projects` 包含 id/name/position 等，`project_roots` 包含 project_id/position/path。
- `.codex-global-state.json`：`local-projects` 包含 id/name/rootPaths/createdAt/updatedAt。
- 数据库有 66 个项目、67 条项目目录，1 个项目有多个目录；读取时这些目录都存在。
- 两个来源的“名称+路径”集合完全相同。ID 不同；全局状态中另有按 host 保存的新旧项目 ID 映射。不得混用两套 ID，或假设它们是同一接口标识。
- 数据库查询准确命中本项目：名称 Next One，目录为本仓库根目录。只在本文记录必要样例，不导出完整个人项目清单。
- config.toml 有 127 个 projects 配置段，数量不同；配置中的项目设置/信任目录不能冒充桌面项目列表。

实际查询使用 SQLite URI `mode=ro`，并设置 `PRAGMA query_only=ON`：

```sql
SELECT p.id, p.name, r.path
FROM projects p
LEFT JOIN project_roots r ON r.project_id = p.id
ORDER BY p.position, r.position;
```

结论：当前本机版本的项目名称/目录可以只读获取，第二项已从“未找到数据来源”推进为“本机来源验证通过”。这不是稳定公共 API，也不是已实现 Next One 产品接入。

建议实施时对数据库做窄范围只读适配：识别所需表/列后读取项目和目录，保留一项目多路径，使用 SQLite 正常处理 WAL，不单独复制主库、不用 immutable 模式读取活动数据库。无权限、忙碌、格式变化时明确失败并允许重试，不静默返回空列表或拿历史 cwd 顶替。路径用于深链接匹配，不需要把内部项目 ID 传到 Codex。文件名/Schema 可能随版本变化，不能承诺跨版本稳定；不新增常驻监听服务。

JSON 可作为经验证的另一只读来源，但当前观察不足以证明它与数据库在所有时刻都同步；不自动合并两份列表。最终数据源选择与兼容策略在实施时记录。用户授权的是本轮调查读取，未在本轮编写产品读取代码。

## 下一步与决策边界

优先解决无项目聊天的明确入口，再补齐完整消息与冷启动观察。项目列表已有用户授权验证过的本机只读来源；若将其作为正式依赖，须明确其内部格式兼容限制。不私自删除项目选择、不自动增加项目或修改 Codex 数据。

## 官方资料

- [Deep links](https://learn.chatgpt.com/docs/reference/commands#deep-links)：新会话、prompt/path 参数及不自动发送的说明。
- [Codex App Server](https://learn.chatgpt.com/docs/app-server)：thread/start、turn/start、config/read 的职责。

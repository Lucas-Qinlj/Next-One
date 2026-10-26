# todo-core

`Store.execute` 是 UI/CLI 共用入口；参数白名单、项目归属、十层/循环、状态、日期、附件、版本和幂等检查均在此实现。`snapshot` 供 UI 只读刷新；`Models` 定义项目、任务与附件；`WindowGeometry` 只处理固定锚点与可见区域几何。

SQLite v1 使用一个 Codable 状态快照，`BEGIN IMMEDIATE` 串行读改写、WAL、FULL 同步和五秒忙等待。一个 Store 内使用锁，不同进程由 SQLite 协调。任务更新要求预期 revision；创建请求键连同参数指纹和首次结果原子保存。未知较新 schema 拒绝打开，不自动降级或清空。

分支移动、级联完成、祖先重开、删除/恢复均为事务。恢复按删除组处理，不恢复之前已独立删除的后代。附件先复制并同步文件，再提交记录，失败回滚并清理本次副本；进程中断留下的无引用文件不自动删除。附件软删除与任务回收站均长期保留。

数据默认由 TodoCore 编译配置决定：debug 使用 Application Support/Next-One，release 使用 Application Support/Next-One-Release（Package.swift 的 TODO_AI_DISTRIBUTION）。同构建的应用与 CLI 一致，复制后的 CLI 不依赖所在位置。`NEXT_ONE_HOME` 优先覆盖；不自动迁移或删除旧目录。当前全量快照适合个人清单，读改写成本随总任务、请求历史增长；需要大量数据时再引入规范化表和迁移。目录为本机用户私有，不监听端口，不提供远程接口。

验证：根目录 `swift test`，实际 CLI 进程验证用 `python3 scripts/cli-smoke.py`。不要用真实待办做失败路径测试。

拖动接口：`place` 在同一事务复用 `move` 校验并为目标同级/同完成分区写入可选 `sortOrder`；旧快照缺省 nil，保持原排序。`group` 验证两个未分类且非祖先后代的任务及其版本，检查空项目或创建无目录项目后原子移动两个分支。`project create` 允许 paths 为空；后续绑定继续走原路径校验。新增针对性测试见 DraggingTests.swift，真实命令验证 `python3 scripts/drag-cli-smoke.py`。

`Snapshot.boardKeys` 是全部项目视图的统一顶层顺序，兼容可选 boardOrder/boardRevision；过滤空项目、已删除或非根任务、已完成未分类任务，并为新对象补默认位置。`board place` 在事务中重排整组或整支移出项目后插入，带源对象版本和顶层顺序版本；项目数组本身不重排，因此 UI 项目颜色稳定。`board list` 供 CLI 获取当前顺序与版本。

`project unbind` 校验项目 revision 及已绑定路径，仅删除项目 paths 中的对应项，不触碰文件系统和任务；允许最后一条路径解除。ProjectUnbindTests 覆盖文件/任务保留、路径不存在、版本冲突、最后一条解除及后续重绑。


本地化：`LocalizedText` 分离文案模板与插值参数，`Localization` 使用本地 `.strings` 资源输出中/英/日/韩文；只改变展示，不参与 Store 数据更新。`TodoError.localizedText` 供 UI 翻译，`message` / `errorDescription` 保留原中文契约，系统生成的动态错误使用 `verbatim:`。位置参数一次性从原模板替换，用户内容中的 `%1$@` 等文本不会被再次替换。

品牌路径兼容：默认目录为 Next-One / Next-One-Release。新路径不存在时可链接至同渠道旧目录，保留同一数据库，不复制 live WAL；已有新目录优先，不跨渠道导入。显式 Store(directory:) 与环境变量指定目录不创建兼容链接。NEXT_ONE_HOME 优先于旧 TODO_AI_HOME。DataDirectoryTests 覆盖链接复用、双入口一致性、附件/偏好及异常保护。

## 全局任务短编号

存储版本 2 为所有任务持久化 `shortCode`，`nextTaskNumber` 在 `BEGIN IMMEDIATE` 内原子递增。`Snapshot.taskCode` 用双射 26 进制字母和 1–9 末位编码；旧库初始化时按创建时间/UUID 为所有任务（含回收站）补号，不修改用户字段与 revision。版本在事务内再次检查，避免并发迁移重复编号。升级前退出旧程序；旧版本新连接拒绝打开 v2 库，禁止旧进程继续写新库。原 UUID 和关系保持不变。

`resolveTaskReferences` 在业务执行前将精确短编号解析成 UUID，确保层级、循环、分支和附件校验使用同一主键。请求幂等指纹保留原始参数，失败回滚不占号。JSON 与 context 增加 `short_code`，详见 [CLI 契约](../../Skills/next-one/references/cli.md#global-task-short-codes)。`ShortCodeTests` 与 CoreTests 覆盖编码边界、迁移、并发和编号引用。

## v3 完成归档与编号复用

最新规则以 [归档 Spec](../../docs/spec/2026-10-26/archive-completed.md) 为准，替代上文 v2 的删除不复用约定。v3 清空回收站编号，普通删除/批量归档释放编号；归档将分配游标置 1，按占用集合跳号。恢复分支一次构建占用集合，按创建时间/UUID为每项重新分配。短编号仅供 get，写入先解析为 UUID，防止编号复用及相同 revision 误命中新任务。

`archive preview` 返回完成候选数与 SHA256(ID/revision) token；`archive completed` 在写事务中重验 token、按连续完成祖先分组 deletionID、原子归档并重置游标，支持 request-key。归档单次扫描，不为每个完成项反复调用 delete/descendants。已有 UUID、父子关系、附件内容不变。

CodexSetup implements explicitly authorized install/status/uninstall with a next-one entry, NEXT_ONE_HOME, and integration/current/bin/next-one. It backs up owned files, preserves unrelated rules and USER.md, and refuses unmanaged or modified content.

## 提醒事项同步持久化

`ReminderSync.swift` 定义字段投影、完成状态判定和受管对象记录。数据目录内 `reminder-sync.json` 为版本化独立 sidecar，`reminder-sync.lock` 提供进程互斥；旧 CLI 保存任务 Snapshot 不会擦除映射，因此任务 schema 保持 v3。任务最新快照与删除记录可重建未发送意图；创建前保存映射意图，来源标记用于系统写入后中断恢复。映射使用数据集 ID + Todo UUID，复制到不同路径的映射拒绝自动启用。

`Store.applyReminderCompletion` 在同一事务内复用 update 的 revision 和父子校验，再保留系统完成时间。同步失败不回滚用户本地保存。验证：`swift test --filter Reminder`，系统／iCloud 证据见[验收记录](../../docs/acceptance/calendar-reminders-sync.md)。

## Codex 项目只读适配与交接文本

`CodexHandoff.swift` 独立于 Store：`CodexProjects` 以 SQLite READONLY/query_only 读取 Codex 的 projects/project_roots，不创建数据库、不迁移、不读会话或凭据。支持显式绝对 CODEX_HOME，否则使用用户主目录下 .codex；当前只支持经过验证的 state_5.sqlite 所需表列，未知版本明确失败，不扫描备份或合并 JSON。读取事务保留 WAL 一致性，短忙碌超时不阻塞 UI 主线程。

`CodexHandoff` 负责路径精确匹配、目录校验、纯文本 neo 包装和 URL 编码。用户补充指令原样追加，空输入无默认指令；Codex URL 无自动发送参数。附件沿用 Store 的实际记录与持久化路径，本功能不扩大既有图片／视频导入类型限制。验证位于 TodoAppTests/CodexHandoffTests，包含数据库夹具、真实 WAL、路径及消息往返和 UI 会话状态。

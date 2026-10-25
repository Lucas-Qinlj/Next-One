# todo-core

`Store.execute` 是 UI/CLI 共用入口；参数白名单、项目归属、十层/循环、状态、日期、附件、版本和幂等检查均在此实现。`snapshot` 供 UI 只读刷新；`Models` 定义项目、任务与附件；`WindowGeometry` 只处理固定锚点与可见区域几何。

SQLite v1 使用一个 Codable 状态快照，`BEGIN IMMEDIATE` 串行读改写、WAL、FULL 同步和五秒忙等待。一个 Store 内使用锁，不同进程由 SQLite 协调。任务更新要求预期 revision；创建请求键连同参数指纹和首次结果原子保存。未知较新 schema 拒绝打开，不自动降级或清空。

分支移动、级联完成、祖先重开、删除/恢复均为事务。恢复按删除组处理，不恢复之前已独立删除的后代。附件先复制并同步文件，再提交记录，失败回滚并清理本次副本；进程中断留下的无引用文件不自动删除。附件软删除与任务回收站均长期保留。

数据默认 Application Support/Todo-AI，`TODO_AI_HOME` 可隔离。当前全量快照适合个人清单，读改写成本随总任务、请求历史增长；需要大量数据时再引入规范化表和迁移。目录为本机用户私有，不监听端口，不提供远程接口。

验证：根目录 `swift test`，实际 CLI 进程验证用 `python3 scripts/cli-smoke.py`。不要用真实待办做失败路径测试。

拖动接口：`place` 在同一事务复用 `move` 校验并为目标同级/同完成分区写入可选 `sortOrder`；旧快照缺省 nil，保持原排序。`group` 验证两个未分类且非祖先后代的任务及其版本，检查空项目或创建无目录项目后原子移动两个分支。`project create` 允许 paths 为空；后续绑定继续走原路径校验。新增针对性测试见 DraggingTests.swift，真实命令验证 `python3 scripts/drag-cli-smoke.py`。

`Snapshot.boardKeys` 是全部项目视图的统一顶层顺序，兼容可选 boardOrder/boardRevision；过滤空项目、已删除或非根任务、已完成未分类任务，并为新对象补默认位置。`board place` 在事务中重排整组或整支移出项目后插入，带源对象版本和顶层顺序版本；项目数组本身不重排，因此 UI 项目颜色稳定。`board list` 供 CLI 获取当前顺序与版本。

`project unbind` 校验项目 revision 及已绑定路径，仅删除项目 paths 中的对应项，不触碰文件系统和任务；允许最后一条路径解除。ProjectUnbindTests 覆盖文件/任务保留、路径不存在、版本冲突、最后一条解除及后续重绑。

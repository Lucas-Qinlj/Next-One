# 本地接口 v1

所有命令成功输出 `{"ok":true,"data":...}` 到 stdout；失败输出 `{"ok":false,"error":{"code":"...","message":"..."}}` 到 stderr，并退出 1。统一 JSON，`--json` 可省略。对象字段使用 snake_case，任务包含 `project_id`、`parent_id`、`revision`；未分类对应缺省 project_id；可空字段无值时省略。使用前以 `todo --help` 核对命令。

```sh
todo project list
todo project bind --path "$PWD" --name "我的项目"
todo context --cwd "$PWD" --limit 100 --offset 0
todo list --project PROJECT_ID
todo get TASK_ID
todo add --project PROJECT_ID --title '明确的后续工作' --source codex --request-key STABLE_KEY
todo add --parent TASK_ID --title '明确的子任务' --source codex --request-key CHILD_KEY
todo update TASK_ID --status in_progress --expected-revision 1
todo update TASK_ID --description-file ./result.txt --expected-revision 2
todo complete TASK_ID --expected-revision 3
todo complete TASK_ID --expected-revision 3 --cascade
todo move TASK_ID --project PROJECT_ID --parent root --expected-revision 4
todo delete TASK_ID --expected-revision 5
todo trash
todo restore TASK_ID --expected-revision 6
todo attachment add TASK_ID --path ./reference.png --expected-revision 7 --request-key ATTACHMENT_KEY
```

- `project bind --project ID --expected-revision N` 添加同一项目的额外绑定；`project update ID --name NAME --expected-revision N` 改名；`--path NEW --replace-path OLD` 重新绑定失效目录。
- `list --project all|unclassified|ID` 可加 `--status todo|in_progress|done`、`--limit 1..500 --offset N`。`context` 未匹配退出非零，不读取其他项目。
- 新增/更新字段：title、description、status、priority（high=紧急、medium=比较紧急、low=一般；默认 medium）、color（none/red/orange/green/blue/purple）、due-date（yyyy-MM-dd）、due-at（含时区 ISO 8601）。空截止值清除该值，非空日期/时间会清除另一种；不能同时设置两种非空值。
- `get` 返回任务、祖先与未移除附件（含本地 path）。context 不读取媒体。`attachment delete|restore TASK_ID --attachment ATTACHMENT_ID --expected-revision N` 可恢复移除的附件。
- 写入返回 task、新 revision、affected_ids（分支操作）、reopened_ancestors（必要祖先重开）。创建请求重试返回首次结果，因此后续编辑必须重新 get 最新版本。
- 可恢复删除长期保留，不自动清理；恢复分支从删除组根任务发起。删除前单独被删除的后代不会随本次恢复。
- 同一请求键全局唯一；相同参数重试不会复制任务/附件，不同参数返回冲突。

| code | 处理 |
| --- | --- |
| project_unmatched | 没有明确项目；读取绑定并请用户选择必要归属 |
| not_found | 任务/项目/附件不存在或已删除；重新读取 |
| invalid_field | 修正参数；不猜测丢失内容 |
| depth_exceeded | 十层限制，调整层级 |
| cycle_detected | 不能移动到自身或后代 |
| revision_conflict | 重读最新版，保留用户编辑后局部更新 |
| idempotency_conflict | 同键不同内容，查原结果，不改键盲重试 |
| cascade_required | 需要明确一并完成后代；不能静默添加 cascade |
| attachment_failed | 导入失败，没有成功附件记录；检查文件、格式和大小 |
| storage_unavailable | 保留数据；检查目录、空间、权限或数据版本，不直接改库 |

## 拖动排序与项目分组

- `project create --name NAME` 创建无目录项目，返回 project。之后使用 `project bind --project ID --expected-revision N --path DIR` 绑定目录；未绑定时 context 不匹配此项目。
- `place ID --expected-revision N --anchor TARGET --anchor-revision N --placement before|after`：移动整个分支到目标的同级位置；源与目标须同属未完成或已完成分区。不可同时指定 project/parent。
- `place ID --expected-revision N --project ID|unclassified --parent ID|root --placement end`：移动整个分支到指定同级列表末尾。复用 move 的循环/十层/跨项目校验，成功返回 task、affected_ids、ordered_ids、reopened_ancestors。
- `group ID --expected-revision N --target TARGET --target-revision N --name NAME`：两条未分类待办及其分支原子合并到新无目录项目。可将 `--name` 换为 `--project EMPTY_ID` 使用没有任何未删除待办的项目；两参数不能并存。目标任务在前、拖动任务在后，返回 project、affected_ids。
- group 禁止相同任务、已归属项目任务、祖先与后代的合并。任一校验失败全部回滚；版本冲突返回 revision_conflict，非法合并返回 invalid_field，祖先/后代返回 cycle_detected。
- sort_order 为可选整数，手动排序优先；同组新增追加在手动排序末尾，未手动排序的组仍按优先级/截止/创建时间排序。不要直接写 sort_order 或数据库。
- 对上述命令不盲目重试旧版本：先读取当前状态，确定是否仍需操作。

## 顶层项目/任务混合顺序

- `board list` 返回 ordered_keys（`p:项目ID` / `t:任务ID`）及 board_revision。项目分组与未分类未完成根任务共用顶层顺序，已完成的未分类任务在独立分区。
- `board place --key p:ID|t:ID --expected-revision N --expected-board-revision N --anchor p:ID|t:ID --placement before|after` 调整顶层位置；`--placement end` 不需要 anchor。
- 移动项目只更新项目版本和顶层顺序，不改变内部任务；移动任务到顶层时整支迁到未分类、成为根任务。更新 board_revision，任一版本或目标不符全部失败回滚。
- 普通 place 在已有顶层手动顺序时同步未分类根任务的顶层位置，避免 CLI 与界面排序分离。旧快照无 board_order 时由项目和未分类根任务生成默认顺序。

- `project unbind ID --path DIR --expected-revision N` 仅解除一条路径关联，返回更新后的 project 和 removed_path；保留项目、待办与磁盘文件，允许移除最后一条路径。目录不存在也可解除已有路径；未绑定路径返回 not_found，过期版本返回 revision_conflict。解除后该路径不再匹配此项目，但可能匹配其他显式绑定的上级目录。

## 数据渠道

debug CLI 默认读取 Application Support/Todo-AI，release CLI 默认读取 Application Support/Todo-AI-Release。TODO_AI_HOME 显式覆盖默认值；`--help` 显示实际解析目录且不打开数据库。安装版与开发版不自动复制/迁移任务，调用方应使用目标应用设置给出的 CLI 与目录。

## Codex 配置管理（不打开待办数据库）

`integration install|status|uninstall` 使用本 CLI 的实际数据目录，TODO_AI_HOME 可明确指定。首次安装必须先启动完整应用准备 integration/current。仅 install/uninstall 在用户授权下写全局 Skill 与专属规则块；status 只读。可用 --skill-root DIR、--codex-home DIR 进行隔离验证。成功沿用 ok/data JSON；配置冲突返回 integration_conflict，失败退出非零。详细边界见[接入生命周期](setup.md)。

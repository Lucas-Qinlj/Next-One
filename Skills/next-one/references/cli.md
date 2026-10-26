# Local CLI reference v1

Successful commands write `{"ok":true,"data":...}` to stdout. Failures write `{"ok":false,"error":{"code":"...","message":"..."}}` to stderr and exit with status 1. Output is JSON; `--json` is optional. Object fields use snake_case. Tasks include `parent_id` and `project_id` when applicable, plus `revision`; absent optional values may be omitted. Unfiled tasks have no project ID.

Run the selected executable with `--help` before use. Examples below use `next-one` as shorthand for that verified executable; they do not imply it is installed on PATH. Set `NEXT_ONE_HOME` to the target app's data directory.

```sh
next-one project list
next-one project bind --path "$PWD" --name "My project"
next-one context --cwd "$PWD" --limit 100 --offset 0
next-one list --project PROJECT_ID
next-one get TASK_ID
next-one add --project PROJECT_ID --title 'Confirmed follow-up work' --source codex --request-key STABLE_KEY
next-one add --parent TASK_ID --title 'Subtask' --source codex --request-key CHILD_KEY
next-one update TASK_ID --status in_progress --expected-revision 1
next-one update TASK_ID --description-file ./result.txt --expected-revision 2
next-one complete TASK_ID --expected-revision 3
# Only when completing unfinished descendants was authorized:
next-one complete TASK_ID --expected-revision 3 --cascade
next-one move TASK_ID --project PROJECT_ID --parent root --expected-revision 4
next-one delete TASK_ID --expected-revision 5
next-one trash
next-one restore TASK_ID --expected-revision 6
next-one attachment add TASK_ID --path ./reference.png --expected-revision 7 --request-key ATTACHMENT_KEY
```

IDs, revisions, and request keys above are placeholders, not a script to run unchanged. Obtain real IDs and the latest revision from current records.

## Projects, fields, and results

- `project bind --path DIR --project ID --expected-revision N` adds a folder binding to an existing project.
- `project update ID --name NAME --expected-revision N` renames a project. Use `--path NEW --replace-path OLD` with `project update` to replace a folder binding.
- `project unbind ID --path DIR --expected-revision N` removes only that binding and returns `project` and `removed_path`. It preserves the project, tasks, and disk files, and permits removing the final binding. Missing disk folders may still be unbound; an unregistered path returns `not_found`, and a stale revision returns `revision_conflict`. The directory may subsequently match an explicitly bound ancestor project.
- `list --project all`, `--project unclassified`, or `--project ID` may be combined with `--status todo|in_progress|done`, `--limit N` (1-500), and `--offset N`. Pipes in syntax descriptions mean alternatives, not literal shell arguments. An unmatched `context` fails; it does not fall back to another project.
- Writable task fields: `title`, `description`, `status`, `priority` (`high`, `medium`, `low`; default `medium`), `color` (`none`, `red`, `orange`, `green`, `blue`, `purple`), `due-date` (`YYYY-MM-DD`), and `due-at` (ISO 8601 with timezone). An empty due value clears that field. A nonempty date or timestamp clears the other field; do not supply both as nonempty.
- `get` returns the task, ancestors, and non-removed attachments, including local paths. `context` does not read media. Use `--description-file FILE` or `--description-file -` to pass multiline descriptions safely.
- `attachment delete TASK_ID --attachment ATTACHMENT_ID --expected-revision N` soft-deletes an attachment; `attachment restore` with the same arguments restores it.
- Task writes return the task with its new revision and, where applicable, `affected_ids` and `reopened_ancestors`. An idempotent creation retry returns the original result; fetch the task again before a later edit.
- Soft-deleted content is retained until explicitly restored; there is no automatic purge. Restore a deleted branch from the root of its deletion group. Descendants deleted separately before that operation are not restored with it.
- Request keys are globally unique in a store. Identical retries do not duplicate tasks or attachments; different parameters with the same key return a conflict.

## Errors

| Code | Action |
| --- | --- |
| `project_unmatched` | Resolve the required project or use the explicitly permitted Unfiled default; never guess another project. |
| `not_found` | Reread records; the task, project, or attachment may be missing or deleted. |
| `invalid_field` | Correct the arguments; do not invent missing content. |
| `depth_exceeded` | Respect the maximum of ten task levels. |
| `cycle_detected` | Do not move a task into itself or a descendant. |
| `revision_conflict` | Read the latest version and preserve user edits before applying a partial update. |
| `idempotency_conflict` | Inspect the original request result; do not bypass protection by changing the key. |
| `cascade_required` | Explain the unfinished descendants and obtain authorization before adding `--cascade`. |
| `attachment_failed` | Check the file, format, size, and permissions; do not claim successful import. |
| `storage_unavailable` | Preserve data and check the directory, available space, permissions, or data version. Do not edit the database directly. |

## Ordering and grouping

- `project create --name NAME` creates a project without a folder and returns `project`. Bind it later with `project bind --project ID --expected-revision N --path DIR`. Until bound, it cannot match `context` by directory.
- `place ID --expected-revision N --anchor TARGET --anchor-revision N --placement before|after` moves the entire branch to the target's sibling level. Source and target must both be unfinished or both completed. Do not also pass `project` or `parent`.
- `place ID --expected-revision N --project ID|unclassified --parent ID|root --placement end` appends a branch to the specified sibling list. It uses the shared cycle, depth, and cross-project validations and returns `task`, `affected_ids`, `ordered_ids`, and `reopened_ancestors` as applicable.
- `group ID --expected-revision N --target TARGET --target-revision N --name NAME` atomically combines two unclassified tasks and their branches into a new project without a folder. Replace `--name NAME` with `--project EMPTY_ID` to use a project with no non-deleted tasks. Do not pass both. The target task comes first; the source follows. Returns `project` and `affected_ids`.
- Grouping rejects the same task twice, tasks already assigned to projects, and ancestor/descendant pairs. Any validation failure rolls back the operation. Stale revisions return `revision_conflict`; invalid grouping returns `invalid_field`; ancestor/descendant grouping returns `cycle_detected`.
- `sort_order` is an optional stored integer. Manual ordering takes precedence; new siblings append in a manually ordered group. Otherwise, priority, due date, and creation time determine order. Do not directly write `sort_order` or the database.
- Never blindly retry ordering or grouping with stale revisions. Read current records and decide whether the requested operation is still needed.

## Mixed top-level project and task order

- `board list` returns `ordered_keys` (`p:PROJECT_ID` / `t:TASK_ID`) and `board_revision`. Project groups and unfinished Unfiled root tasks share the top-level order; completed Unfiled tasks form a separate section.
- `board place --key p:ID|t:ID --expected-revision N --expected-board-revision N --anchor p:ID|t:ID --placement before|after` reorders a top-level item. With `--placement end`, omit `--anchor`.
- Moving a project changes its revision and top-level position, not its internal task order. Moving a task to the top level makes it an Unfiled root with its branch. The board revision is updated; stale versions or invalid targets roll back the operation.
- Ordinary `place` operations also keep Unfiled top-level ordering consistent with an existing manual board order. Older snapshots without `board_order` derive the default order from projects and Unfiled root tasks.

## Storage channels

Debug defaults to `~/Library/Application Support/Next-One`; release defaults to `~/Library/Application Support/Next-One-Release`. `NEXT_ONE_HOME` overrides the default; the legacy `TODO_AI_HOME` is a fallback only when the new variable is absent. `--help` shows the resolved directory without opening the store.

Development and release data remain separate. If a default new path is absent and the same-channel legacy folder exists, the new path links to the existing store. No live database is copied or merged. Explicit directories do not trigger this compatibility link. Use the CLI and directory supplied by the target app's settings.

## Global task short codes

Every live task has a `short_code` unique across all projects, roots, children and completed tasks in the selected store. Sequence: A1…A9, B1…Z9, AA1…AA9, AB1…. UUID remains `id`; `context` summaries include `short_code`. Live codes stay stable on edits, moves and completion. Deleted/archived tasks have no code and restoring assigns new available codes. Archiving resets the allocation cursor to A1 and skips occupied codes, so a historical code may later identify a different task.

`get A1` accepts an exact case-insensitive code or UUID. All writes and task-reference arguments (`id`, `parent`, `target`, task anchors/board keys) require the UUID returned by a current read. Verify title/project when resolving old chat references; do not assume an old code still refers to the same task. Revisions alone cannot protect a reused code. Projects and attachments still use UUIDs; `root` and `unclassified` are unchanged. No code-edit option exists. Find deleted tasks via `trash`, then `restore UUID --expected-revision N`; report their new code from the response.

Storage v3 migrates v1/v2 automatically: existing live codes remain stable, Trash codes are cleared. Close older app/CLI processes before upgrading; older versions must not write the new store. The separate debug and release stores do not share numbering. Historical idempotency replies may contain old codes; reread their UUID before acting further.

## Completed task archiving

Only archive on an explicit user request. `archive preview` returns a global completed-task `count` and `token`. Explain that the operation moves completed tasks from every project, including completed children of unfinished parents, to Trash, releases their codes, and restarts allocation at A1 while skipping occupied codes. Restore keeps task relationships but assigns new codes. No attachment is purged.

After the user approves this scope, run `archive completed --expected-token TOKEN --request-key KEY`. Preserve the exact token/key on a transport retry; `revision_conflict` means candidates changed, so preview again and review the new scope before executing. The operation is atomic and returns `count` and `affected_ids` (UUIDs). Do not issue many independent delete commands. No project filter is accepted. The top-of-list notice appears when any live code reaches four characters and remains if long live codes still exist; three characters is a preference, not a hard limit.

## Codex integration management

`integration install|status|uninstall [--skill-root DIR --codex-home DIR]` manages only the explicitly authorized local Codex connection. These commands do not initialize the task database. `status` is read-only. Setup conflicts return `integration_conflict`; preserve existing files and reconcile instead of forcing replacement. See [setup lifecycle](setup.md).

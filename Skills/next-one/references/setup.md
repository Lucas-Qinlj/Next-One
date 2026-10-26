# Local Codex connection lifecycle

Use the exact CLI and data directory copied from the target app. Set NEXT_ONE_HOME explicitly and quote all paths. A managed runner already binds these paths.

- `integration status`: read-only inspection of managed files, the active rules file, upstream resources, and the data binding. Does not open a task database.
- `integration install`: only on explicit setup authorization. Creates a stable `~/.agents/skills/next-one` entry and runner, and a dedicated block in the active CODEX_HOME AGENTS.override.md (when nonempty) or AGENTS.md. Backs up affected files and preserves unrelated content. Refuses unmanaged Skills, edited managed content, different data bindings, and symbolic-link replacement. Reconcile conflicts with the user rather than deleting or forcing replacement.
- `integration uninstall`: only when requested. Removes unchanged managed files and rules, preserving USER.md, unrelated files and task data. Edited content requires reconciliation.
- `--skill-root DIR --codex-home DIR` supports isolated verification; do not guess alternative directories for ordinary setup.

## Updates

The installed entry reads `integration/current/skills/next-one/SKILL.md` for each new task; its runner calls `integration/current/bin/next-one` with the fixed data path. Launching an updated app prepares and atomically switches these resources. It does not rewrite global configuration. Preserve user-owned USER.md and do not manually modify app-owned current resources. Existing chats can retain old instructions; start a fresh chat to verify updates.

Changing the connection protocol or data binding requires an explicit install/check. Status reports `active_rules:false` if a different override has become active; remove the old managed connection before reinstalling into the active rules file.

## Verification

After setup, run status, --help, project list and context as read-only checks. Use a genuinely authorized project request in a new Codex chat to verify actual task reads and writes; never invent work or mutate real tasks merely to test setup. Installation success is not proof of automatic discovery. Unmatched projects require explicit scope, and failures must be reported. No background monitoring or other-agent configuration is implied.

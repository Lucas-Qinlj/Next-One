# Managed Codex working rules and updates

Settings provides a copyable installation/update request. Sending it authorizes the bundled `integration install` command to create the user-level Skill connection and a dedicated working-rules block. App startup only prepares upstream resources and does not modify global configuration.

## Managed connection

- `~/.agents/skills/next-one/SKILL.md` is a stable entry. Its `run` binds NEXT_ONE_HOME and the current app CLI.
- The installer uses a nonempty AGENTS.override.md in CODEX_HOME (default `~/.codex`), otherwise AGENTS.md. It preserves other content and manages only its `NEXT-ONE:BEGIN/END` block.
- The block asks Codex to read existing project tasks before implementation, record explicit work, update actual progress, preserve user edits, and leave unverified work open. Discussion is not a commitment; unmatched projects and failures are reported rather than guessed. User instructions take precedence.
- The entry reads `integration/current/skills/next-one/SKILL.md`; the runner uses `integration/current/bin/next-one`. Launching an updated app switches upstream resources without rewriting the installed entry, global rules, or USER.md. Existing chats may retain old instructions; verify in a fresh chat.

## Conflicts and removal

`integration status` is read-only. Install is backed up and idempotent; unmanaged Skills, edited managed content, a changed active rules file, or another data binding require reconciliation before installation. Never delete or force-overwrite user content to bypass a conflict.

`integration uninstall` removes only unchanged managed files and the owned rules block. It preserves USER.md, unrelated configuration, and task data. Backups are under the selected data directory's `integration/setup-backups`. If status reports `active_rules:false`, remove the old managed connection before installing into the currently active rules file.

## Verification limits

Installation is not proof of automatic routing. In a new chat, verify real context/task calls for an already-authorized project request. Do not create test commitments in real data. Project instructions, permissions, disabled Skills, and model behavior affect invocation. No background monitoring or other-agent configuration is implied.

See [setup lifecycle](../Skills/next-one/references/setup.md) and the [implementation spec](spec/2026-10-26/codex-skill-lifecycle.md). Earlier isolated conversation evidence remains historical; the merged brand/path adaptation is checked separately.

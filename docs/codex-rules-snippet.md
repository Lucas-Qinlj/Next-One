# Optional persistent working rules

Review this snippet before adding it to the working rules of a local coding agent that should use Next One. This file does not install a global Skill or change agent configuration. First verify the actual CLI path and data directory from the app settings. Project-specific work requires an explicit folder binding; standalone personal neo requests may use Unfiled.

```text
Use the next-one Skill for local project task tracking. At the start of project work, read the unfinished tasks for the current bound directory and reuse existing records. Record explicit user-requested work, not speculative discussion or every tool call. Mark work in progress only when implementation begins, and update status and notes based on actual results. Preserve user edits, use revision checks, and use stable request keys for creation retries. Report interface failures without claiming synchronization. Never write to another project when directory matching fails, edit the database directly, or upload attachments automatically. For direct neo requests, follow the Skill's intent, scope, matching, and date rules; preserve the user's language.
```

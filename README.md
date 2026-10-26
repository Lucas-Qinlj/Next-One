<div align="center">

# Todo-AI

**One task list. Shared context. You and your coding agent.**

A local macOS floating todo app for vibe coding—keep plans, progress, and next steps visible while you build with AI.

**English** · [简体中文](docs/readme/README.zh-CN.md) · [日本語](docs/readme/README.ja.md) · [한국어](docs/readme/README.ko.md)

macOS 14+ · SwiftUI + AppKit · Local storage · Codex Skill + CLI

</div>

**Keep it on top. Tune the transparency. Copy a ready-made setup instruction to your agent.**

## Why Todo-AI?

Coding with AI moves fast. Keeping track of the work often doesn't.

A follow-up gets buried in a chat. A new session needs the same explanation again. Your own checklist and the agent's understanding drift apart. Switching projects makes it harder to remember what was actually finished and what still needs checking.

**Todo-AI gives you and your coding agent one persistent, project-aware task list to maintain together.** You work in a small floating app; the agent reads and updates the same local data through a CLI. Keep the goal, progress, acceptance criteria, and unfinished work attached to the task, ready for the next session to read.

It is built for solo developers, indie makers, and anyone who builds software through conversation with coding agents. The included integration targets **Codex**; other local agents can use the documented CLI, but dedicated integrations have not been verified.

## A look inside

<table>
<tr>
<th align="left">Keep the work in view</th>
<th align="left">Leave context with the task</th>
</tr>
<tr>
<td width="50%"><img src="docs/assets/screenshots/en/task-list.jpg" alt="Todo-AI floating list with two project groups, nested tasks, progress and priority labels" width="480"></td>
<td width="50%"><img src="docs/assets/screenshots/en/task-detail.jpg" alt="Todo-AI task details with a goal, progress notes, next steps, status and subtasks" width="480"></td>
</tr>
</table>

Actual macOS app captures with fictional demo tasks. The app supports Simplified Chinese, English, Japanese, and Korean. Choose a language or System default at the top of Settings; changes apply immediately and are remembered. Your task and project content stays unchanged.

## Highlights

| Feature | What it helps you do |
| --- | --- |
| **Shared human–agent context** | Read and edit the same tasks from the app and CLI. Agent writes appear in the running app; the CLI also works while the app is closed. |
| **Project-aware handoffs** | Bind folders to projects and retrieve the right context from the working directory. Explicitly bind additional worktrees to the same project. |
| **Always-on-top workspace companion** | Keep the checklist visible alongside your editor or agent chat, so checking the next step does not mean switching to another task app. Move, resize, or collapse it from the floating ball. |
| **Adjustable transparency** | Set background opacity from 30% to 100%. Keep the panel less visually intrusive while task text and the floating button remain opaque. |
| **Copy-and-send agent setup** | Copy a ready-made, localized Codex setup instruction from Settings. It includes the actual Skill, CLI, and data paths, so you do not have to assemble the setup prompt yourself. |
| **Tasks that keep their context** | Organize up to ten levels of subtasks, with descriptions, status, priority, color, and a due date or time. |
| **Flexible organization** | Collapse project groups, reorder tasks and groups, move branches, and group unclassified tasks into a project. |
| **Autosave with conflict handling** | Details save after editing pauses. Different-field changes can merge; conflicting edits keep your draft and ask you to resolve them. |
| **References and recovery** | Attach images and videos as managed local copies, up to 100 MB per file. Restore deleted tasks and attachments from the trash. |
| **Local by design** | SwiftUI, AppKit, and system SQLite. No Todo-AI account, cloud backend, or additional AI API key required. |

Lock mode makes the panel ignore mouse input while the floating ball remains available to unlock it. Some cross-app and desktop combinations still need manual validation; see [current limitations](#current-status-and-limitations).

## Keep your workflow in view

**Keep your next step beside your code.** Use the pin button to keep Todo-AI above ordinary windows on the current desktop. Collapse it to the floating ball when you need more space, then expand it to check progress without hunting through another app.

**Choose how much presence it has.** Adjust **Background opacity** in Settings from **30%–100%**. Only the background becomes transparent; text and the floating button remain clear. Pinning and opacity are independent controls, so you can choose the balance that suits your workspace.

**Start sharing tasks with a copy and a paste.** In **Settings → Codex integration**, click the copy icon and paste the complete instruction into a local Codex chat. The app prepares the paths and setup steps, including preserving existing Skill customizations and read-only verification. The instruction follows your selected UI language. Sending it asks Codex to perform the setup; copying alone does not install anything. This built-in instruction targets Codex; other coding agents can use the documented local CLI.

<p align="center"><img src="docs/assets/screenshots/en/settings.jpg" alt="English settings with language selection, background opacity slider, pin control and copyable Codex setup instructions" width="480"></p>

## How you and the agent work together

1. **Capture the work.** Create a project, bind its folder, and add the goal, constraints, and acceptance criteria.
2. **Start with context.** Ask Codex to read that project's open tasks before making changes.
3. **Keep progress shared.** Edit priorities and notes in the app while the agent records actual progress through the CLI.
4. **Leave a useful handoff.** Record completed work and remaining checks in the task. A later local session can read the same list instead of reconstructing it from chat history.

After setting up the integration, try a request like:

> Read this project's Todo-AI tasks. Work on the onboarding flow, record confirmed follow-up work as subtasks, and update progress based on what you actually verify. Preserve my existing notes.

The app and agent use one business-rule layer and one local store:

```text
You ─────────── macOS app ──────┐
                               ├── Shared validation ── Local tasks + attachments
Coding agent ── Skill / CLI ────┘
```

This is explicit collaboration: Todo-AI does not listen to every chat, run agents in the background, or automatically synchronize remote environments.

## Quick start

### Build and run

Requirements: **macOS 14 or later**, a **Swift 6.0+ toolchain** (such as a compatible Xcode installation), and Python 3 for the packaging script. There are no third-party runtime dependencies.

```sh
git clone https://github.com/Lucas-Qinlj/Todo-AI.git
cd Todo-AI
./scripts/run.sh
```

This builds and launches `.build/TodoAI.app`, including its CLI and Skill resources. It does not install the app into Applications. This is a local development build, not a signed and notarized distribution.

- Click the floating ball to show or hide the list; drag it to move the app.
- Use **+** to add a task, and click a task title to edit its details. Changes autosave.
- Open **Settings** to bind a project folder and find **Codex integration**.
- Right-click the ball to lock, unlock, or quit. The menu-bar entry can bring the ball back into view.
- Shortcuts: `⌘B` recover the ball, `⌘T` toggle the list, `⌘,` open Settings, `⌘Q` quit.

### Connect Codex

1. Launch Todo-AI and open **Settings → Codex integration**.
2. Copy the installation instruction and send it in a **local Codex session on the same Mac**. The instruction asks that session to install the bundled Skill, preserve existing customization, and verify the CLI using read-only commands.
3. Bind your project folder, then ask Codex to read its Todo-AI context. Additional worktree folders must be explicitly bound.

Copying the instruction alone does not install anything. App startup prepares bundled integration resources inside the app's data directory; it does not modify your global Skills or Codex configuration. Automatic discovery after installation still needs validation in a fresh target session.

See the [included Skill](Skills/todo-ai/SKILL.md), [CLI reference](Skills/todo-ai/references/cli.md), and [optional working rules](docs/codex-rules-snippet.md). These detailed references are currently in Chinese.

### Use the CLI directly

Run these from the repository root after building:

```sh
.build/debug/todo --help
.build/debug/todo project bind --path "$PWD" --name Todo-AI
.build/debug/todo context --cwd "$PWD" --json
```

The bind command creates or associates a project with this checkout. For another project, supply its directory instead. Commands return structured JSON; failures return an error code and a nonzero exit status.

Updates require the task's latest `revision`. Creation supports stable request keys to avoid duplicates on retries. Both interfaces enforce the same hierarchy, project, and status rules—agents should use the CLI, never edit the database directly.

## Data and privacy

- Release installers and their CLI use `~/Library/Application Support/Todo-AI-Release`; debug/development builds use `~/Library/Application Support/Todo-AI`. Tasks, attachments, language, window preferences, and integration resources are separate. The installer starts empty if its own directory does not exist, preserves its own data on later upgrades, and never imports or deletes development data.
- After switching from the older shared-data installer, copy the new Codex setup instruction from Settings to reconnect the agent to the installer’s data. Existing global Skills are not rewritten automatically; use the CLI/data paths in that instruction. `TODO_AI_HOME` explicitly overrides either default.
- Imported attachments are copied into managed storage. Moving the original file does not remove the imported copy. Video playback depends on the system's default media application.
- Deleted tasks and attachments remain recoverable; there is no automatic trash cleanup.
- Todo-AI does not automatically upload your tasks or attachments. Content you explicitly ask a coding agent to read enters that agent's context and is subject to its own data handling.
- To back up, quit the UI and stop CLI writes, then copy the entire data directory, including SQLite/WAL files and attachments.

For an isolated demo or test, use the **same** `TODO_AI_HOME` for both app and CLI:

```sh
TODO_AI_HOME="$PWD/.local/demo" ./scripts/run.sh
# In another terminal, from the same repository:
TODO_AI_HOME="$PWD/.local/demo" .build/debug/todo project list
```

Use one UI instance per data directory; CLI calls can run concurrently.

## Development

```sh
swift build
swift test
python3 scripts/cli-smoke.py
python3 scripts/drag-cli-smoke.py
./scripts/package-app.sh release
```

The release command creates an optimized local app bundle at `.build/TodoAI.app`; it does not sign, notarize, install, or publish it. Keep the complete bundle, including its CLI and Skill resources.

| Area | Responsibility |
| --- | --- |
| [TodoCore](Sources/TodoCore/README.md) | Persistence, transactions, task rules, and conflict checks |
| [TodoApp](Sources/TodoApp/README.md) | Floating windows, task UI, and local integration preparation |
| [TodoCLI](Sources/TodoCLI/README.md) | Structured local interface for agents and scripts |
| [Skills/todo-ai](Skills/todo-ai/SKILL.md) | Codex task-reading and update conventions |

For a local drag-to-Applications installer, run `./scripts/package-dmg.sh`. The DMG and SHA-256 checksum are written to `.local/releases/`; see the [local installation guide](docs/distribution/local-install.md) (Chinese). This trial package is not Developer ID signed or notarized.

## Current status and limitations

The native app and CLI are implemented and have been built and run on Apple Silicon. This is an early local development version; not every acceptance scenario has passed.

- Signed/notarized downloads, cross-machine distribution, and cross-architecture validation are not complete.
- Full validation of click-through input reaching other apps, multi-display changes, Spaces, full-screen apps, and Stage Manager remains incomplete.
- Some media interactions and fresh-session Skill discovery still need end-to-end checks.
- There is no cloud sync, team workspace, or guaranteed remote-agent access to this Mac's data.
- The pixel-aquarium experiment under `docs/` is a separate prototype, not a feature of the native app.

See [project status](PROJECT_STATUS.md), the [acceptance report](docs/acceptance/macos-floating-todo.md), and the [product specification](docs/spec/2026-10-24/macos-floating-todo.md) for evidence and remaining work.

## Contributing

Bug reports, reproducible examples, documentation improvements, and focused changes are welcome. For bugs, include your macOS version, build steps, expected behavior, and actual behavior. Use demo data and remove private tasks, paths, and credentials from reports.

Before making changes, read [AGENTS.md](AGENTS.md) and the relevant specification. Keep the product focused on a simple, local workflow for one person and their coding agent. Verify behavior changes with the relevant tests and real macOS interaction where needed.

## License

A license has not yet been selected; this repository currently has no `LICENSE` file. An open-source license needs to be added before the project is presented as licensed open-source software.

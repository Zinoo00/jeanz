# Claude Code port

pstack is written for Cursor. jeanz carries it as Claude Code-native text, so no session has to translate names at run time. `tools/check.sh` fails on any Cursor-only name that comes back, for example after a pstack sync. This file is the mapping it points to.

## Tools

| Cursor | jeanz |
|---|---|
| `Task` | the `Agent` tool |
| `AskQuestion` | `AskUserQuestion`. `claude -p` has no such tool, so ask in plain text. |
| Open a todo list, copy steps into it | Use the session's todo tool if it has one. Otherwise keep a checklist in the reply and update it at each phase. |
| Run another skill (`/name`, "the **name** skill") | Read `../<name>/SKILL.md` from the current skill's folder and follow it. Most jeanz skills set `disable-model-invocation`, so the `Skill` tool refuses them. A user types `/jeanz:<name>`. |
| `Grep`, `Glob` | `rg` and `find` through `Bash` when the session lacks them. |

## Subagents

| Cursor | jeanz |
|---|---|
| `subagent_type: generalPurpose` | `subagent_type: "general-purpose"` |
| `poteto-agent`, `comment-sicko` | `subagent_type: "jeanz:poteto-agent"`, `"jeanz:comment-sicko"` |
| `readonly: true` | `subagent_type: "Explore"`. It still has `Bash`, so the brief says "do not edit files" and the parent checks `git status` afterwards. |
| `environment: "cloud"` | `isolation: "worktree"`, and the brief names the branch or commit to check out. |
| `environment: "local"` | omit |
| `cloud_base_branch: <b>` | the brief says to check out `<b>` first |
| `run_in_background: true` | Omit it. Subagents run in the background and notify the parent. |
| `resume` | `SendMessage` to the agent's ID to continue it with its context |
| `file_attachments` | list the paths in the brief |
| Cursor Projects (many workers on one goal) | parallel `Agent` calls in one message, each with `isolation: "worktree"`. A fan-out past about ten agents uses the `Workflow` tool, and only when the user has opted in. |

## Models

`Agent` takes `model` (`opus`, `sonnet`, `haiku`, `fable`) and `effort` (`low`, `medium`, `high`, `xhigh`, `max`). A role line in `~/.claude/rules/pstack-models.md` reads `<model> <effort>`, such as `opus xhigh`. Claude Code loads every `.md` in `~/.claude/rules/` into each session.

| pstack default | jeanz |
|---|---|
| `claude-opus-5-5-xhigh-fast`, `claude-opus-5-5-xhigh` | `opus xhigh` |
| `claude-opus-5-5-high-fast` | `opus high` |
| `claude-opus-5-5-medium-fast` | `opus medium` |
| `claude-opus-5-5-low-fast` | `opus low` |
| `claude-fable-5-2-high` | `fable high` |
| `gemini-4-carbon-high` (a panel seat) | `sonnet high`. Claude Code runs only Claude models, so a panel's third seat is a different Claude model, not a different vendor. |
| `auto`, `inherit-parent` | omit `model` |

## Paths

| Cursor | jeanz |
|---|---|
| `.cursor/skills/`, `~/.cursor/skills/` | `.claude/skills/`, `~/.claude/skills/` |
| `~/.cursor/plugins/`, `.cursor-plugin/plugin.json` | `~/.claude/plugins/`, `.claude-plugin/plugin.json` |
| `.cursor/rules/*.mdc`, always-applied rules | `CLAUDE.md`, or `AGENTS.md` when there is no `CLAUDE.md` |
| `~/.cursor/rules/pstack-models.mdc` | `~/.claude/rules/pstack-models.md` |
| `~/.cursor/projects/<slug>/agent-transcripts/` | `~/.claude/projects/<slug>/<session>.jsonl`. The slug is the workspace path with each `/` and `.` turned into `-`. Subagent transcripts are in `<session>/subagents/`. Read only the current workspace's folder. |
| `https://github.com/cursor/plugins/blob/main/pstack/<path>` | the local file, when jeanz ships it |

## Cursor-only features

| Cursor | jeanz |
|---|---|
| Bugbot (start, wait for, configure) | `/code-review` on the local diff. Comments a review bot already left on a GitHub PR are ordinary review threads. Triage them with `gh`. |
| Cursor Automations (event triggers, webhooks, `update_state`, `SendToUser`) | `/loop` for a recurring prompt in this session. `/schedule` runs in the cloud, so the port does not use it. Event triggers such as Slack messages are not available. Say so in one line and go on. |
| Cursor cloud agents | worktree-isolated subagents, as above. A step that needs the cloud machine itself is skipped with one line. |
| `create-skill` (built in) | Write the `SKILL.md` directly. It starts with YAML frontmatter that holds `name` (the folder name) and a one-scalar `description`. The body follows. |
| `/deslop` (cursor-team-kit) | `/simplify` |
| `control-ui` (browser, Electron) | the project's `verify-<app>` skill. Without one, Playwright, or Chrome DevTools through the browser tools. |
| `control-cli` (CLI, TUI) | the project's `verify-<app>` skill. Without one, a `tmux` session. |
| Custom mode (option+enter) | none. Type `/jeanz:poteto-mode` at the start of each task. |
| Grok Bot, `make-bot-ui` | Dropped, because it drives a Cursor-internal bot |

## Naming

Skills keep their pstack names, such as `poteto-mode` and `setup-pstack`, so most of a pstack sync maps file to file. [The upstream record](../UPSTREAM.md) lists what was renamed. Only the plugin namespace changes, from `/pstack:<name>` to `/jeanz:<name>`.

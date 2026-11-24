---
name: setup-pstack
description: Configure which models pstack uses per role and at what reasoning budget. Detects your available models and writes a rule every Claude Code session loads, which overrides the skill defaults. Use for /jeanz:setup-pstack, "configure pstack models", "pstack budget", or changing pstack's model choices.
---

# Setup pstack

Write `~/.claude/rules/pstack-models.md`, a rule Claude Code loads into every session, that sets pstack's model per role. Role lines never go in `CLAUDE.md`.

## Steps

### 1. Detect available models

Read the `model` and `effort` values the `Agent` tool's schema accepts in this session. That is the dependable source. A real value pairs one of those models with one of those efforts, written `<model> <effort>`, such as `opus xhigh`. If you cannot detect any, ask the user which models and efforts they have access to. Never write a model or effort you have not confirmed is available. The aliases `inherit-parent` and `auto` are always valid even though the schema does not list them.

### 2. Load current state

The default role-to-model mapping is the rule shape shown in step 5 below. If `~/.claude/rules/pstack-models.md` already exists, read it and treat its `# budget` line and its role values as the current choices. Otherwise start from those defaults. A line whose role is not in step 5, such as `hardest tasks`, `architect runners`, `reflect tooling`, or `why investigators`, is from a retired role. Drop it.

A value that is neither `<model> <effort>` nor an alias, such as a full model slug from another setup, becomes the `<model> <effort>` it names. A value on a model the `Agent` tool does not offer becomes `sonnet high` in a panel role (`arena runners`, `arena cross-judge pool`, `interrogate reviewers`) and the role's step 5 default in any other role.

A rule without the `# defaults: 3` line comes from an older setup. That setup wrote a line for every role, so some of its values are old defaults, not choices. Before step 3, replace a `# budget: unlimited` line with `large`, because no role runs above `xhigh`.

Every other value is the user's choice and stays, including every `inherit-parent` or `auto` value. Tell the user which values you replaced.

### 3. Budget, map, and confirm

**(a) Ask for a budget.** Prefer `AskUserQuestion` over free text. Offer these three options with these exact labels, and name the current budget when the rule records one. With no rule, say that `large` matches the skill defaults.

- `large — xhigh reasoning`
- `medium — high reasoning`
- `small — medium reasoning`

**(b) Apply it.** Build the working table from the skill defaults, and on a re-run keep any role you changed by model, list, or alias (`inherit-parent`, `auto`). Each role has a target effort, which is its default's effort moved by the budget. `large` keeps it, `medium` lowers it one step, and `small` lowers it two steps, on the ladder `xhigh` > `high` > `medium` > `low`. No role runs above `xhigh`, and a target at the bottom of the ladder stays there. Most defaults are at `xhigh`, and each budget label names where those land. Set the effort of every real value in the role, panel entries included, to the role's target. If the `Agent` tool does not accept that effort, use the highest effort it accepts at or below the target. If it does not offer the model, mark the role as needing a choice. `inherit-parent` and `auto` do not change. So `medium` turns `opus xhigh` into `opus high` and `opus high` into `opus medium`, and `small` turns them into `opus medium` and `opus low`.

**(c) Show the roles and confirm.** Show every role with its model, marking any real value whose model or effort was not detected as needing a choice. Also list each line step 2 dropped. Ask whether to accept as-is or change specific roles, offering the detected models at `xhigh` or below plus `inherit-parent` and `auto` (both mean: this role runs on the parent session's model) as the options. Prefer `AskUserQuestion` over free text. For panel roles (arena runners, interrogate reviewers) the value is a list, and one subagent runs per entry, alias entries included, so the list length sets the count. `arena cross-judge pool` is also a list, but Arena runs one judge. It tries only values on a model other than the parent's, in list order, so order it by preference. An `inherit-parent` or `auto` value never judges. `swarm workers` is the default model for every worker unless a race or comparison assigns another model per arm.

### 4. Validate

Every real value written must use a detected model and a detected effort at `xhigh` or below. `inherit-parent` and `auto` always pass. If a chosen real value is not available, stop and ask again.

### 5. Write the rule

Write `~/.claude/rules/pstack-models.md` with no frontmatter, the `# defaults: 3` line, a `# budget` line with the chosen label and the effort that label names, and one line per role, using the same labels poteto-mode uses. Overwrite the whole file so re-runs stay idempotent. Shape:

```
# pstack model configuration. One line per role, as `<model> <effort>`. Delete a line to fall back to the skill default.
# `inherit-parent` or `auto` as a value: the role runs on the parent session's model (omit the `Agent` `model` and spawn `general-purpose`). Alias entries in a panel list still count toward its fan-out.
# defaults: 3
# budget: large (xhigh)
feature, refactoring: opus xhigh
bug-fix: opus xhigh
perf-issue: opus xhigh
hillclimb: opus xhigh
judgment and prose: opus xhigh
arena runners: fable high, opus high, sonnet high
arena cross-judge pool: opus high, sonnet high
swarm workers: opus high
interrogate reviewers: fable high, opus high, sonnet high
```

### 6. Confirm

Tell the user the rule was written and that it applies to new sessions. Re-running this skill updates it.

### 7. Offer a verification skill (optional)

Check whether the project has a way to drive the real app for proof (a `verify-*` skill, or an existing harness). If not, offer once: "want a project-local verification skill, so agents can drive the app the way a user does and prove changes work? I can generate one with /jeanz:create-verification-skill." On yes, read [`../create-verification-skill/SKILL.md`](../create-verification-skill/SKILL.md) and follow it. On no, move on without pushing.

### 8. Offer a formal verification skill (optional)

Check whether the project already has a formal verification skill (a project skill that runs a model checker, a proof, or another verifier against the code). If not, offer once: "want a formal verification skill, so agents can prove a key property of your code holds in every case in scope, not only the cases tests reach? I can generate one with /jeanz:create-formal-verification-skill." On yes, read [`../create-formal-verification-skill/SKILL.md`](../create-formal-verification-skill/SKILL.md) and follow it. On no, move on without pushing.

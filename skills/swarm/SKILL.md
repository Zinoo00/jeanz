---
name: swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
disable-model-invocation: true
---

# Swarm

## Start

Before launching anything, add one entry per phase to the session's todo tool. Without one, keep this checklist in the reply and update it at each phase.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
3. Pick the worker model from the `swarm workers` line in `~/.claude/rules/pstack-models.md`. If the rule or that line is missing, use `opus high`. For `auto` or `inherit-parent`, omit `model` so the workers run on the parent model. If the `Agent` tool rejects a value, use the default and say so. If it rejects the default, use the same model at the closest effort its error message allows. For a model race, name each arm's model up front. Pick each subagent's reasoning level for the job, per the Subagents section of the [**poteto-mode**](../poteto-mode/SKILL.md) skill.
4. Give each worker its own writable output when it writes. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Spawn the workers in one message with `subagent_type: "general-purpose"`, `isolation: "worktree"`, and the step 3 model, left unset for `auto` or `inherit-parent`. A worker that runs the app is a lane. When those outnumber what `scripts/lanes.sh` in [**poteto-mode**](../poteto-mode/SKILL.md) prints, spawn that many, queue the rest, and start each queued worker the moment a lane reports. Omit `isolation` only for a worker that reads the user's own checkout and neither changes files nor runs the app. When a worker that edits or runs the app needs uncommitted changes, copy them into its worktree.

Each brief names the branch or commit its worker checks out first.

The first line of each brief is `Read <path>/worker.md before anything else.`, with `<path>` the absolute path of the [**poteto-mode**](../poteto-mode/SKILL.md) skill's folder. That file carries the operator's rules and the lane rule to every worker.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

## Phase D: Report

Return one consolidated in-chat report with a result table, issue one-liners, gaps or dropouts, and the race rule when used.

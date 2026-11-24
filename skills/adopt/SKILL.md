---
name: adopt
description: "Bring one project under jeanz. Build its layers in order, from checks in code through runtime verification, property checks, and formal checks to automation. Keep every project fact inside that project. Use for /adopt, \"set up jeanz for this repo\", or \"tune jeanz for <project>\"."
disable-model-invocation: true
---

# Adopt a project

jeanz is the same for every project. Adopting a project means building that project's own layers with jeanz's skills, in the order below. Each layer makes the next one cheaper. Automation on top of weak lower layers only produces more to clean up.

Everything this skill writes goes in the project, in its code, its `CLAUDE.md`, and its `.claude/skills/`. When the repo is not the user's to change, generated skills go in `~/.claude/skills/`, and nothing is committed to the repo. Nothing about the project goes into jeanz. If the project does not fit a jeanz skill, change the project or its generated skill. Change jeanz only for a flaw any project would hit, and add a fixture case that fails without the change.

## 0. See where the project stands

Run `scripts/status.sh <repo> [app]` from this skill's folder. It prints which layers exist, and its last line says whether the project is ready for automation. It counts layer 3 only after a property run that passed, and it cannot see a run of `verify-<app>`. Read the project's `CLAUDE.md` and obey its rules. They outrank this skill.

## 1. Checks in code

Run [correct](../correct/SKILL.md) on the repo's history. It encodes repeated mistakes across the existing validation layers and records each rule in `CLAUDE.md`. It leaves product code untouched and flags any needed design or type refactors for `/jeanz:poteto-mode`. This layer comes first because only it stops a mistake before code lands.

## 2. Runtime verification

Run [create-verification-skill](../create-verification-skill/SKILL.md). The project gets `verify-<app>`. That skill says how to start a disposable instance, one for each parallel agent, drive it, capture evidence, and clean up. It also holds a feature map that gives every feature one name.

## 3. Property checks, for a web UI

Run [create-property-skill](../create-property-skill/SKILL.md). It reuses the instance, the login, and the feature map that layer 2 found. The feature map fills `FEATURES`. Skip this layer for a project with no web UI.

## 4. Formal checks, where they pay

For a flow with many states, or an algorithm that must not be wrong, use [statechart](../statechart/SKILL.md) or [create-formal-verification-skill](../create-formal-verification-skill/SKILL.md). Most projects need none at first.

## 5. Automation, last

Start this layer only when the last line of `status.sh` says `ready`. When it says `ready only if the project has no web UI`, check that first. Use the autopilot playbooks of [poteto-mode](../poteto-mode/SKILL.md). Use `/loop` to run [maintain-verification-skill](../maintain-verification-skill/SKILL.md) and [maintain-property-skill](../maintain-property-skill/SKILL.md) on a schedule.

## Each visit

Build the lowest missing layer, prove it by running it, and stop. One layer per visit keeps each layer small enough to review. Reply with these facts:

- the `status.sh` output before and after
- what you built, and the run that proves it
- every project fact you had to ask the user for
- anything about the project that did not fit jeanz, and where you handled it

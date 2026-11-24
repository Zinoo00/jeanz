---
name: correct
description: "Update the project's verification framework so repeated agent mistakes cannot pass. Routes each rule to the highest existing validation layer (lint/CI, test, verify-<app>, properties-<app>, formal check, prose last), syncs affected layers, never edits product code, and proves each new check fails without the fix. Use for /correct."
disable-model-invocation: true
---

# Correct

The operator keeps correcting agents for the same mistakes, or wants to update validation standards. Update the project's verification framework so the next agent cannot ship the mistake.

**Verification framework only.** Never edit product code during `/correct`. Only edit lint or CI configs, tests, project verification skills (`verify-*`, `properties-*`, formal verification skills), and the rule table in `CLAUDE.md`. When a mistake is best eliminated by a product architecture or type refactor, add the strongest verification check now and report the product refactor for `/jeanz:poteto-mode` so product code changes flow through the full verification loop.

## Find the mistake classes

If the user passed a specific rule or mistake, start there. Otherwise read recent commits, reverts, review comments, agent instruction files, and workaround comments, and group repeated mistakes into classes (a class counts once it has happened twice).

## Route each class to the highest existing validation layer

Check which layers already exist in the repo before picking. Pick the highest layer that can express the rule:

1. **Lint, typecheck rule, or CI check.** Preferred whenever static analysis can block the bad pattern. Make the error message name the file, type, or function to use instead. If the pattern is already common, fail only when a change adds more.
2. **Behavioral test.** Assert what users or callers observe so the test fails when the behavior breaks and survives internal refactors. Fix or delete brittle tests that still pass when behavior breaks.
3. **Runtime verification (`verify-<app>`).** Add or tighten a feature-map recipe, observable end-state, or driver check when the rule only shows up on the running app.
4. **Web UI property (`properties-<app>`).** Add an app property in `spec/properties.ts` plus its row in `SKILL.md` (or update `spec/config.ts` / `spec/actions.ts`) when the rule is a UI invariant across states over time. Never edit sealed files.
5. **Formal check.** Add or tighten a model invariant or proof when the project has a formal verification skill covering that state machine or protocol.
6. **Docs or `CLAUDE.md` rule last.** Only for judgment calls that no executable check can catch.

**Missing layers:** If the ideal layer does not exist in the project yet (for example, a UI-over-time rule with no `properties-<app>` skill), fall back to the highest existing layer and flag the missing layer in one line. Do not bootstrap a new `create-*-skill` mid-correction; that belongs to `/jeanz:adopt`.

## Sync affected layers and prove every check

- **Targeted cross-layer sync:** When tightening validation in one layer affects an existing entry in another layer (such as a `verify-<app>` recipe, a `KNOWN_ISSUES` entry in `properties-<app>`, or a covered formal model), update only those directly affected entries in the same pass. Leave full-repo drift audits and sealed template upgrades to `/jeanz:maintain-*`.
- **Edit and remove as well as add.** Every rule, property, test, and recipe can be edited or removed when the operator's standard changed, or when it is wrong, stale, or a duplicate. Say why for each.
- **Never weaken a check to get green.** Never disable a lint, loosen an assertion, or hide a new bug in `KNOWN_ISSUES` so that failing code passes.
- **Prove it fails.** Prove every new or changed check fails when the mistake is present. When the product code no longer has the mistake, use a past buggy commit or a temporary reverted scratch break, then confirm the check passes on clean code with only verification-framework edits left in the diff. Run the same command locally and in CI. Exceptions need a reason, an expiry date, and human approval.
- **Leave a live mistake failing.** When the product code still has the mistake, the failing run on the current code is the proof. Leave the check failing so `/jeanz:poteto-mode` fixes the product code against it. Never skip it, mark it as an expected failure, or list it in `KNOWN_ISSUES` to get green.

## Keep the rule table

Maintain one table in the project's `CLAUDE.md` pairing each rule with what enforces it across all layers (lint, test, `verify-<app>` feature, `properties-<app>` property, or formal check). If a rule was already listed with nothing enforcing it, that is a repeat: enforce it at the highest existing layer now. Drop a prose rule once a structural check makes the mistake impossible.

**Reply:** each class with its evidence, the layer chosen (and why higher layers did not apply or were absent), cross-layer syncs made, each check edited or removed with its reason, proof that each new check fails without the fix, each check left failing with the command that runs it, and any product-code refactors queued for `/jeanz:poteto-mode`. When a check is left failing, end with the `/jeanz:poteto-mode` prompt that fixes the product code against it, and tell the operator to commit the checks first so the fix run cannot change them unseen.

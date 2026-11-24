# Golden evals

Changes to jeanz skills and playbooks need numbers, not guesses. Run this set through the [Eval playbook](../skills/poteto-mode/playbooks/eval.md) before keeping a skill edit or folding a subagent.

## Rules

- Change or fold one thing per eval so each delta has one cause.
- Run each task at least twice per variant to catch flaky flips.
- Keep candidates blind to the rubric, the variant name, and the other runs.
- Judge chain following from the opened files and subagent spawns in the transcript, not self report.
- Promote a variant only when quality holds or improves and latency and cost stay bounded.

## Tasks

| # | Chain under test | Hard constraints checked |
|---|---|---|
| 1 | Single-file bug fix | Reproduces and fixes in the main loop, runs one fresh-context verifier, spawns zero coding or comment subagents |
| 2 | Multi-file feature with shared callers | Names the data shape first, builds in the main loop, passes one unified fresh-context verifier with proven safety checks |
| 3 | Parallel independent workstreams | Splits disjoint modules across parallel worktree lanes and merges verified results |
| 4 | Contradicting bug logics (two options and four options) | Builds two competing worktree variants with visual evidence for two options, stops to talk before building four options |
| 5 | Unsettled new work | Runs `grill-me` first, writes no spec file, settles one baseline before coding |
| 6 | Diff with a hidden downstream break and workaround comments | One unified fresh-context verifier proves the break and flags the workaround, then the main loop fixes both and adds a guard |
| 7 | Broken check or missing property during the loop | Adds the missing check and sees it fail first, repairs the broken check, lists each change with its reason, and weakens none to pass |
| 8 | Standalone `/jeanz:correct` across existing layers | Updates validation layers and `CLAUDE.md` rule table without editing product code, flags needed product refactors for `poteto-mode`, and leaves a live mistake's check failing |
| 9 | Web UI change with `verify-<app>` and `properties-<app>` | Runs both project skills automatically inside the verification loop and reports unresolved calls in an out-of-git HTML report |
| 10 | Project onboarding with `/jeanz:adopt` | Builds only the lowest missing layer, proves it by running it, keeps project facts out of jeanz |

## Metrics

Record these numbers for baseline and variant across every trial.

- **Quality.** Blinded rubric pass rate and any task whose outcome flipped between trials.
- **Latency.** Wall time from kickoff to final reply.
- **Cost.** Total tokens and subagent spawn count, split into coding, verification, and parallel spawns.

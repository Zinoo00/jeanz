# Upstream

pstack is by Lauren Tan, under the MIT license. Its home is https://github.com/cursor/plugins/tree/main/pstack. `tools/upstream.txt` lists every path in jeanz that came from it. Every other file is jeanz's own.

| | |
|---|---|
| Source | `harness/pstack/claude-code/` in `cursor/plugins`, which is pstack's generated Claude Code tree |
| Commit | `35a90942a7f02e1ebbc2443643179815f2147954` (2026-11-18) |
| pstack version | 0.15.43 |
| Dropped | `skills/make-bot-ui` (drives Grok Bot, which is Cursor-internal), `docs/harness/` (the run-time Cursor-name adapter, replaced by native text) |
| Moved | pstack's `README.md` is `docs/pstack.md` |
| Added | In `skills/poteto-mode/SKILL.md`, the `grill-me` trigger, which opens every run and makes the confirmed baseline the goal, and the lane paragraph that ends the Subagents section. In `skills/create-verification-skill/SKILL.md`, the text on instances for parallel agents (Isolate, Launch, and step 4). In `skills/poteto-mode/scripts`, `lanes.sh`, which prints how many lanes this machine can run, and its test |
| Reworded | Prompt audit of 2026-11-23. Word and count caps on a reply are qualitative in `ketchup`, `ketchup-video`, `recall`, the `opening-a-pr` playbook, and `worker.md`. Model names carry no version in `skills/poteto-mode/SKILL.md`, `docs/pstack.md`, and `docs/guide/01-setup.md`. `teach` drops two comma rules and no longer needs an image tool. `technical-writing` indents snippets the way the project does. `statechart/references/render.md` drops a line about an older skill. The `comment-sicko` description says when to spawn it |
| Corrected | Stale facts and files that disagreed, found by the same audit. `swarm` follows the lane rule. `poteto-help` and three doc pages say that `/schedule` runs in the cloud, and they point at `/loop`. `pause-safely`, `autopilot-full`, `review-bot-triage`, and `create-formal-verification-skill` name only what the plugin has. Eight skills link each skill they name. `poteto-mode` defines the control skill. `opening-a-pr`, `hillclimb`, and `figure-it-out` agree with the files they cite |
| Changed | On 2026-11-24, `poteto-mode` moved to a two-actor default of the main loop plus one unified fresh-context verifier. Added `playbooks/verification-loop.md` for automatic post-test checks, framework strengthening, competing bug variants up to three, and out-of-git HTML review reports. Updated `correct` to edit only the verification framework across existing layers, updated `how` to read small scopes directly, and updated `no-comments` to encode reversible constraints. Expanded `eval.md` for repeated golden-set trials, updated the build playbooks, `figure-it-out`, `poteto-help`, `docs/pstack.md`, and the guide, and dropped per-reply principle citations. The loop writes each check before its fix, and `correct` leaves the check for a live mistake failing. Both add, edit, and remove checks. On 2026-11-25, the shape of the work set the default. One unit keeps the two actors. Several independent units run the full checks first, then as many lanes as `lanes.sh` measures. `swarm` and `autopilot-full` queue what the machine cannot run. `worker.md` gained the lane rule and the rule that a worker starts no verifier. A run works from the project's folder and matches a playbook once the baseline is confirmed. The verifier runs as `Explore` on the working tree, and `figure-it-out` sends its units to lanes. A diff of about 50 lines or fewer is cleaned in the main loop, and `/simplify` runs only above that. `autopilot-full` drops the `/no-comments` pass and gives each owner the playbook's path. `opening-a-pr` and `babysit` each name the autopilot owner as their one exception |
| Renamed | `references/bugbot-triage.md` in `skills/poteto-mode` is `references/review-bot-triage.md`. The `@cursor-skill` packages under `skills/*/scripts` are `@jeanz-skill` |

## Another source

`skills/grill-me` follows the interview in Matt Pocock's `grilling` skill, from https://github.com/mattpocock/skills at commit `abeeaf9`, under the MIT license. The text is jeanz's own.

## Syncing a newer pstack

1. Diff the upstream tree between the commit above and the new one with `git diff <old>..<new> -- harness/pstack/claude-code`.
2. Apply each change to the matching jeanz file. Skill names are unchanged. The table above lists the paths that differ.
3. Translate Cursor names with `docs/claude-code-port.md`, then run `tools/check.sh` until it passes.
4. Add each new upstream path to `tools/upstream.txt`, and remove each path that upstream dropped.
5. Update the commit and the version here.

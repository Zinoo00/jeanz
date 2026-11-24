# Design

jeanz is one kit for every project. It builds the layers below into a project, in order, and checks that each layer still works. It holds no project's facts.

## The layers

The order comes from Lauren Tan's talk "All Code Is Slop (Except Mine)". Most of the effort goes into the code, then into verification. Prose is for judgment only. Automation comes last.

| # | Layer | jeanz skill | What the project gets |
|---|---|---|---|
| 1 | Checks in code | `/jeanz:correct` | Lints, CI checks, tests, targeted cross-layer validation sync, and a rule table in `CLAUDE.md` without editing product code |
| 2 | Runtime verification | `/jeanz:create-verification-skill`, `/jeanz:maintain-verification-skill` | `verify-<app>`, which starts the app, drives it, captures evidence, cleans up, and maps the features |
| 3 | Property checks, for a web UI | `/jeanz:create-property-skill`, `/jeanz:maintain-property-skill` | `properties-<app>`, which explores the app at random and checks rules in every state |
| 4 | Formal checks | `/jeanz:create-formal-verification-skill`, `/jeanz:statechart` | A model or a proof for the code where a bug costs most |
| 5 | Automation | `/jeanz:poteto-mode` playbooks, `/loop` | Unattended runs on this machine, once layers 1 to 3 hold |

`/jeanz:adopt` walks one project through the layers, lowest missing layer first. Layers 1, 2, 4, and 5 are pstack's. Layer 3 and `adopt` are jeanz's own.

New work starts with `/jeanz:grill-me`, which is jeanz's own too. It interviews the user until both sides hold one picture of the work, and then it states a short baseline. It writes no spec. Every `/jeanz:poteto-mode` run opens with it.

## Two tiers

- **The baseline** is jeanz, with its skills, templates, fixture, and checks. It is the same for every project.
- **The tuning** is the project's own generated skills, rule table, and code.

When a project does not fit, the project or its generated skill changes. jeanz changes only for a flaw any project would hit, and the change comes with a fixture case that fails without it. The rule table in [CLAUDE.md](../CLAUDE.md) says what enforces each part of this, and which parts rest on judgment.

## Main loop and verification loop

Normal tasks run with two actors. The main loop reads, codes, runs local checks, cleans slop and comments, and fixes failures. One fresh-context verifier subagent then checks breakage, downstream safety, workaround comments, and check integrity in one pass. Extra subagents run only for parallel lanes, two to three competing worktrees on contradicting bug logics, high-stakes panels, or bulk read-only searches.

After any code change, `poteto-mode` runs the [Verification loop](../skills/poteto-mode/playbooks/verification-loop.md) automatically without waiting for the user. It runs local tests, `verify-<app>`, and `properties-<app>` when present for web UI changes, then calls the single fresh-context verifier. Proven findings loop back into main-loop fixes and verification-framework strengthening for up to three rounds, never weakening an existing check. More than three contradicting options stop for a talk with the user. Any remaining blockers, human calls, or competing variants go into one out-of-git HTML report under `~/.jeanz/reviews/` instead of markdown files in the repo.

## Lanes

Agents that work at the same time each get a lane. A lane is one agent, its own worktree, and its own instance of the app, front end and back end both. A worktree splits the code, but agents that share one running app still wait on each other to test. Every lane runs on this machine, with no container and no cloud machine.

The rule is in the Subagents section of [poteto-mode](../skills/poteto-mode/SKILL.md). A `/jeanz:poteto-mode` session reads it, and so does each `poteto-agent` that it starts. The project's `verify-<app>` skill says how an instance launches from any worktree, how it gets its ports, and whether instances share a database. `props.sh` locks the instance it drives, so a lane that points at another lane's instance is refused. A skill inside the repo keeps an evidence folder for each checkout, so `status.sh` reports the runs of the checkout it is given.

## What an app supplies to the property skill

| Need | The app's answer | Where it lives |
|---|---|---|
| A disposable instance | Start and stop commands, every outbound channel off, `DISPOSABLE="yes"`, and a host on this machine or listed in `DISPOSABLE_HOSTS` | `props.config.sh`, `SKILL.md` |
| Sign-in | `LOGIN` prints session cookies, or `HEADERS` carries them. `READY_URL` and `READY_TEXT` prove that the sign-in worked. | `props.config.sh` |
| Signs of being signed out | `SIGNED_OUT` | `spec/config.ts` |
| Dangerous controls | `data-destructive` on the control, in the app. Failing that, words and selectors. | The app, or `spec/config.ts` |
| Dangerous requests | `DANGER_REQUESTS` | `spec/config.ts` |
| Known issues | `KNOWN_ISSUES`, each with a reason and an end date | `spec/config.ts` |
| Features | `FEATURES`, each with a name, a URL pattern, and a start URL | `spec/config.ts` |
| Ways into hard places | Action generators | `spec/actions.ts` |
| The app's own rules | Properties | `spec/properties.ts` |
| Quirks | Gotchas | `SKILL.md` |

The rest of a generated skill is sealed and identical across apps. That includes `GUIDE.md`, which holds the commands, the triage steps, and the protections. `SEALED.sha256` in the skill lists the sealed files, and an upgrade replaces them.

## How the baseline is tested

Each behavior the sealed files claim has a case in `skills/create-property-skill/fixture/` that fails without it. A behavior with no case is not part of the baseline. The cases sit in three tests, fastest first. A fourth script proves that the cases can fail.

| Test | What it covers | Time |
|---|---|---|
| `rules.test.ts` | Each decision the spec makes from a name, a request, or an address | Under a second |
| `props.test.sh` | `props.sh`, run against a stand-in `bombadil` | Under a minute |
| `selftest.sh` | The sealed files in a real browser, against the fixture app in `fixture/app` | 5 to 7 minutes |
| `mutants.sh` | It breaks one sealed behavior at a time, and it fails when none of the three tests notices | About an hour, on demand |

`tools/check.sh` runs the first two. The commit hook and the push hook run the third when a file it reads changed. They first check that each break in `mutants.sh` still applies to the files. Nothing runs the whole table by itself. Run the lines you changed before a commit, and the whole table before a release.

The checks have tests too. `tools/check.test.sh` plants a violation of each rule and looks for it under that rule. It keeps its own list of the rules, and it fails when `tools/check.sh` runs another set. `tools/hooks.test.sh` runs the hooks against a stand-in check.

Changes to playbooks and skills are tested against the ten-task set in [golden evals](golden-evals.md). Each task runs at least twice per variant to catch flaky flips and compare quality, latency, and cost.

## Limits

- The property skill covers web UIs only. Other kinds of app use layer 2.
- Sign-in is by cookie or header. An app that keeps its session in browser storage adds a cookie sign-in to its disposable instance.
- Cookie values show in the process list during a run.
- The record of stopped and failed requests follows the run from page to page through session storage. A page on another origin starts a new record.
- The run cannot see into a frame from another origin, so the guard drops every click inside one.
- The guard and the request block have the limits that [the guide](../skills/create-property-skill/templates/GUIDE.md#protections) lists. The disposable instance covers those.
- The request block holds a new tab that a link, a form, or `window.open` names. A tab that opens another way breaks `noNewTab`.
- A run that gets no new state in its last half exits 3. A page that stops answering later than that only slows the run, and `states` in the summary shows how much the run checked. The rule cannot tell a page that stopped answering from a page that took that long, so a slow app needs a longer run.
- A signal that stops `props.sh` stops Bombadil too. The record of that run stays empty, and `status.sh` says that the run has no result. `kill -9` gives `props.sh` no chance to do that. Bombadil then runs on until its time limit, and the next run takes the stale lock.
- The lock for an instance sits in the folder that holds the evidence folders. Two skills that set an `OUT_ROOT` of their own share the lock only when those folders have one parent. It names an instance by the host and port as `ORIGIN` spells them, so `localhost` and `127.0.0.1` on one port are two instances to it.
- A skill kept in `~/.claude/skills/` serves every checkout of its project, so those checkouts share its runs.
- A run that breaks nothing exits 3 until it reaches every listed feature. A feature that random steps cannot reach needs a `start` address.
- `props.sh doctor` compares the sealed files with the skill's own `SEALED.sha256`. It cannot see an edit whose checksum someone wrote into that record. `status.sh` and `upgrade.sh` compare with jeanz's own record, so they do see it.
- The hooks check a commit, a merge commit, and a push. A rebase, a cherry-pick, and `--no-verify` each make a commit that no hook checks until it is pushed.
- `shrink` is experimental in Bombadil 0.7.10.

## Not built, and what would start the work

| Item | Build it when |
|---|---|
| Scrolling inside panels and grids | Two apps needed the same action generator |
| Sign-in through an external browser (`bombadil browser test-external`) | An app cannot add a cookie sign-in |
| A type-check of a generated skill's own files | A wrong type in an app's file costs a run |
| A block for dangerous WebSocket messages and worker requests | An app's dangerous control sends one |
| A request block that reads a body | An app sends a dangerous write and a safe one to the same address |
| The checks on a remote, in CI | The repo gets a remote that someone else pushes to |
| A script that ports a newer pstack | The next pstack sync |
| A script that keeps lanes running and hands each one the next job | Launching a lane costs more than the jobs it serves |
| A personal mode skill (`/jeanz:automate-me`) | There is enough real history to mine |

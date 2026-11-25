# jeanz

jeanz holds what every project needs. One project's facts never go in it.

- pstack is the only reference for how a skill is shaped. `tools/upstream.txt` lists the paths that came from it.
- When an app does not fit a jeanz skill, fix it in that app's generated skill or in the app. Change jeanz only for a flaw any app would hit, and add a fixture case that fails without the change.
- When the user corrects you, turn the correction into a check and add a row below. Prose is for judgment calls only.
- [The design](docs/design.md) explains the layers, the two tiers, what an app supplies, and what is deliberately not built.

## Rules and what enforces them

| Rule | Enforced by |
|---|---|
| Claude Code names only | `tools/check.sh` fails on each name that `tools/names.txt` lists. It scans every text file outside the `corpus` folders, except the files that its `EXEMPT` line names, which have to hold those names |
| Skill and agent frontmatter is a strict subset of YAML that Claude Code reads, with known keys only | `tools/frontmatter.py`, which `tools/check.sh` runs |
| A link points at a file and a heading that exist, and `jeanz:<name>` names a skill or an agent | `tools/check.sh` |
| The files that an app fills ship empty | `tools/check.sh` holds the exact text of each one and fails on any other line. It also fails on non-ASCII text in `templates/` |
| A change to a sealed file or the guide carries no single app's words, labels, numbers, or URLs | Judgment. Read the diff of `templates/` before each commit |
| The guide lists every property that the sealed spec exports | `tools/check.sh` |
| A generated property skill's sealed files stay as jeanz shipped them | `props.sh doctor` compares them with `SEALED.sha256`. `status.sh` and `upgrade.sh` compare them with `sealed-history.txt`, which lists every sealed file that jeanz shipped. `tools/seal.sh` writes both records, and `tools/check.sh` fails when one is stale |
| `props.sh`, the type-check, its lock file, and jeanz's own text name the same Bombadil version | `tools/check.sh` |
| Each behavior the sealed files claim works | `skills/create-property-skill/fixture/selftest.sh`, which the hooks run |
| Each case for a sealed behavior can fail | `skills/create-property-skill/fixture/mutants.sh` breaks one behavior at a time and fails when no test notices. Nothing runs the whole table by itself. The hooks check that each break still applies to the files |
| `props.sh` refuses with a different exit code for each cause, and reports what a run did | `skills/create-property-skill/fixture/props.test.sh` runs it against a stand-in `bombadil`, and `tools/check.sh` runs that test |
| `status.sh` reports each layer that a project has, and what is missing. It counts a property skill only after a run that passed | `skills/adopt/scripts/status.test.sh`, which `tools/check.sh` runs |
| The spec files type-check against Bombadil's published types. They hold nothing that switches the check off, such as `any`, a cast, or a call that returns `any` | `tools/typecheck.sh`, which `tools/check.sh` runs |
| jeanz's own text follows the writing rules that a script can judge | `tools/prose.py`, which `tools/check.sh` runs on every `.md` file, template, and manifest description outside `tools/upstream.txt` |
| jeanz's own text follows the writing rules that a script cannot judge | Judgment, with `/jeanz:unslop` and `/jeanz:technical-writing` |
| jeanz's own text keeps one name for each thing | `tools/check.sh` fails on a term that `tools/terms.txt` lists as replaced |
| An exception to a rule names its file and the text it excuses | `tools/check.sh` fails on a line of `tools/check-allow.txt` whose text is gone |
| The README lists every skill that is jeanz's own | `tools/check.sh` |
| Each rule in the checks fails on a planted violation | `tools/check.test.sh`, which `tools/check.sh` runs. It lists the rules, fails when `tools/check.sh` runs another set, and looks for each plant under its own rule |
| The check runs each test that is jeanz's own | `tools/check.sh` fails on a test file that its `TESTS` line lacks, and `tools/check.test.sh` fails when a listed test does not run |
| The checks pass on each commit, each merge commit, and each push | The hooks in `tools/hooks`, once `git config core.hooksPath tools/hooks` is set in the clone. `tools/check.sh` says when it is not set. `tools/hooks.test.sh` runs the hooks against a stand-in check |
| A commit that skipped the hooks is checked before it is used | Judgment. Run `tools/check.sh` after a rebase, a cherry-pick, or `--no-verify` |
| Each decision the spec makes from a name, a request, or an address gives the expected answer | `skills/create-property-skill/fixture/rules.test.ts`, which `tools/check.sh` runs |
| A change to the sealed files comes with a case in `fixture/` that fails without it | Judgment. Add a line for the behavior to `fixture/mutants.sh` and run that line |
| An entry joins `spec/defaults.ts` only if it destroys data or ends the session in any app | Judgment. `rules.test.ts` holds the list, so a new entry needs an example there |
| A fan-out uses this machine's fullest potential, measured and not guessed | `skills/poteto-mode/scripts/lanes.sh` prints the count from the cores and the free memory. `skills/poteto-mode/scripts/lanes.test.sh`, which `tools/check.sh` runs, checks it on stand-in machines |
| A run opens its playbook once the baseline is confirmed, starts as many lanes as `lanes.sh` prints, and each lane runs its own instance | Judgment. Read it from the run's transcript, as golden tasks 3 and 5 do |
| A change to a skill or a playbook shows what it costs on a real run | `skills/poteto-mode/scripts/run-stats.py` prints the turns, the agents, and the jeanz text of one run from its transcript. `skills/poteto-mode/scripts/run-stats.test.sh`, which `tools/check.sh` runs, checks it on a stand-in run |
| A run that outlasts its chat keeps its queue in files and its lanes in background sessions | Judgment. Read it from the run's transcript, as golden task 11 does. `skills/poteto-mode/scripts/lane-sessions.sh` reads the state of each unit, and `skills/poteto-mode/scripts/lane-sessions.test.sh`, which `tools/check.sh` runs, checks it against a stand-in `claude` |
| A worker reads `worker.md` and the Principles section, and leaves the rest of the mode file to the chat that runs the playbook | Judgment. `skills/poteto-mode/scripts/run-stats.py` counts the workers that opened the whole file as `mode_rereads`, and golden task 3 checks it |

# jeanz

jeanz is Jin's software factory for Claude Code, in one plugin. It carries [pstack](docs/pstack.md) by Lauren Tanm [grill-me](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md) by Matt Pocock, and adds Jin's own skills on top. pstack supplies the playbooks, the principles, and the verification skills. Both follow one rule. When an agent is corrected, the correction becomes a check, such as a type, a lint, a test, or a property. It does not become another line of prose. There contains structural changes that follow suggested by [Building agents: When to fold subagents into your main agent loop](https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop) and [How the Claude Code team thinks about verification](https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/#differential-tests-the-old-system-is-the-oracle).

## Install

```bash
claude plugin marketplace add Zinoo00/jeanz
claude plugin install jeanz@jeanz
```

jeanz already contains pstack, so do not install pstack separately. After you change jeanz, run `claude plugin update jeanz@jeanz` so that Claude Code picks up the change.

For Antigravity, run `tools/antigravity.sh`, and run it again after each change. It installs the committed tree as an Antigravity plugin. The agents there inherit the session's model, and one rule routes every model role to Antigravity's Neon model.

Property checks need [Bombadil](https://github.com/antithesishq/bombadil) 0.7.10 on `PATH`. These commands install it on a Mac with Apple silicon. On another machine, `props.sh doctor` points at the release page.

```bash
curl -L -o ~/.local/bin/bombadil https://github.com/antithesishq/bombadil/releases/download/v0.7.10/bombadil-aarch64-darwin
chmod +x ~/.local/bin/bombadil
```

## Get started

1. Run `/jeanz:setup-pstack`. It picks a model for each role and writes `~/.claude/rules/pstack-models.md`.
2. Run `/jeanz:adopt` in a project. It builds that project's layers in order. What it writes goes in the project, or in `~/.claude/skills/` when the repo is not yours to change.
3. Run `/jeanz:grill-me` before new work. It interviews you until you and the agent hold one picture of the work, and it writes no spec.
4. Run `/jeanz:poteto-mode <task>` for work that needs rigor. It picks a playbook and runs the other skills as the steps need them.

[The design](docs/design.md) explains how jeanz is put together, what stays the same for every project, and what each project tunes. [The pstack page](docs/pstack.md) lists pstack's skills, playbooks, and principles. [The guide](docs/guide/README.md) walks through them.

## jeanz's own skills

| Skill | Use it when |
|---|---|
| `/jeanz:grill-me` | New work starts, and its shape is not settled. The skill interviews you in rounds until nothing is open, then states a short baseline for you to confirm. |
| `/jeanz:adopt` | A project should work the jeanz way. The skill builds the lowest missing layer, proves it, and reports where the project stands. |
| `/jeanz:create-property-skill` | A web app has no way to find bugs on paths nobody scripted. The skill generates a `properties-<app>` skill that explores the app with Bombadil and checks properties in every state. |
| `/jeanz:maintain-property-skill` | jeanz changed its property templates, or a `properties-<app>` skill no longer matches its app. The skill upgrades the sealed files and proves the skill again. |

## Checks

```bash
tools/check.sh
skills/create-property-skill/fixture/selftest.sh
git config core.hooksPath tools/hooks
```

`tools/check.sh` needs npm. The self-test drives a fixture app in a real browser. The third command turns on the hooks, which run the checks on each commit, each merge commit, and each push. Run it once per clone. After you change a sealed template, run `tools/seal.sh`.

[CLAUDE.md](CLAUDE.md) lists each rule and the check that enforces it. [The design](docs/design.md#how-the-baseline-is-tested) says what each test covers, and when to run the break table in `mutants.sh`.

[The upstream record](UPSTREAM.md) says where pstack came from and how to sync a newer one. [The port map](docs/claude-code-port.md) maps pstack's names to Claude Code.

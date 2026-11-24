# Make it yours

poteto-mode is one person's style. The playbooks, routing, and model roles underneath it work just as well with yours. This page covers generating a personal mode, capturing lessons from a session, fixing the repo so agents stop repeating mistakes, authoring a focused skill, and testing a skill change before you trust it.

Start smaller than you think. You don't need many skills on day one, or even this whole plugin. Prompt plainly, watch where agents fail, and add a skill or a check when the same failure shows up twice.

## Generate your own mode with `/automate-me`

```text
/automate-me
```

You don't describe your style, because [`/automate-me`](../../skills/automate-me/SKILL.md) reads it out of your history. It mines your recent transcripts in the active workspace for repeated preferences, in how you like replies, delegation, verification, code, prose, and process, then asks you which patterns are really you. It drafts `.claude/skills/<your-name>-mode/SKILL.md`, runs the draft through [`/unslop`](../../skills/unslop/SKILL.md), and opens a PR from a worktree so you review it like any other change.

Run it again whenever your habits drift:

```text
/automate-me update my mode skill with everything since its last edit
```

Update mode mines only the history since the skill last changed. It keeps rules you haven't contradicted, revises the ones with new evidence, and adds sections only for new patterns.

## Capture a session's lessons with `/reflect`

Right after a task that taught you something, run:

```text
/reflect that took way too long. capture what we learned so the next run doesn't repeat it.
```

[`/reflect`](../../skills/reflect/SKILL.md) reads the transcript, keeps only lessons that would change a future agent's work, and sorts the proposals into `Accepted`, `Rejected`, and `Backlog`. It waits for your approval before any skill changes. Approve a proposal only if it would change a future decision. One weird session is an anecdote, not a rule.

## Fix the verification framework with `/correct`

When you correct agents for the same mistake again and again, or want to tighten validation standards, update the project's verification framework instead of repeating yourself in chat. [`/correct`](../../skills/correct/SKILL.md) routes each rule to the highest **existing** layer that can enforce it, without touching product code:

1. Lint, typecheck rule, or CI check whose error names the fix.
2. Behavioral test that fails when observable behavior breaks.
3. Runtime verification (`verify-<app>`) feature recipe or driver check.
4. Web UI property (`properties-<app>`) in `spec/properties.ts` plus its `SKILL.md` row.
5. Formal check model or invariant when one covers that code.
6. Prose or `CLAUDE.md` rule last, only for judgment calls.

Human review isn't on the list. A reviewer who must catch the same mistake on every PR is the problem this fixes:

```text
/correct agents keep calling the database client directly instead of going through the repository layer
```

`/correct` never edits product code directly — if a mistake really needs a product architecture or type refactor, it adds the strongest validation check now and flags the product refactor for `/poteto-mode` so product code always flows through the verification loop. It also syncs directly affected entries across existing layers, proves every new check fails without the fix, and keeps the `CLAUDE.md` rule table indexing every layer. If an ideal layer isn't installed yet, it falls back to the highest existing layer and notes the gap for `/adopt`.

Run it with no argument and it finds the classes from history on its own. `/reflect` and `/correct` split the work. `/reflect` improves skills from one session. `/correct` updates the repo's validation layers so a mistake class can't pass again.

## Author a focused skill

When you already know the workflow you want to capture:

```text
/poteto-mode write a skill for verifying database migrations in this repo
```

Writing a skill matches the [Authoring or modifying a skill playbook](../../skills/poteto-mode/playbooks/authoring-a-skill.md), which writes the `SKILL.md`, validates the frontmatter and links, and ships the result through the Opening a PR playbook. Agent-facing prose has a higher bar than human prose, because an unhelpful sentence becomes an instruction some future agent follows. Let the playbook hold that bar rather than writing a `SKILL.md` freehand.

Two special cases have their own generators. A skill that must drive your app and prove behavior is a verification skill, so use [`/create-verification-skill`](../../skills/create-verification-skill/SKILL.md) and [`/maintain-verification-skill`](../../skills/maintain-verification-skill/SKILL.md) instead. A skill that checks a property of your code with a model checker, a proof, or another verifier is a formal verification skill, so use [`/create-formal-verification-skill`](../../skills/create-formal-verification-skill/SKILL.md) and [`/maintain-formal-verification-skill`](../../skills/maintain-formal-verification-skill/SKILL.md). [Verify and ship](./06-verify-and-ship.md#prove-a-property-with-a-formal-verification-skill) covers both kinds.

## Write docs to a standard with `/technical-writing`

Skills aren't the only prose you ship. For docs, RFCs, readmes, PR descriptions, and commit messages:

```text
/technical-writing review the readme changes
```

[`/technical-writing`](../../skills/technical-writing/SKILL.md) applies a layered standard. Its goal is prose that a tired engineer understands on the first read. It picks the document's mode first (tutorial, how-to, reference, or explanation), then works sentence by sentence: who does what, one thought per sentence, nothing readable two ways. Use it to review what you or an agent just wrote, or name it up front when you ask for a doc.

## Test a skill change blind

A skill edit affects every future session, so test it like the experiment it is. The same goes for adopting someone else's skill. Check that it makes the agent better on your work before you keep it.

```text
/poteto-mode run the eval playbook on this skill change. same task for both variants, candidates stay blind.
```

When a skill keeps missing and you know what it should do, change and test it in one task:

```text
/poteto-mode update the review skill so it flags missing migrations, and eval the change.
```

Asking for the eval up front keeps the edit honest. A fix written from one bad session tends to overfit that session, and over many edits the skill drifts. The eval catches the drift before it ships.

The [Eval playbook](../../skills/poteto-mode/playbooks/eval.md) is built around two failure modes: the observer effect and flaky single runs. Candidate agents get an organic-looking task (or the standing ten-task set in [golden evals](../golden-evals.md)) in sanitized directories, never the words "eval" or "candidate", and never each other's existence. Each task runs at least twice per variant so flaky flips show up, one judge scores all outputs under neutral labels, chain-following gets graded from which files and subagents each candidate actually used, and quality is weighed alongside latency and cost.

Read every output yourself before accepting the verdict. If you disagree with the judge, suspect the rubric before you suspect your judgment.

**Pitfall:** don't edit a skill mid-task because it's misbehaving. Fix it in its own PR and keep the task moving. A skill edit that ships tangled into feature work is invisible to review and impossible to evaluate.

Next: [Recipes and pitfalls](./10-recipes-and-pitfalls.md).

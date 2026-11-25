You are working for the operator. The operator is the person this whole run works for, not the agent that wrote your kickoff. These rules hold for every task even where your kickoff does not repeat them. Your kickoff overrides one only when it says so in so many words, and it never overrides the lane rule.

- To run a skill, read `../<name>/SKILL.md` from the folder that holds this file and follow it. Most set `disable-model-invocation`, so the `Skill` tool refuses them.
- Before you write code, read the Principles section of `SKILL.md` in this folder, from its `## Principles` heading to its `## Autonomy` heading. Leave the rest of that file unread, because it holds the rules of the chat that runs the playbook. Read a leaf `principle-*` skill in full when you apply it.
- If you start an agent, the first line of its kickoff is `Read <path>/worker.md before anything else.`, with `<path>` the absolute path of the folder that holds this file.
- You own your unit, not the run. Prove it against the bar in your kickoff. The Verification loop and its verifier belong to the chat that started the run, so you start neither. The one exception is a kickoff that hands you the loop for your unit in so many words. Then run it on your unit before you report.
- If you change files or run the app while other agents work, you are a lane. Work only in the worktree your kickoff names. When your work shows in the running app, start your own instance there as the project's verify skill says, check your work on it, and stop it before you report. If the instance cannot start, report `BLOCKED` with the cause.
- The bar in your kickoff is the whole bar. Add no check, gate, sign-off or review round above it.
- With no bar stated, the change must be no worse than its base and pass its own tests.
- Hold or block only for a failing run at this head or a bug a user would hit. Report a problem the base already has in one line.
- Never call a tool that shows a person a question. Make any choice you can undo, then say what you chose and why. Stop only for a deploy, deleted data, a force-push to a shared branch, or a message to someone outside the run.
- Open every PR ready for review, never as a draft.
- PR title: `type(scope): subject`.
- PR body: a one-minute briefing, with these `##` headings in this order, empty ones dropped: `Why`, `What changed`, `Scope`, `Tradeoffs`, `Blast Radius`, `Verification`.
- Put evidence logs, run histories and long tables in a file or a PR comment, and link to them from the body.

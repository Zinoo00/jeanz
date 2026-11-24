---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Use why for motivation."
disable-model-invocation: true
---

# How

Explore the codebase to answer "how does X work?" questions.

If the scope is ambiguous, state your interpretation and explore. The user can redirect.

## 1. Explain

For a focused subsystem or a handful of files, explore directly in the main loop so context stays intact without subagent handoff overhead. Spawn one read-only `Agent` with `subagent_type: "Explore"` only when the search spans a large tree or bulk files that would bloat the main context window; if you spawn one, run `git status` before and after to confirm it edited nothing.

Write an architectural explanation a senior engineer unfamiliar with this area can read and walk away with a solid mental model: runtime flow, key types, ownership, and non-obvious parts. Do not edit files.

## 2. Present

Present the explanation directly with exact file citations. If you used `Explore`, lightly tighten for conversation context without rewriting from scratch.

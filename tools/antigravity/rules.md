# Antigravity model routing

The jeanz skills were written for Claude Code. In Antigravity, every model role runs on Gemini 4 Neon.

- Where a skill names `opus`, `fable`, or `sonnet`, use Gemini 4 Neon at the effort level that the skill gives.
- When a tool takes a model ID, pass `gemini-4-neon-low`, `gemini-4-neon-medium`, `gemini-4-neon-high`, or `gemini-4-neon-xhigh`. Use `gemini-4-neon-xhigh` for `max`.
- When a tool takes only a tier, leave the model unset, so that the subagent inherits this session's model.
- When this session does not run on a Neon model, say so before you start a subagent.
- A panel that lists several models runs every seat on Neon.
- This rule stands in for the `pstack-models` rule, which `/setup-pstack` writes for Claude Code only.

## Review artifacts

- When a run ends with unresolved blockers, human calls, or competing variants, present one consolidated report.
- Write it as a user-facing artifact in the conversation artifact folder with copied screenshots, or as a browser-viewable HTML file under `~/.jeanz/reviews/`.
- Never write markdown review or issue-report files into the project repository.
- Skip creating an artifact when the run finishes clean with no open decisions.

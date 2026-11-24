### Opening a PR

Run this when a playbook step says to open a PR.

Work from a git worktree off trunk, and keep unrelated work out of it. Rebase into small, landable commits. Ensure **Verification loop** (`playbooks/verification-loop.md`) passed on the current head, or run `/simplify` and **no-comments** over the diff before commit.

Title: `type(scope): subject`, naming a real symbol when one carries the change. Body: a one-minute briefing with these `##` headings in order, dropping empty ones: `## Why`, `## What changed`, `## Scope`, `## Tradeoffs` (only rejected alternatives a reviewer would otherwise ask about), `## Blast Radius`, `## Verification`.

Stack follow-ups by base branch. Open PRs ready, with `gh pr create` without `--draft`, or `origin pr create --status open` when Origin's CLI resolves the repository. Opening a PR does not start a babysit.

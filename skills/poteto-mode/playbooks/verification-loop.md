### Verification loop

Run this automatically after implementing any code change, before opening a PR or reporting done. Do not wait for the operator to invoke post-test skills or approve reversible fixes.

**Two actors by default: the main loop builds, tests, cleans, and hardens; one fresh-context verifier audits the diff.** Scale up to extra subagents only for parallel work, A/B variants, or high-stakes contested reviews.

1. **Self-verify and clean in the main loop.**
   - Run the repo's typecheck, lint, and tests for the touched scope, then prove behavior on the real artifact through the control skill (`verify-<app>` when present, otherwise browser tools for UI or `tmux` for CLI or TUI). Never stop at "it compiles" (**principle-prove-it-works**).
   - Check `.claude/skills/` and `~/.claude/skills/` for `properties-<app>`. When one exists and the diff touches web UI or user-facing API behavior, start a disposable instance in this lane, run `props.sh run 2m` (or longer when requested), triage any violation, and stop the instance.
   - Run `/simplify` in the main loop and strip narrating, stale, or redundant comments directly. Do not spawn a separate comment-only subagent on routine diffs.

2. **Run ONE unified fresh-context verifier subagent (the author never signs off alone).**
   Spawn one isolated subagent with the goal, the diff against base, and the verification evidence. In a single pass, it must:
   - **Break it (`interrogate` bar):** Try to break the change with a real command, test, or repro script. Report only run-proven failures; drop unproven style or speculative nitpicks.
   - **Prove safety (`blast-radius` bar):** Identify hidden downstream breakage grep misses and prove the one key safety fact by running code.
   - **Audit comments and checks (`no-comments` and anti-cheat bar):** Flag leftover workaround or constraint comments. For each check, test, lint, recipe, or property the diff edits or removes, test its base version against the new code. Report every edit, removal, or `KNOWN_ISSUES` entry that hides a defect or that neither the goal nor a fault in the check explains.
   Reserve multi-seat [**interrogate**](../../interrogate/SKILL.md) panels strictly for genuinely high-stakes, contested, or security-critical diffs (or when explicitly requested).

3. **Fix, harden, and loop (capped at 3 rounds).**
   - Fix every verified product failure at its root cause in the main loop (**principle-fix-root-causes**). When earlier checks missed the failure, write its check before the fix. Turn the repro into a check at the highest existing layer of [**correct**](../../correct/SKILL.md)'s ladder that can express it, see it fail on the current code, then fix and see it pass. Encode reversible in-scope constraints as a type, test, or lint without pausing to ask.
   - **Keep the verification framework current:** Add, edit, or remove any rule, property, test, or recipe that the task or a framework error calls for, without waiting to be asked. That covers a broken `verify-<app>` driver or selector, a missing `properties-<app>` feature or property, a weak test, a check that still asserts behavior the task changed on purpose, and a check the task makes obsolete. Inside a code-changing task, you may also harden types or structure on files already in scope.
   - **Strict anti-weakening rule:** Every change to a check needs a reason from the goal or a fault in the check itself. Passing is never the reason, so never weaken, disable, bypass, or remove a check, relax an assertion, or add a new bug to `KNOWN_ISSUES` to go green. Prove every newly added check fails without the fix. Never edit installed plugin skills mid-task; record durable skill follow-ups in one line.
   - Re-run affected local checks and one fresh-context re-check on the updated diff. If **2 fixes sharing one premise** fail the same check, apply **principle-attack-the-premise** to test the premise directly before writing another fix. Stop after 3 rounds if still blocked and report exact failing repros.

4. **Contradicting bug logics: A/B test up to 3 variants.**
   When competing bug fixes or interpretations genuinely contradict each other and tests or runtime evidence cannot objectively pick one winner:
   - **2 to 3 variants:** Build each variant in its own isolated git worktree branch (leaving the main branch clean), verify each on the real artifact, and capture side-by-side screenshots or runtime outputs for the user to choose. Once the user picks, apply the winner and prune the losing worktrees.
   - **More than 3 variants:** Stop before building and discuss with the user to narrow the choices or settle the premise.

5. **Consolidate unresolved items into one visual report (never repo `.md` files).**
   Skip this step when the run finishes clean with zero open decisions. Whenever unresolved blockers, human decisions, or A/B/C comparisons remain:
   - Write one disposable, self-contained HTML report at `~/.jeanz/reviews/<run>/report.html` with screenshots saved in `~/.jeanz/reviews/<run>/shots/` (outside git so it opens in any browser across any agent and deletes in one `rm -rf`). Never write `.md` report files into the project repo.
   - Use a consistent layout: quick-count summary table at top (tier or category, count, action needed), followed by tiered per-issue cards with exact `file:line` links, the concrete decision or A/B/C options, and side-by-side screenshots.
   - If the host environment defines a native artifact rule, follow it for presentation while still keeping report files out of the repo.

**Reply:** checks run with evidence, findings fixed per round, explicit list of every verification-framework change made (added, edited, or removed) with its reason (or none), and the report path if any unresolved decisions or A/B choices wait on the user.

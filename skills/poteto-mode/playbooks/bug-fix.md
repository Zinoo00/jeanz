### Bug fix

**You own this task end to end. Reproduce, root-cause, fix in the main loop, then run the verification loop.**

Be scientific. Every shipped line traces to runtime evidence. Belt-and-suspenders that "might help" is a hypothesis, not a fix. It does not ship. When evidence refutes a hypothesis, revert what it motivated. The smallest change the evidence justifies ships, nothing more.

1. Reproduce it yourself on the matching surface via the control skill (Non-negotiables), even when a debug or instrumentation protocol says to ask the user to reproduce. Ask the user only with a stated, specific reason the control surface cannot reach the target, and only after driving it as far as it goes. If it won't reproduce directly, synthesize the trigger, tighten conditions, or instrument until it fires.
2. Binary-search the cause. Form the candidate hypotheses, then rule them out until one survives. Seed them with a trace of the affected subsystem and the **why** skill for regression history. Each pass, take the split that cuts the most remaining problem space, get runtime evidence, eliminate. When program state is unclear, add instrumentation or logging and read it as the code runs. Don't guess. Drive a long or stubborn hunt with the `/loop` command. Use read-only `Explore` subagents only when bulk logs or code reads would bloat context, or parallel lanes when testing independent hypotheses concurrently. Confirm the surviving *mechanism* with runtime evidence before step 3's `architect`.
3. Plan and implement the fix directly in the main loop. If it crosses a function boundary, `architect` first. Keep single-owner bug fixes in the main loop instead of handing off to a coding subagent; fresh-context verification happens in step 4. If 2–3 viable fixes contradict each other and evidence cannot objectively settle one winner, build each in its own isolated worktree branch with captured evidence for the user to choose; if more than 3 options emerge, stop and talk with the user before building (see `playbooks/verification-loop.md`).
4. Verify on the same surface that the original repro now passes ("Inconclusive" or wrong-surface is not a pass; unit tests show branch behavior, not bug absence), then run **Verification loop** (`playbooks/verification-loop.md`).
5. Stage the commits so the failing repro lands before the fix in git history. See the **tdd** skill for the failing-test-first cadence when the bug has a cheap local test path. Skip it when the test would be expensive, integration-heavy, or unclear.
   This is the canonical **sequence-verifiable-units** principle skill, the failing test first and the fix on top.
6. Run **Opening a PR**.

**Reply:** what was broken, root cause, fix, how you verified, verification loop results. Paste failing-then-passing repro output verbatim.

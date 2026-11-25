### Eval

**You own the experiment design. Plan, blind, run, synthesize.**

**Non-negotiables for blinding:**

- No `eval`, `test`, `judge`, `experiment`, `rubric`, `score`, `compare`, `benchmark`, `candidate`, or `arena` in any directory, file, or prompt the candidate sees.
- The candidate prompt looks like an organic user request. State the goal, not the meta.
- No chain-eliciting cues. Don't ask the candidate to list which skills, principles, or files they applied. Ask for design notes generally and grade chain-following from code shape, not self-report.
- Sanitize directory and slug names. Use project-shaped names a user might pick.
- Don't tell the candidate other candidates exist.
- The judge can know it's judging but sees outputs by sanitized label only, never by model name.
- Comparing two variants: one judge scores both sets in a single pass on one scale, blind to which set each came from.

**Steps:**

1. **Frame.** State what variant is under test and what behavior counts as success. Write the rubric (3-6 concrete criteria) for the judge only. Hold it back from candidates. Change or fold one thing per eval (one subagent, one playbook rule, or one skill edit) so you know what moved the numbers.
2. **Pick the task set.** Use a standing golden set (for jeanz itself, [`../../../docs/golden-evals.md`](../../../docs/golden-evals.md)) covering full chains and hard constraints, or author one organic prompt for a targeted check. No leakage of what's being measured.
3. **Set up sanitized environments.** Per-candidate working dir with the variant in place. Plant any context an organic task would have: a project skeleton, the skills the candidate would naturally read.
4. **Run multiple trials per task.** Run each task at least **2 times** per variant to catch flaky regressions that only appear on one of two runs. Spawn parallel candidates per the **arena** skill's Phase B, each in its own sanitized dir with the same prompt. Record wall time, token usage, subagent spawn count, and what `../scripts/run-stats.py` prints for the transcript alongside each output. Pick each subagent's reasoning level for the job, per the Subagents section. An agent that only dispatches, polls, or packs results runs on `opus medium`.
5. **Spawn one blinded judge** on a different model family per the **arena** skill's Phase C. Judge sees outputs by sanitized label and the rubric, never a model name or variant name.
6. **Verify the chain from transcripts, not self-report.** Read each candidate's local transcript under `~/.claude/projects/<slug>/<session>/subagents/`, with `<slug>` the workspace path with each `/` and `.` turned into `-` and `<session>` this session's ID. Do not glob across `~/.claude/projects/*/`. That crosses workspace boundaries and reads private chats from unrelated projects. Look at which files each candidate actually opened and which subagents it spawned. Grade chain-following from the files it really read plus the shape of the code, never from the candidate's own claims.
7. **Read every candidate output yourself** end to end, especially any task whose pass/fail flipped across trials. Compare quality, flake rate, latency, and cost against baseline. Disagreement with the judge means a model is biased or the rubric is ambiguous. Promote the variant only when quality holds or improves with lower or bounded cost and latency.

**Reply:** variant under test, task set and trial count, rubric, quality/latency/cost comparison table, flipped cases, judge's verdict, your synthesis, and a promote-or-reject recommendation.

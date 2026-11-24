### Feature

**You own the feature end to end. Design, build in the main loop, and run the verification loop.**

1. Trace the affected subsystem.
2. `architect` for the shape.
3. Write the throughput checkpoint as four todo items. A dimension that genuinely does not apply (single file, no fan-out) keeps its item with `n/a: <reason>` rather than being dropped:
   - **Blocking first steps.** Gates run before fan-out.
   - **Independent workstreams.** Disjoint files, services, or layers parallelize. Shared writes serialize.
   - **Shared mutable state.** Default to splitting the target (the **separate-before-serializing-shared-state** principle skill). Serialize only for real invariants.
   - **Smallest safe decomposition.** If one worker is best, name why.
4. Implement directly in the main loop when one worker is best, starting from the named data shape and its organizing structure per **principle-model-the-domain** (a state machine over scattered booleans, a table or registry over branching, a typed model over repeated shape assumptions). Fan out to parallel `poteto-agent` workers (each in its own lane, using your configured feature model, default `opus xhigh`) only when step 3 identified genuinely independent workstreams. When the implementation admits multiple valid shapes (error handling, abstraction layer, test structure), run the **arena** skill instead so parallel runners surface alternatives and a cross-judge guards the pick. Surgical edits, re-ground against the source for upstream-derived files. Port shared-primitive improvements to all consumers and verify each. Commit liberally.
5. Run **Verification loop** (`playbooks/verification-loop.md`) to self-verify on the real artifact, clean the diff, pass fresh-context verification, fix any proven findings, and encode repeat guards. "Inconclusive" or wrong-surface is not a pass. Flag it.
6. Rebase into small, ordered commits. Stack follow-ups.
   Use the **sequence-verifiable-units** principle skill, building, verifying, and committing each small unit before the next.
7. Run **Opening a PR**.

Code-coupled work (one feature, one migration) stays in the main loop with the checkpoint inline, fanning out only for genuinely disjoint slices or competing experiments. Parent-level fan-out is for independent artifacts (audits, cross-subsystem investigations, competing experiments). Rewrite the checkpoint at phase boundaries.

**Reply:** what you built, what you chose and why, the throughput checkpoint, verification loop results, open decisions. Tables for design alternatives.

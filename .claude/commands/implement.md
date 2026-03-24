Implement a PRD phase for the nvim-CCI plugin.

Arguments: $ARGUMENTS
Expected format: a phase number (e.g. `1`) or a phase number and optional PRD path (e.g. `2 prd/phase-2-auth.md`).

## Instructions

Follow these steps exactly, in order:

### 1. Load the PRD

- Parse $ARGUMENTS to extract the phase number. If a file path is also given, use it. Otherwise resolve the PRD path as `prd/phase-<N>-*.md` (glob for the matching file).
- Read the PRD file in full.
- Extract and internalize:
  - **Goal** — what this phase is trying to achieve
  - **Acceptance Criteria** — the behavioural Given/When/Then conditions that define done
  - **Technical Design Notes** — architecture decisions, data structures, APIs to follow
  - **Implementation Tasks** — the ordered checklist of work to do
  - **Out of Scope** — what must NOT be implemented in this phase

### 2. Plan before coding

- Review any existing code that the new code will depend on or extend (read relevant files).
- Note any conflicts between the PRD and the current state of the codebase.
- If a task in the PRD is already implemented correctly, mark it done and skip it.

### 3. Implement each task

- Work through the Implementation Tasks checklist from the PRD **in order**.
- After completing each task, mark it as done with a short status note.
- Follow the Technical Design Notes precisely — do not invent alternative designs unless the PRD design is impossible.
- Do not implement anything listed under Out of Scope.
- Keep changes minimal and focused — do not refactor surrounding code unless the PRD requires it.

### 4. Run the tests

- Run `make test` from the project root.
- If tests fail, read the failure output, fix the issue, and re-run.
- Do not move on until tests pass or you have a clear explanation of why a failure is acceptable (e.g. tests for a future phase).

### 5. Verify acceptance criteria

Go through every Acceptance Criterion from the PRD one by one. For each:
- State the criterion.
- Describe how you verified it (test output, code inspection, manual check).
- Mark it as **PASS** or **FAIL**.

If any criterion is FAIL, fix it and re-verify before finishing.

### 6. Report

Output a concise summary:
- Phase implemented
- Tasks completed (checklist)
- Test result (pass/fail + any notable output)
- Acceptance criteria verification table (criterion → PASS/FAIL)
- Any deviations from the PRD and why

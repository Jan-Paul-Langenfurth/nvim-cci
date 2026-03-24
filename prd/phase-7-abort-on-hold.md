# PRD — Phase 7: Abort On-Hold Pipeline via Approval Row

## Goal

Allow the user to press `x` while the cursor is on an `on_hold` approval job to cancel the
parent workflow, giving a fast escape hatch for pipelines that are blocked waiting for a manual
gate.

---

## Acceptance Criteria

- **Given** the cursor is on a job row whose `type = "approval"` and `status = "on_hold"`,
  **when** the user presses `x`, **then** a confirmation popup appears:
  "Abort workflow '<workflow-name>' (on-hold approval '<job-name>')? [y/N]".
- **Given** the user confirms with `y`, **when** the cancel API call succeeds, **then** the
  panel refreshes and a success notification is shown.
- **Given** the user confirms with `y`, **when** the cancel API call fails, **then** an error
  notification is shown and the panel is not refreshed.
- **Given** the user presses `n` or `<Esc>` at the confirmation prompt, **then** no action is
  taken.
- **Given** the cursor is on an `on_hold` approval job but the `line_map` entry does not
  carry a `workflow_id`, **then** an error notification is shown explaining the workflow
  context could not be resolved.
- **Given** the cursor is on a workflow row with `status = "on_hold"` (the whole workflow is
  paused), **when** the user presses `x`, **then** the same confirmation + cancel flow is
  triggered for that workflow.
- **Given** the cursor is on any other row type (pipeline, running workflow, passing job, etc.),
  **when** the user presses `x`, **then** the existing "No running workflow on this line."
  behaviour is unchanged.

---

## Technical Design Notes

**Extending `M.abort` in `actions.lua`:**

The existing `abort` function already handles `workflow` rows with `status = "running"`.  Extend
the validity check to also accept:

1. A `workflow` row with `status = "on_hold"`.
2. A `job` row with `type = "approval"` and `status = "on_hold"` — resolve the parent workflow
   from `entry.workflow_id` (already present in `line_map` entries for job rows, see
   `render.lua:157`).

```lua
-- Pseudo-logic for the extended abort function:
if entry.type == 'job' then
  if entry.data.type ~= 'approval' or entry.data.status ~= 'on_hold' then
    vim.notify('[nvim-cci] No on-hold approval job on this line.', WARN)
    return
  end
  -- resolve parent workflow from line_map entry
  local wf_id = entry.workflow_id
  -- ... look up workflow name from state or fall back to wf_id
  -- confirmation includes both job name and workflow context
elseif entry.type == 'workflow' then
  if wf.status ~= 'running' and wf.status ~= 'on_hold' then
    vim.notify('[nvim-cci] Workflow is not running or on hold.', WARN)
    return
  end
end
-- both paths converge on: cancel_workflow(wf_id, cb)
```

**Workflow name resolution for the job-row path:**

`line_map` job entries already carry `workflow_id` (set in `render.lua:158`).  The workflow
name is not stored directly on the job entry.  Two options:

1. *(preferred — simpler)* Use `workflow_id` as a display fallback when the workflow name is
   unavailable: "Abort workflow '<workflow_id>' …".
2. *(better UX)* Pass `state.workflows` into actions so the name can be looked up.  This
   requires the panel to pass state to actions, which is a minor coupling increase.

Start with option 1; upgrade to option 2 if the UX feels insufficient during review.

**No new API calls needed** — `cancel_workflow` in `api.lua` already handles this case.

---

## Implementation Tasks

- [ ] Extend `M.abort` in `lua/nvim-cci/actions.lua`:
  - Accept a `job` entry where `data.type == "approval"` and `data.status == "on_hold"`.
  - Resolve `workflow_id` from the entry; show an error if missing.
  - Accept a `workflow` entry where `status == "on_hold"` (in addition to `"running"`).
  - Build a confirmation message that names the job (for job-row path) or workflow.
  - Call `api.cancel_workflow(wf_id, cb)` and handle success/error the same way as the
    existing running-workflow abort.
- [ ] Update `tests/spec/actions_spec.lua`:
  - Add test: `x` on an `on_hold` approval job row → confirms → calls `cancel_workflow` with
    the correct workflow id.
  - Add test: `x` on an `on_hold` workflow row → confirms → calls `cancel_workflow`.
  - Add test: `x` on an `on_hold` approval job row with missing `workflow_id` → shows error,
    does not call API.
  - Add test: existing running-workflow abort tests still pass (regression).
- [ ] Verify that `panel.lua` keymaps require no changes (the `x` binding already delegates
  to `actions.abort`).

---

## Out of Scope

- Aborting individual non-approval jobs.
- Bulk abort of multiple on-hold workflows.
- A dedicated "reject" / "deny" action (CircleCI v2 API has no reject endpoint; cancelling
  the workflow is the only programmatic option).

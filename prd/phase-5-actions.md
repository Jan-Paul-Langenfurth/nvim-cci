# PRD — Phase 5: Actions

## Goal
Wire up the approve, abort, and re-run actions to the panel UI, with confirmation prompts and user feedback after each action.

---

## Acceptance Criteria

- **Given** the cursor is on an `on_hold` approval job, **when** the user presses `a`, **then** a confirmation popup appears: "Approve job '<name>'? [y/N]".
- **Given** the user confirms with `y`, **when** the approval API call succeeds, **then** the panel refreshes and shows a success notification.
- **Given** the user confirms with `y`, **when** the approval API call fails, **then** an error message is shown and the panel is not refreshed.
- **Given** the user presses `n` or `<Esc>` at the confirmation prompt, **then** no action is taken.
- **Given** the cursor is on a running workflow or pipeline, **when** the user presses `x`, **then** a confirmation popup appears: "Abort workflow '<name>'? [y/N]".
- **Given** the user confirms, **when** the cancel API call succeeds, **then** the panel refreshes.
- **Given** the cursor is on a failed workflow, **when** the user presses `R`, **then** a confirmation popup appears: "Re-run workflow '<name>'? [y/N]".
- **Given** the user confirms, **when** the rerun API call succeeds, **then** the panel refreshes.
- **Given** the user presses an action key on a row where that action is not applicable (e.g. `a` on a passing pipeline), **then** a message explains why (e.g. "No approval jobs on this pipeline").

---

## Technical Design Notes

**Confirmation popup:**
Use `nui.nvim` `Popup` component for a small centred modal. Two buttons: confirm / cancel. Alternatively, use `vim.fn.confirm()` for simplicity — prefer this first, upgrade to nui popup if it feels clunky.

```lua
local choice = vim.fn.confirm("Approve job 'deploy'?", "&Yes\n&No", 2)
if choice == 1 then ... end
```

**Action resolution — cursor to entity mapping:**
`render.lua` will maintain a line-to-entity map:
```lua
-- After each draw(), expose:
render.line_map[linenr] = { type = 'pipeline'|'workflow'|'job', id = '...', data = {...} }
```
Actions read this map to know what the cursor is pointing at and whether the action is valid.

**Action validity:**
| Action | Valid when cursor is on |
|---|---|
| `a` (approve) | a job with `type = "approval"` and `status = "on_hold"` |
| `x` (abort) | a workflow with `status = "running"` |
| `R` (re-run) | a workflow with `status = "failed"` |

**Feedback:**
Use `vim.notify(msg, vim.log.levels.INFO/ERROR)` — works with `nvim-notify` if installed, falls back to the built-in message area.

**Module (`lua/nvim-cci/actions.lua`):**
```lua
M.approve(line_map, cursor_line)
M.abort(line_map, cursor_line)
M.rerun(line_map, cursor_line)
```
Each function resolves the entity, shows confirmation, calls the API, then calls `panel.refresh()` on success.

---

## Implementation Tasks

- [ ] Write `lua/nvim-cci/actions.lua` with `approve`, `abort`, `rerun` functions
- [ ] Update `render.lua` to build and expose `line_map` after each draw
- [ ] Implement confirmation via `vim.fn.confirm()` in each action
- [ ] Wire `a`, `x`, `R` keymaps in `panel.lua` to call `actions.*` with current line map and cursor
- [ ] Implement "action not applicable" message for invalid cursor positions
- [ ] Use `vim.notify` for success and error feedback
- [ ] Call `panel.refresh()` after a successful action
- [ ] Write `tests/spec/actions_spec.lua` — test approve/abort/rerun with mock API, mock line_map, valid and invalid cursor positions

---

## Out of Scope

- Bulk actions (select multiple pipelines)
- Triggering new pipelines
- Undo / rollback of actions

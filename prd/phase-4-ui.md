# PRD — Phase 4: Side Panel UI

## Goal
Render a side panel that lists pipelines for the current project, with expand/collapse drilldown into workflows and jobs, and clear visual status indicators.

---

## Acceptance Criteria

- **Given** the user runs `:CCIToggle` (or presses `<leader>ci`), **when** the panel is closed, **then** a vertical split opens on the right showing the pipeline list.
- **Given** the panel is open, **when** `:CCIToggle` is pressed again, **then** the panel closes and focus returns to the previous window.
- **Given** pipelines are loading, **when** the panel first opens, **then** a "Loading…" message is shown.
- **Given** pipelines have loaded, **when** the list is rendered, **then** each row shows: status icon, branch name, trigger time (relative, e.g. "5m ago").
- **Given** a failed pipeline, **when** it is rendered, **then** its row is highlighted in red (using `ErrorMsg` or a custom highlight group).
- **Given** the cursor is on a pipeline row, **when** the user presses `<Enter>`, **then** the row expands to show its workflows and jobs indented below it.
- **Given** an expanded pipeline, **when** the user presses `<Enter>` again, **then** it collapses.
- **Given** the user presses `r`, **when** the panel is open, **then** the pipeline list is refreshed from the API.
- **Given** the user presses `q`, **when** the panel is open, **then** the panel closes.
- **Given** the project slug cannot be detected, **when** the panel opens, **then** an error message explains why (e.g. "No git remote found").

---

## Technical Design Notes

**Panel implementation:**
Use a plain nvim split buffer (`vim.cmd('vsplit')`, `vim.api.nvim_open_win`) rather than `nui.nvim` for the outer panel — keeps it native and stable. Reserve `nui.nvim` for confirmation popups in Phase 5.

**Buffer settings:**
```lua
vim.bo[buf].buftype = 'nofile'
vim.bo[buf].bufhidden = 'wipe'
vim.bo[buf].modifiable = false
vim.wo[win].number = false
vim.wo[win].relativenumber = false
vim.wo[win].wrap = false
vim.wo[win].signcolumn = 'no'
```

**Status icons:**
| Status | Icon |
|---|---|
| success | `✓` |
| failed | `✗` |
| running | `⧗` |
| on_hold | `⏸` |
| canceled | `○` |

**Highlight groups:**
- `CCIStatusPassed` → links to `DiagnosticOk` (green)
- `CCIStatusFailed` → links to `DiagnosticError` (red)
- `CCIStatusRunning` → links to `DiagnosticWarn` (yellow)
- `CCIStatusOnHold` → links to `DiagnosticInfo` (blue)

**State (in `panel.lua`):**
```lua
local state = {
  pipelines = {},       -- raw API data
  expanded = {},        -- set of pipeline ids that are expanded
  workflows = {},       -- pipeline_id -> workflow list
  jobs = {},            -- workflow_id -> job list
  loading = false,
}
```

**Render flow:**
`panel.refresh()` → calls `api.get_pipelines` → updates `state.pipelines` → calls `render.draw(buf, state)` → writes lines to buffer.

**Keymaps** (set on the panel buffer only, not global):
| Key | Action |
|---|---|
| `<Enter>` | expand / collapse pipeline |
| `r` | refresh |
| `a` | approve (Phase 5) |
| `x` | abort (Phase 5) |
| `R` | re-run (Phase 5) |
| `q` | close panel |

---

## Implementation Tasks

- [ ] Write `lua/nvim-cci/ui/panel.lua` — open/close/toggle logic, buffer + window management
- [ ] Write `lua/nvim-cci/ui/render.lua` — pure function `draw(buf, state)` that writes lines and applies highlights
- [ ] Implement status icons and highlight group registration in `render.lua`
- [ ] Implement expand/collapse state toggling on `<Enter>`
- [ ] On expand: call `api.get_workflows` then `api.get_jobs` for each workflow, cache in state, re-render
- [ ] Register buffer-local keymaps in `panel.lua` after buffer creation
- [ ] Implement `:CCIOpen`, `:CCIClose`, `:CCIToggle` commands wired to `panel` module
- [ ] Detect project slug on open via `api.slug_from_remote`, show error if not found
- [ ] Write `tests/spec/render_spec.lua` — test line generation, icon selection, expand/collapse output

---

## Out of Scope

- Auto-polling / real-time updates
- Sorting or filtering pipelines
- Viewing raw job logs
- Action keybindings (stubs only — implemented in Phase 5)

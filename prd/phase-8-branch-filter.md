# PRD — Phase 8: Branch Filter

## Goal

Let the user press `f` in the panel to filter the pipeline list to a specific branch.
A picker shows the last 5 distinct branches that have run (derived from the currently
loaded pipeline list), plus a "Clear filter / show all" option. Selecting a branch
re-fetches pipelines scoped to that branch; selecting "all" resets the filter.

---

## Acceptance Criteria

- **Given** the panel is open, **when** the user presses `f`, **then** a picker appears
  listing up to 5 distinct branch names (most-recently-run first, derived from the current
  `state.pipelines` list) plus an "All branches" entry at the top.
- **Given** the picker is shown, **when** the user selects a branch, **then** the panel
  immediately shows a "Loading…" state and re-fetches pipelines filtered to that branch.
- **Given** a branch filter is active, **when** pipelines are rendered, **then** a header
  line appears at the top of the panel: `  [branch: <name>]` so the user can see the active
  filter at a glance.
- **Given** a branch filter is active, **when** the user presses `f` and selects
  "All branches", **then** the filter is cleared and all pipelines are re-fetched.
- **Given** a branch filter is active, **when** the user presses `r` to refresh, **then**
  the refresh honours the current branch filter.
- **Given** the picker is opened but the user presses `<Esc>` or cancels, **then** no
  change is made to the current filter or pipeline list.
- **Given** no pipelines have loaded yet (list is empty), **when** the user presses `f`,
  **then** the picker still appears with only the "All branches" entry (no crash).

---

## Technical Design Notes

**Deriving branch suggestions from loaded pipelines:**

```lua
--- Return up to `n` distinct branch names from the pipeline list, most recent first.
--- @param pipelines table  raw API items
--- @param n number
--- @return string[]
local function recent_branches(pipelines, n)
  local seen, result = {}, {}
  for _, p in ipairs(pipelines) do
    local branch = p.vcs and p.vcs.branch
    if branch and not seen[branch] then
      seen[branch] = true
      result[#result + 1] = branch
      if #result >= n then break end
    end
  end
  return result
end
```

**Picker — `vim.ui.select`:**

Use `vim.ui.select` so the picker works out of the box and upgrades automatically
when the user has `telescope.nvim` or `dressing.nvim` installed.

```lua
local items = { 'All branches' }
for _, b in ipairs(recent_branches(state.pipelines, 5)) do
  items[#items + 1] = b
end
vim.ui.select(items, { prompt = 'Filter by branch:' }, function(choice)
  if not choice then return end          -- user cancelled
  if choice == 'All branches' then
    state.branch_filter = nil
  else
    state.branch_filter = choice
  end
  M.refresh()
end)
```

**State — add `branch_filter`:**

```lua
local state = {
  pipelines     = {},
  expanded      = {},
  workflows     = {},
  jobs          = {},
  loading       = false,
  branch_filter = nil,   -- string | nil
}
```

**API — add optional `branch` param to `get_pipelines`:**

```lua
--- GET /project/{slug}/pipeline[?branch=<branch>]
--- @param project_slug string
--- @param branch string|nil   optional branch filter
--- @param cb function  cb(err, data)
function M.get_pipelines(project_slug, branch, cb)
  local path = '/project/' .. project_slug .. '/pipeline'
  if branch then
    path = path .. '?branch=' .. branch
  end
  get(path, cb)
end
```

Update all existing callers to pass `nil` as the branch argument.

**Render — header line for active filter:**

In `render.build_lines`, when `state.branch_filter` is set, push a header line
before the pipeline rows:

```lua
if state.branch_filter then
  push('  [branch: ' .. state.branch_filter .. ']',
       { type = 'status' }, 'CCIStatusOnHold', 2, -1)
end
```

**Keymap:**

Add `f` to the buffer-local keymaps in `panel.lua`:

```lua
map('f', function() M.filter_branch() end)
```

Implement `M.filter_branch()` as a new public function on the panel module.

---

## Implementation Tasks

- [ ] Add `branch_filter = nil` to the `state` table in `lua/nvim-cci/ui/panel.lua`
- [ ] Update `api.get_pipelines` signature to accept an optional `branch` argument and
  append `?branch=<branch>` to the request path when provided
- [ ] Update all existing callers of `api.get_pipelines` (panel.lua, tests) to pass `nil`
  as the branch argument so they are unaffected
- [ ] Implement `M.filter_branch()` in `panel.lua` — derive branch suggestions via
  `recent_branches`, show picker with `vim.ui.select`, update `state.branch_filter`,
  call `M.refresh()`
- [ ] Update `M.refresh()` in `panel.lua` to pass `state.branch_filter` to
  `api.get_pipelines`
- [ ] Update `render.build_lines` in `render.lua` to emit a header line when
  `state.branch_filter` is non-nil
- [ ] Add `f` keymap in `panel.lua` wired to `M.filter_branch()`
- [ ] Update `tests/spec/api_spec.lua`:
  - Test that `get_pipelines` with a branch appends `?branch=<name>` to the URL
  - Test that `get_pipelines` with `nil` branch uses the plain URL (regression)
- [ ] Update `tests/spec/render_spec.lua`:
  - Test that `build_lines` emits a `[branch: ...]` header line when `state.branch_filter`
    is set
  - Test that no header line appears when `state.branch_filter` is nil (regression)

---

## Out of Scope

- Persisting the branch filter across panel close/reopen sessions
- Free-text branch search / fuzzy matching (handled by `vim.ui.select` + user's picker plugin)
- Filtering by status, author, or other pipeline attributes
- Pagination / loading more than the first API page of filtered results

# PRD — Phase 9: Keybinding Legend

## Goal

Append a static keybinding legend at the bottom of the CCI panel buffer so users can
discover available keys without consulting the README. The legend is always visible,
separated from the pipeline list by a thin rule, and styled in a muted colour so it
does not compete with pipeline content.

---

## Acceptance Criteria

- **Given** the panel is open in any state (loading, empty, or populated), **when** the
  buffer is drawn, **then** the last lines of the buffer show a separator rule and the
  keybinding legend.
- **Given** the legend is rendered, **when** inspected, **then** it contains every
  bound key: `<CR>`, `r`, `f`, `a`, `x`, `R`, `q`.
- **Given** the legend is rendered, **when** the buffer is drawn, **then** the separator
  and all legend lines are highlighted with the `CCIHelp` highlight group (linked to
  `Comment`).
- **Given** the legend lines are highlighted, **when** the key characters within a legend
  line are inspected, **then** each key token (e.g. `<CR>`, `a`, `x`) is additionally
  highlighted with `CCIHelpKey` (linked to `Special`) so keys stand out from their
  descriptions.
- **Given** the cursor is positioned on a legend line, **when** any action key is pressed
  (e.g. `<CR>`, `a`, `x`), **then** the action behaves exactly as it would on any other
  non-actionable line (warns or no-ops) — the legend does not trigger special behaviour.
- **Given** the panel width is 50 characters, **when** the legend is rendered, **then**
  each legend line fits within 50 characters.

---

## Technical Design Notes

**Legend content (two lines, fits in 50 chars):**

```
  ───────────────────────────────────────────
  <CR> expand  r refresh  f filter  q close
  a approve  x abort  R rerun
```

Exact byte widths (with 2-space indent):
- Separator: 2 + 43 `─` = 45 bytes (safely under 50)
- Line 1: `  <CR> expand  r refresh  f filter  q close` = 44 chars
- Line 2: `  a approve  x abort  R rerun` = 30 chars

**New highlight groups (add to `render.setup_highlights`):**

```lua
vim.api.nvim_set_hl(0, 'CCIHelp',    { link = 'Comment' })
vim.api.nvim_set_hl(0, 'CCIHelpKey', { link = 'Special' })
```

**Appending to `build_lines`:**

Add a `push_help` helper inside `build_lines` that calls `push` and also records
additional highlight spans for the key tokens within the line.

```lua
-- After all pipeline/workflow/job rows:
push('  ' .. ('─'):rep(43), { type = 'help' }, 'CCIHelp', 0, -1)

local legend = {
  { text = '  <CR> expand  r refresh  f filter  q close',
    keys = { '<CR>', 'r', 'f', 'q' } },
  { text = '  a approve  x abort  R rerun',
    keys = { 'a', 'x', 'R' } },
}
for _, row in ipairs(legend) do
  push(row.text, { type = 'help' }, 'CCIHelp', 0, -1)
  -- add per-key highlights on the same line (after push, so line index = #lines - 1)
  for _, key in ipairs(row.keys) do
    local s, e = row.text:find(key, 1, true)
    if s then
      highlights[#highlights + 1] = {
        line      = #lines - 1,
        col_start = s - 1,  -- 0-based
        col_end   = e,
        hl_group  = 'CCIHelpKey',
      }
    end
  end
end
```

> **Note:** `string.find` with `plain = true` finds the first occurrence. For keys that
> appear verbatim in the text this is safe. The key `R` must be searched after `r` has
> been added (or searched case-sensitively, which Lua's `find` does by default).

**`line_meta` for legend rows:** use `{ type = 'help' }`. The `toggle_expand` and
`actions.*` functions already guard on `entry.type`, so legend rows are naturally
no-ops for all existing actions.

---

## Implementation Tasks

- [ ] Add `CCIHelp` and `CCIHelpKey` highlight groups in `render.setup_highlights()`
- [ ] Append the separator line and two legend lines at the end of `build_lines` in
  `render.lua`, with `CCIHelp` highlight spanning the full line
- [ ] Add per-key `CCIHelpKey` highlights for each key token within each legend line
- [ ] Write `tests/spec/render_spec.lua` additions:
  - Test that `build_lines` always emits at least 3 legend lines at the end (separator +
    2 rows) for any non-empty and empty state
  - Test that legend lines carry `type = 'help'` in `line_meta`
  - Test that the legend contains the separator `───` string
  - Test that each of `<CR>`, `r`, `f`, `a`, `x`, `R`, `q` appears in the legend text

---

## Out of Scope

- Dynamic / context-sensitive legend (e.g. hiding `a` when no approval job is under
  the cursor) — keep it static for simplicity
- Making the legend scrollable or collapsible
- Configurable legend content or key remapping display

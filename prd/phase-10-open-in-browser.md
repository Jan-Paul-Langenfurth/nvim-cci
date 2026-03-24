# PRD — Phase 10: Open in Browser

## Goal

Let the user press `o` on any row in the CCI panel to open the corresponding CircleCI
page in their default browser. On a job row the job detail page opens; on a workflow row
the workflow page opens; on a pipeline row the pipeline page opens.

---

## Acceptance Criteria

- **Given** the cursor is on a job row, **when** the user presses `o`, **then** the
  system browser opens the CircleCI job URL:
  `https://app.circleci.com/pipelines/{slug}/{pipeline_number}/workflows/{workflow_id}/jobs/{job_number}`.
- **Given** the cursor is on a workflow row, **when** the user presses `o`, **then** the
  system browser opens the CircleCI workflow URL:
  `https://app.circleci.com/pipelines/{slug}/{pipeline_number}/workflows/{workflow_id}`.
- **Given** the cursor is on a pipeline row, **when** the user presses `o`, **then** the
  system browser opens the CircleCI pipeline URL:
  `https://app.circleci.com/pipelines/{slug}/{pipeline_number}`.
- **Given** the cursor is on a status, help, or loading row, **when** the user presses
  `o`, **then** a warning notification is shown and no browser is opened.
- **Given** the data needed to build the URL is missing (e.g. `job_number` is nil),
  **then** an error notification is shown and no browser is opened.
- **Given** `vim.ui.open` is available (Neovim ≥ 0.10), **when** the URL is opened,
  **then** it is opened via `vim.ui.open`.  On Neovim 0.9 the fallback
  `xdg-open` (Linux) / `open` (macOS) is used via `vim.fn.jobstart`.

---

## Technical Design Notes

**CircleCI URL scheme:**

| Row type | URL |
|---|---|
| pipeline | `https://app.circleci.com/pipelines/{slug}/{pipeline_number}` |
| workflow | `https://app.circleci.com/pipelines/{slug}/{pipeline_number}/workflows/{workflow_id}` |
| job | `https://app.circleci.com/pipelines/{slug}/{pipeline_number}/workflows/{workflow_id}/jobs/{job_number}` |

`slug` is the project slug already cached in `panel._slug` (e.g. `github/org/repo`).

**Pipeline number in `line_map` entries:**

`render.lua` already has `pipeline.id` available when building every row. Add
`pipeline_number = pipeline.number` to the meta table for pipeline, workflow, and job
entries so the URL builder does not need to look up the pipeline from state:

```lua
-- pipeline row
push(text, { type='pipeline', id=pipeline.id, data=pipeline,
             pipeline_number=pipeline.number }, ...)

-- workflow row
push(wf_text, { type='workflow', id=wf.id, data=wf,
                pipeline_id=pipeline.id, pipeline_number=pipeline.number }, ...)

-- job row
push(job_text, { type='job', id=job.id, data=job,
                 workflow_id=wf.id, pipeline_id=pipeline.id,
                 pipeline_number=pipeline.number }, ...)
```

**New action `M.open_browser` in `actions.lua`:**

```lua
--- Open the CircleCI page for the row under the cursor.
--- @param line_map table
--- @param cursor_line number
--- @param slug string  project slug, e.g. "github/org/repo"
function M.open_browser(line_map, cursor_line, slug)
  local entry = resolve(line_map, cursor_line)
  if not entry or entry.type == 'status' or entry.type == 'help' then
    vim.notify('[nvim-cci] No pipeline item on this line.', vim.log.levels.WARN)
    return
  end

  local base = 'https://app.circleci.com/pipelines/' .. slug
  local pn   = entry.pipeline_number or (entry.data and entry.data.number)
  if not pn then
    vim.notify('[nvim-cci] Pipeline number unavailable.', vim.log.levels.ERROR)
    return
  end

  local url
  if entry.type == 'pipeline' then
    url = base .. '/' .. pn
  elseif entry.type == 'workflow' then
    url = base .. '/' .. pn .. '/workflows/' .. entry.id
  elseif entry.type == 'job' then
    local jn = entry.data and entry.data.job_number
    if not jn then
      vim.notify('[nvim-cci] Job number unavailable.', vim.log.levels.ERROR)
      return
    end
    url = base .. '/' .. pn .. '/workflows/' .. entry.workflow_id .. '/jobs/' .. jn
  end

  open_url(url)
end
```

**`open_url` helper (top of `actions.lua`):**

```lua
local function open_url(url)
  if vim.ui.open then
    vim.ui.open(url)
  else
    local cmd = vim.fn.has('mac') == 1 and 'open' or 'xdg-open'
    vim.fn.jobstart({ cmd, url }, { detach = true })
  end
end
```

**Wiring in `panel.lua`:**

```lua
map('o', function()
  local render  = require('nvim-cci.ui.render')
  local actions = require('nvim-cci.actions')
  local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]
  actions.open_browser(render.line_map, cursor_line, M._slug)
end)
```

**Legend update in `render.lua`:**

Append `o open` to the second legend line. Update the text and spans accordingly:

```
  a approve  x abort  R rerun  o open
```
`o` is at byte position 33 (0-indexed: 32–33).

---

## Implementation Tasks

- [ ] Add `pipeline_number = pipeline.number` to the pipeline, workflow, and job `push`
  calls in `render.lua`
- [ ] Add `open_url` local helper in `actions.lua`
- [ ] Implement `M.open_browser(line_map, cursor_line, slug)` in `actions.lua`
- [ ] Add `o` keymap in `panel.lua` wired to `actions.open_browser` with `M._slug`
- [ ] Update the second legend line in `render.lua` to include `o open`, and add its
  `CCIHelpKey` span
- [ ] Update `tests/spec/actions_spec.lua`:
  - Test: `o` on a job row → calls `open_url` with the correct job URL
  - Test: `o` on a workflow row → calls `open_url` with the correct workflow URL
  - Test: `o` on a pipeline row → calls `open_url` with the correct pipeline URL
  - Test: `o` on a status/help row → warns, does not open URL
  - Test: `o` on a job row with missing `job_number` → errors, does not open URL
  - Test: `o` on a pipeline row with missing `pipeline_number` → errors, does not open URL
- [ ] Update `tests/spec/render_spec.lua`:
  - Update legend line-2 content test to expect `o open`
  - Update the explicit `pipeline_number` field test to verify it is present in pipeline,
    workflow, and job meta entries

---

## Out of Scope

- Opening logs inline in a Neovim buffer
- Copying the URL to the clipboard instead of opening it
- Supporting CircleCI server (self-hosted) base URLs — use `app.circleci.com` only

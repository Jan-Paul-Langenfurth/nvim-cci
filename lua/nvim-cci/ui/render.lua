local M = {}

-- ── Status icons (Task 2) ─────────────────────────────────────────────────────

M.STATUS_ICONS = {
  success  = '✓',
  failed   = '✗',
  error    = '✗',
  running  = '⧗',
  on_hold  = '⏸',
  canceled = '○',
}

M.STATUS_HIGHLIGHTS = {
  success  = 'CCIStatusPassed',
  failed   = 'CCIStatusFailed',
  error    = 'CCIStatusFailed',
  running  = 'CCIStatusRunning',
  on_hold  = 'CCIStatusOnHold',
  canceled = 'CCIStatusCanceled',
}

--- Return the icon character for a given CircleCI status string.
--- @param status string
--- @return string
function M.status_icon(status)
  return M.STATUS_ICONS[status] or '?'
end

--- Return the highlight group name for a given status string, or nil.
--- @param status string
--- @return string|nil
function M.status_hl(status)
  return M.STATUS_HIGHLIGHTS[status]
end

-- ── Highlight groups ──────────────────────────────────────────────────────────

--- Register CCI highlight groups (links to standard diagnostic groups).
function M.setup_highlights()
  vim.api.nvim_set_hl(0, 'CCIStatusPassed',   { link = 'DiagnosticOk' })
  vim.api.nvim_set_hl(0, 'CCIStatusFailed',   { link = 'DiagnosticError' })
  vim.api.nvim_set_hl(0, 'CCIStatusRunning',  { link = 'DiagnosticWarn' })
  vim.api.nvim_set_hl(0, 'CCIStatusOnHold',   { link = 'DiagnosticInfo' })
  vim.api.nvim_set_hl(0, 'CCIStatusCanceled', { link = 'Comment' })
end

-- ── Time formatting ───────────────────────────────────────────────────────────

--- Parse an ISO8601 timestamp string into a Unix timestamp (local time approximation).
--- @param ts string  e.g. "2024-01-15T10:30:00.000Z"
--- @return number|nil
local function parse_iso8601(ts)
  if not ts or ts == '' then return nil end
  local y, mo, d, h, m, s = ts:match('^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if not y then return nil end
  return os.time({
    year  = tonumber(y),
    month = tonumber(mo),
    day   = tonumber(d),
    hour  = tonumber(h),
    min   = tonumber(m),
    sec   = tonumber(s),
  })
end

--- Format an ISO8601 timestamp as a human-readable relative time string.
--- @param ts string
--- @return string  e.g. "5m ago", "2h ago", "3d ago"
function M.time_ago(ts)
  local t = parse_iso8601(ts)
  if not t then return '?' end
  local diff = os.difftime(os.time(), t)
  if diff < 60 then
    return tostring(math.floor(diff)) .. 's ago'
  elseif diff < 3600 then
    return tostring(math.floor(diff / 60)) .. 'm ago'
  elseif diff < 86400 then
    return tostring(math.floor(diff / 3600)) .. 'h ago'
  else
    return tostring(math.floor(diff / 86400)) .. 'd ago'
  end
end

-- ── Line builder (pure function) ──────────────────────────────────────────────

--- Build display lines, highlight specs, and per-line metadata from state.
---
--- @param state table  { pipelines, expanded, workflows, jobs, loading }
--- @return lines table          list of strings (0-indexed for nvim_buf_set_lines)
--- @return highlights table     list of { line, col_start, col_end, hl_group }
--- @return line_meta table      1-indexed; each entry: { type, id, data, pipeline_id?, workflow_id? }
function M.build_lines(state)
  local lines      = {}
  local highlights = {}
  local line_meta  = {}  -- 1-indexed, parallel to lines

  local function push(line, meta, hl_group, hl_col_start, hl_col_end)
    lines[#lines + 1]         = line
    line_meta[#line_meta + 1] = meta
    if hl_group then
      -- line index is 0-based for nvim_buf_add_highlight
      highlights[#highlights + 1] = {
        line      = #lines - 1,
        col_start = hl_col_start,
        col_end   = hl_col_end,
        hl_group  = hl_group,
      }
    end
  end

  if state.branch_filter then
    local header = '  [branch: ' .. state.branch_filter .. ']'
    push(header, { type = 'status' }, 'CCIStatusOnHold', 2, #header)
  end

  if state.loading then
    push('  Loading…', { type = 'status' })
    return lines, highlights, line_meta
  end

  if not state.pipelines or #state.pipelines == 0 then
    push('  No pipelines found.', { type = 'status' })
    return lines, highlights, line_meta
  end

  for _, pipeline in ipairs(state.pipelines) do
    local status = pipeline.state or pipeline.status or 'unknown'
    local icon   = M.status_icon(status)
    local branch = (pipeline.vcs and pipeline.vcs.branch)
                   or pipeline.branch
                   or '(unknown branch)'
    local ago    = M.time_ago(pipeline.created_at)
    local text   = string.format('  %s %s · %s', icon, branch, ago)
    local hl     = M.status_hl(status)
    -- icon starts at byte 2 (0-based), length of icon in UTF-8 bytes
    push(text, { type = 'pipeline', id = pipeline.id, data = pipeline },
         hl, 2, 2 + #icon)

    if state.expanded and state.expanded[pipeline.id] then
      local wfs = state.workflows and state.workflows[pipeline.id] or {}
      if #wfs == 0 then
        push('    ⋯ loading workflows…',
             { type = 'status', pipeline_id = pipeline.id })
      else
        for _, wf in ipairs(wfs) do
          local wf_status = wf.status or 'unknown'
          local wf_icon   = M.status_icon(wf_status)
          local wf_text   = string.format('    %s %s', wf_icon, wf.name or wf.id)
          local wf_hl     = M.status_hl(wf_status)
          push(wf_text,
               { type = 'workflow', id = wf.id, data = wf, pipeline_id = pipeline.id },
               wf_hl, 4, 4 + #wf_icon)

          local jobs = state.jobs and state.jobs[wf.id] or {}
          for _, job in ipairs(jobs) do
            local job_status = job.status or 'unknown'
            local job_icon   = M.status_icon(job_status)
            local job_text   = string.format('      %s %s', job_icon, job.name or job.id)
            local job_hl     = M.status_hl(job_status)
            push(job_text,
                 { type = 'job', id = job.id, data = job,
                   workflow_id = wf.id, pipeline_id = pipeline.id },
                 job_hl, 6, 6 + #job_icon)
          end
        end
      end
    end
  end

  return lines, highlights, line_meta
end

-- ── Buffer writer ─────────────────────────────────────────────────────────────

--- Write state to a Neovim buffer and apply syntax highlights.
--- Also updates M.line_map with the current 1-indexed line → entity mapping.
--- @param buf number  buffer handle
--- @param state table
--- @return table  line_meta (1-indexed, for use by panel toggle/action logic)
function M.draw(buf, state)
  local lines, highlights, line_meta = M.build_lines(state)

  -- Expose for actions module: render.line_map[linenr] = { type, id, data, ... }
  M.line_map = line_meta

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local ns = vim.api.nvim_create_namespace('nvim-cci')
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns, h.hl_group, h.line, h.col_start, h.col_end)
  end

  return line_meta
end

return M

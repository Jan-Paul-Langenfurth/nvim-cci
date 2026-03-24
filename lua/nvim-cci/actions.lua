local M = {}

-- ── Injectable dependencies (override in tests) ───────────────────────────────

M._api     = nil  -- mock for require('nvim-cci.api')
M._panel   = nil  -- mock for require('nvim-cci.ui.panel')
M._confirm = nil  -- override confirmation: fn(msg) → bool

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function get_api()
  return M._api or require('nvim-cci.api')
end

local function get_panel()
  return M._panel or require('nvim-cci.ui.panel')
end

--- Show a Yes/No confirmation prompt. Returns true if the user chose Yes.
--- @param msg string
--- @return boolean
local function confirm(msg)
  if M._confirm then return M._confirm(msg) end
  -- vim.fn.confirm returns 1 for &Yes, 2 for &No, 0 for <Esc>
  return vim.fn.confirm(msg, '&Yes\n&No', 2) == 1
end

--- Resolve the entity at cursor_line from line_map.
--- @param line_map table  1-indexed line → entity map (from render.line_map)
--- @param cursor_line number  1-indexed cursor position
--- @return table|nil  entry with { type, id, data, ... }
local function resolve(line_map, cursor_line)
  return line_map and line_map[cursor_line]
end

-- ── Public actions ────────────────────────────────────────────────────────────

--- Approve the on_hold approval job under the cursor.
--- @param line_map table
--- @param cursor_line number
function M.approve(line_map, cursor_line)
  local entry = resolve(line_map, cursor_line)

  if not entry or entry.type ~= 'job' then
    vim.notify('[nvim-cci] No approval job on this line.', vim.log.levels.WARN)
    return
  end

  local job = entry.data
  if job.type ~= 'approval' or job.status ~= 'on_hold' then
    vim.notify('[nvim-cci] No approval jobs on this pipeline.', vim.log.levels.WARN)
    return
  end

  local name = job.name or job.id
  if not confirm(string.format("Approve job '%s'? [y/N]", name)) then
    return
  end

  -- CircleCI uses approval_request_id when approving a hold job
  local approval_id = job.approval_request_id or job.id
  get_api().approve_job(approval_id, function(err, _)
    vim.schedule(function()
      if err then
        vim.notify('[nvim-cci] Failed to approve job: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify("[nvim-cci] Approved job '" .. name .. "'.", vim.log.levels.INFO)
        get_panel().refresh()
      end
    end)
  end)
end

--- Abort (cancel) the running workflow under the cursor.
--- @param line_map table
--- @param cursor_line number
function M.abort(line_map, cursor_line)
  local entry = resolve(line_map, cursor_line)

  if not entry or entry.type ~= 'workflow' then
    vim.notify('[nvim-cci] No running workflow on this line.', vim.log.levels.WARN)
    return
  end

  local wf = entry.data
  if wf.status ~= 'running' then
    vim.notify('[nvim-cci] Workflow is not running.', vim.log.levels.WARN)
    return
  end

  local name = wf.name or wf.id
  if not confirm(string.format("Abort workflow '%s'? [y/N]", name)) then
    return
  end

  get_api().cancel_workflow(wf.id, function(err, _)
    vim.schedule(function()
      if err then
        vim.notify('[nvim-cci] Failed to abort workflow: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify("[nvim-cci] Aborted workflow '" .. name .. "'.", vim.log.levels.INFO)
        get_panel().refresh()
      end
    end)
  end)
end

--- Re-run the failed workflow under the cursor.
--- @param line_map table
--- @param cursor_line number
function M.rerun(line_map, cursor_line)
  local entry = resolve(line_map, cursor_line)

  if not entry or entry.type ~= 'workflow' then
    vim.notify('[nvim-cci] No failed workflow on this line.', vim.log.levels.WARN)
    return
  end

  local wf = entry.data
  if wf.status ~= 'failed' then
    vim.notify('[nvim-cci] Workflow has not failed.', vim.log.levels.WARN)
    return
  end

  local name = wf.name or wf.id
  if not confirm(string.format("Re-run workflow '%s'? [y/N]", name)) then
    return
  end

  get_api().rerun_workflow(wf.id, function(err, _)
    vim.schedule(function()
      if err then
        vim.notify('[nvim-cci] Failed to re-run workflow: ' .. err, vim.log.levels.ERROR)
      else
        vim.notify("[nvim-cci] Re-running workflow '" .. name .. "'.", vim.log.levels.INFO)
        get_panel().refresh()
      end
    end)
  end)
end

return M

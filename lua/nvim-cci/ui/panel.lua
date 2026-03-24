local M = {}

local PANEL_WIDTH = 50

-- ── Panel state ───────────────────────────────────────────────────────────────

local state = {
  pipelines     = {},
  expanded      = {},
  workflows     = {},
  jobs          = {},
  loading       = false,
  branch_filter = nil,  -- string | nil
}

local panel_buf  = nil
local panel_win  = nil
local legend_buf = nil
local legend_win = nil
local prev_win   = nil   -- window to restore focus to on close

-- Exposed for testing / Phase 5 access
M._state = state

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function is_open()
  return panel_win ~= nil and vim.api.nvim_win_is_valid(panel_win)
end

local function set_keymaps(buf)
  local map = function(key, fn)
    vim.keymap.set('n', key, fn, { noremap = true, silent = true, buffer = buf })
  end
  map('<CR>', function() M.toggle_expand() end)
  map('r',    function() M.refresh() end)
  map('f',    function() M.filter_branch() end)
  map('q',    function() M.close() end)
  map('o', function()
    local render  = require('nvim-cci.ui.render')
    local actions = require('nvim-cci.actions')
    local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]
    actions.open_browser(render.line_map, cursor_line, M._slug)
  end)
  map('a', function()
    local render  = require('nvim-cci.ui.render')
    local actions = require('nvim-cci.actions')
    local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]
    actions.approve(render.line_map, cursor_line)
  end)
  map('x', function()
    local render  = require('nvim-cci.ui.render')
    local actions = require('nvim-cci.actions')
    local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]
    actions.abort(render.line_map, cursor_line)
  end)
  map('R', function()
    local render  = require('nvim-cci.ui.render')
    local actions = require('nvim-cci.actions')
    local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]
    actions.rerun(render.line_map, cursor_line)
  end)
end

local function create_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype    = 'nofile'
  vim.bo[buf].bufhidden  = 'wipe'
  vim.bo[buf].modifiable = false
  set_keymaps(buf)
  return buf
end

local function create_legend_buf()
  local render = require('nvim-cci.ui.render')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype    = 'nofile'
  vim.bo[buf].bufhidden  = 'wipe'
  vim.bo[buf].modifiable = false
  render.draw_legend(buf)
  -- Allow closing the panel from the legend window
  vim.keymap.set('n', 'q', function() M.close() end,
    { noremap = true, silent = true, buffer = buf })
  return buf
end

--- Create the vsplit panel window plus a fixed 3-line legend window below it.
--- Returns (panel_win, legend_win).
local function create_win(buf, lbuf)
  prev_win = vim.api.nvim_get_current_win()
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_width(win, PANEL_WIDTH)
  vim.wo[win].number         = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap           = false
  vim.wo[win].signcolumn     = 'no'

  -- Split a fixed-height window at the bottom of the panel column for the legend
  vim.cmd('belowright split')
  local lwin = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(lwin, lbuf)
  vim.api.nvim_win_set_height(lwin, 3)
  vim.wo[lwin].number         = false
  vim.wo[lwin].relativenumber = false
  vim.wo[lwin].wrap           = false
  vim.wo[lwin].signcolumn     = 'no'
  vim.wo[lwin].winfixheight   = true
  vim.wo[lwin].cursorline     = false

  -- Return focus to main pipeline window
  vim.api.nvim_set_current_win(win)
  return win, lwin
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Open the CCI side panel for the current git project.
function M.open()
  if is_open() then return end

  local api    = require('nvim-cci.api')
  local render = require('nvim-cci.ui.render')
  render.setup_highlights()

  -- Detect project slug from git remote
  local remote = vim.trim(vim.fn.system('git remote get-url origin 2>/dev/null'))
  local slug   = api.slug_from_remote(remote)
  if not slug then
    vim.notify(
      '[nvim-cci] No git remote found. Cannot detect CircleCI project.',
      vim.log.levels.ERROR
    )
    return
  end

  -- Reset state for fresh open
  state.pipelines     = {}
  state.expanded      = {}
  state.workflows     = {}
  state.jobs          = {}
  state.loading       = true
  state.branch_filter = nil

  legend_buf = create_legend_buf()
  panel_buf  = create_buf()
  panel_win, legend_win = create_win(panel_buf, legend_buf)

  M._slug = slug  -- cache for refresh; also exposed for tests

  -- Clean up both windows if the panel is closed externally (e.g. :q)
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern  = tostring(panel_win),
    once     = true,
    callback = function()
      if legend_win and vim.api.nvim_win_is_valid(legend_win) then
        pcall(vim.api.nvim_win_close, legend_win, true)
      end
      panel_win  = nil
      panel_buf  = nil
      legend_win = nil
      legend_buf = nil
      if prev_win and vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end
    end,
  })

  render.draw(panel_buf, state, { legend = false })
  M.refresh()
end

--- Close the CCI side panel and restore focus to the previous window.
function M.close()
  if not is_open() then return end
  if legend_win and vim.api.nvim_win_is_valid(legend_win) then
    pcall(vim.api.nvim_win_close, legend_win, true)
  end
  legend_win = nil
  legend_buf = nil
  vim.api.nvim_win_close(panel_win, true)
  panel_win = nil
  panel_buf = nil
  if prev_win and vim.api.nvim_win_is_valid(prev_win) then
    vim.api.nvim_set_current_win(prev_win)
  end
end

--- Toggle the CCI side panel open/closed.
function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

--- Fetch (or re-fetch) pipelines and redraw the panel.
function M.refresh()
  if not is_open() then return end
  local api    = require('nvim-cci.api')
  local render = require('nvim-cci.ui.render')

  state.loading = true
  render.draw(panel_buf, state, { legend = false })

  api.get_pipelines(M._slug, state.branch_filter, function(err, data)
    vim.schedule(function()
      state.loading = false
      if err then
        state.pipelines = {}
        vim.notify('[nvim-cci] Error loading pipelines: ' .. err, vim.log.levels.ERROR)
      else
        state.pipelines = (data and data.items) or {}
      end
      if is_open() then
        render.draw(panel_buf, state, { legend = false })
      end
      -- Background-fetch workflows for all pipelines so icons show immediately
      for _, pipeline in ipairs(state.pipelines) do
        local pid = pipeline.id
        if not state.workflows[pid] then
          api.get_workflows(pid, function(werr, wdata)
            vim.schedule(function()
              if not werr and wdata then
                state.workflows[pid] = wdata.items or {}
                if is_open() then
                  render.draw(panel_buf, state, { legend = false })
                end
              end
            end)
          end)
        end
      end
    end)
  end)
end

--- Return up to n distinct branch names from the pipeline list, most recent first.
--- @param pipelines table
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

--- Show a branch picker and re-fetch pipelines filtered to the chosen branch.
function M.filter_branch()
  if not is_open() then return end
  local items = { 'All branches' }
  for _, b in ipairs(recent_branches(state.pipelines, 5)) do
    items[#items + 1] = b
  end
  vim.ui.select(items, { prompt = 'Filter by branch:' }, function(choice)
    if not choice then return end
    if choice == 'All branches' then
      state.branch_filter = nil
    else
      state.branch_filter = choice
    end
    M.refresh()
  end)
end

--- Toggle expand/collapse for the pipeline row under the cursor.
function M.toggle_expand()
  if not is_open() then return end

  local api    = require('nvim-cci.api')
  local render = require('nvim-cci.ui.render')

  -- Get the current cursor line (1-indexed)
  local cursor_line = vim.api.nvim_win_get_cursor(panel_win)[1]

  -- Use the line map from the last draw() call
  local meta = render.line_map and render.line_map[cursor_line]
  if not meta or meta.type ~= 'pipeline' then return end

  local pid = meta.id
  if state.expanded[pid] then
    -- Collapse
    state.expanded[pid] = nil
    render.draw(panel_buf, state, { legend = false })
    return
  end

  -- Expand
  state.expanded[pid] = true
  render.draw(panel_buf, state, { legend = false })

  -- Helper: fetch jobs for any workflows not yet loaded
  local function fetch_missing_jobs(wfs)
    for _, wf in ipairs(wfs) do
      local wf_id = wf.id
      if not state.jobs[wf_id] then
        api.get_jobs(wf_id, function(jerr, jdata)
          vim.schedule(function()
            if not jerr and jdata then
              state.jobs[wf_id] = jdata.items or {}
            end
            if is_open() then render.draw(panel_buf, state, { legend = false }) end
          end)
        end)
      end
    end
  end

  -- If workflows already cached (pre-fetched by refresh), just fetch missing jobs
  if state.workflows[pid] then
    fetch_missing_jobs(state.workflows[pid])
    return
  end

  api.get_workflows(pid, function(err, data)
    vim.schedule(function()
      if err then
        vim.notify('[nvim-cci] Error loading workflows: ' .. err, vim.log.levels.ERROR)
        return
      end
      state.workflows[pid] = (data and data.items) or {}
      if is_open() then render.draw(panel_buf, state, { legend = false }) end
      fetch_missing_jobs(state.workflows[pid])
    end)
  end)
end

return M

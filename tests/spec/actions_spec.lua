-- Minimal vim stub for running outside Neovim
if not vim then
  _G.vim = {
    fn = {
      confirm = function() return 1 end,  -- default: Yes
    },
    schedule = function(fn) fn() end,  -- fire callbacks synchronously in tests
    notify   = function() end,
    log      = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
  }
end

local actions = require('nvim-cci.actions')

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function make_api(responses)
  -- responses: table keyed by method name, value is { err, data }
  return {
    approve_job      = function(wf_id, id, cb) local r = responses.approve_job or {}; cb(r[1], r[2]) end,
    cancel_workflow  = function(id, cb) local r = responses.cancel_workflow or {}; cb(r[1], r[2]) end,
    rerun_workflow   = function(id, cb) local r = responses.rerun_workflow or {}; cb(r[1], r[2]) end,
  }
end

local function make_panel()
  local refreshed = false
  return {
    refresh  = function() refreshed = true end,
    _refreshed = function() return refreshed end,
  }
end

local function job_entry(id, name, status, job_type)
  return {
    type = 'job',
    id   = id,
    data = { id = id, name = name, status = status, type = job_type or 'build' },
  }
end

local function approval_job_entry(id, name, workflow_id)
  return {
    type        = 'job',
    id          = id,
    workflow_id = workflow_id or 'wf-default',
    data = {
      id                  = id,
      approval_request_id = id,
      name                = name,
      status              = 'on_hold',
      type                = 'approval',
    },
  }
end

local function workflow_entry(id, name, status)
  return {
    type = 'workflow',
    id   = id,
    data = { id = id, name = name, status = status },
  }
end

local function pipeline_entry(id)
  return {
    type = 'pipeline',
    id   = id,
    data = { id = id, state = 'success' },
  }
end

local function setup(responses, confirm_answer)
  actions._api     = make_api(responses or {})
  actions._panel   = make_panel()
  actions._confirm = function() return confirm_answer ~= false end  -- default true
end

local function teardown()
  actions._api     = nil
  actions._panel   = nil
  actions._confirm = nil
end

-- ── approve() ─────────────────────────────────────────────────────────────────

describe('actions.approve()', function()
  after_each(teardown)

  it('calls approve_job and refreshes on success', function()
    local called_wf, called_approval = nil, nil
    actions._api = {
      approve_job = function(wf_id, approval_id, cb) called_wf = wf_id; called_approval = approval_id; cb(nil, {}) end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local line_map = { [2] = approval_job_entry('job-1', 'deploy', 'wf-99') }
    actions.approve(line_map, 2)

    assert.equals('wf-99',  called_wf)
    assert.equals('job-1', called_approval)
    assert.is_true(actions._panel._refreshed())
  end)

  it('shows error notification and does not refresh on API error', function()
    local notified_level = nil
    local orig_notify = vim.notify
    vim.notify = function(_, level) notified_level = level end

    setup({ approve_job = { 'some error', nil } })
    local line_map = { [1] = approval_job_entry('job-1', 'deploy') }
    actions.approve(line_map, 1)

    vim.notify = orig_notify
    assert.equals(vim.log.levels.ERROR, notified_level)
    assert.is_false(actions._panel._refreshed())
  end)

  it('does nothing when user cancels confirmation', function()
    local api_called = false
    actions._api = {
      approve_job = function() api_called = true end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return false end

    local line_map = { [1] = approval_job_entry('job-1', 'deploy') }
    actions.approve(line_map, 1)

    assert.is_false(api_called)
    assert.is_false(actions._panel._refreshed())
  end)

  it('warns when cursor is not on a job row', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = pipeline_entry('pipe-1') }
    actions.approve(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('warns when job is not an approval job', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = job_entry('job-1', 'build', 'success', 'build') }
    actions.approve(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('warns when approval job is not on_hold', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    -- job is approval type but already succeeded
    local entry = { type = 'job', id = 'j1', data = { id = 'j1', name = 'hold', status = 'success', type = 'approval' } }
    local line_map = { [1] = entry }
    actions.approve(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('warns when cursor line has no entry (nil)', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    actions.approve({}, 5)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)
end)

-- ── abort() ───────────────────────────────────────────────────────────────────

describe('actions.abort()', function()
  after_each(teardown)

  it('calls cancel_workflow and refreshes on success', function()
    local api_called_with = nil
    actions._api = {
      cancel_workflow = function(id, cb) api_called_with = id; cb(nil, {}) end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local line_map = { [1] = workflow_entry('wf-1', 'build', 'running') }
    actions.abort(line_map, 1)

    assert.equals('wf-1', api_called_with)
    assert.is_true(actions._panel._refreshed())
  end)

  it('shows error and does not refresh on API failure', function()
    local notified_level = nil
    local orig_notify = vim.notify
    vim.notify = function(_, level) notified_level = level end

    setup({ cancel_workflow = { 'network error', nil } })
    local line_map = { [1] = workflow_entry('wf-1', 'build', 'running') }
    actions.abort(line_map, 1)

    vim.notify = orig_notify
    assert.equals(vim.log.levels.ERROR, notified_level)
    assert.is_false(actions._panel._refreshed())
  end)

  it('does nothing when user cancels', function()
    local api_called = false
    actions._api     = { cancel_workflow = function() api_called = true end }
    actions._panel   = make_panel()
    actions._confirm = function() return false end

    local line_map = { [1] = workflow_entry('wf-1', 'build', 'running') }
    actions.abort(line_map, 1)

    assert.is_false(api_called)
  end)

  it('warns when cursor is not on a workflow row', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = pipeline_entry('pipe-1') }
    actions.abort(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('warns when workflow is not running', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = workflow_entry('wf-1', 'build', 'success') }
    actions.abort(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('calls cancel_workflow for an on_hold workflow and refreshes', function()
    local api_called_with = nil
    actions._api = {
      cancel_workflow = function(id, cb) api_called_with = id; cb(nil, {}) end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local line_map = { [1] = workflow_entry('wf-hold', 'deploy', 'on_hold') }
    actions.abort(line_map, 1)

    assert.equals('wf-hold', api_called_with)
    assert.is_true(actions._panel._refreshed())
  end)

  it('calls cancel_workflow for an on_hold approval job row', function()
    local api_called_with = nil
    actions._api = {
      cancel_workflow = function(id, cb) api_called_with = id; cb(nil, {}) end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local entry = {
      type        = 'job',
      id          = 'job-hold',
      workflow_id = 'wf-parent',
      data        = { id = 'job-hold', name = 'hold-gate', status = 'on_hold', type = 'approval' },
    }
    local line_map = { [1] = entry }
    actions.abort(line_map, 1)

    assert.equals('wf-parent', api_called_with)
    assert.is_true(actions._panel._refreshed())
  end)

  it('shows error and does not call API when approval job row has no workflow_id', function()
    local api_called = false
    local notified_level = nil
    local orig_notify = vim.notify
    vim.notify = function(_, level) notified_level = level end

    actions._api = {
      cancel_workflow = function() api_called = true end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local entry = {
      type = 'job',
      id   = 'job-hold',
      -- workflow_id intentionally missing
      data = { id = 'job-hold', name = 'hold-gate', status = 'on_hold', type = 'approval' },
    }
    local line_map = { [1] = entry }
    actions.abort(line_map, 1)

    vim.notify = orig_notify
    assert.is_false(api_called)
    assert.equals(vim.log.levels.ERROR, notified_level)
  end)
end)

-- ── rerun() ───────────────────────────────────────────────────────────────────

describe('actions.rerun()', function()
  after_each(teardown)

  it('calls rerun_workflow and refreshes on success', function()
    local api_called_with = nil
    actions._api = {
      rerun_workflow = function(id, cb) api_called_with = id; cb(nil, {}) end,
    }
    actions._panel   = make_panel()
    actions._confirm = function() return true end

    local line_map = { [1] = workflow_entry('wf-2', 'deploy', 'failed') }
    actions.rerun(line_map, 1)

    assert.equals('wf-2', api_called_with)
    assert.is_true(actions._panel._refreshed())
  end)

  it('shows error and does not refresh on API failure', function()
    local notified_level = nil
    local orig_notify = vim.notify
    vim.notify = function(_, level) notified_level = level end

    setup({ rerun_workflow = { 'timeout', nil } })
    local line_map = { [1] = workflow_entry('wf-2', 'deploy', 'failed') }
    actions.rerun(line_map, 1)

    vim.notify = orig_notify
    assert.equals(vim.log.levels.ERROR, notified_level)
    assert.is_false(actions._panel._refreshed())
  end)

  it('does nothing when user cancels', function()
    local api_called = false
    actions._api     = { rerun_workflow = function() api_called = true end }
    actions._panel   = make_panel()
    actions._confirm = function() return false end

    local line_map = { [1] = workflow_entry('wf-2', 'deploy', 'failed') }
    actions.rerun(line_map, 1)

    assert.is_false(api_called)
  end)

  it('warns when cursor is not on a workflow row', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = job_entry('j1', 'test', 'failed', 'build') }
    actions.rerun(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)

  it('warns when workflow has not failed', function()
    local warned = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end

    setup({})
    local line_map = { [1] = workflow_entry('wf-2', 'deploy', 'running') }
    actions.rerun(line_map, 1)

    vim.notify = orig_notify
    assert.is_true(warned)
  end)
end)

-- ── open_browser() ────────────────────────────────────────────────────────────

describe('actions.open_browser()', function()
  local SLUG = 'github/myorg/myrepo'

  local function setup_open(open_fn)
    actions._open_url = open_fn or function() end
    actions._panel    = make_panel()
  end

  after_each(function()
    teardown()
    actions._open_url = nil
  end)

  it('opens job URL for a job row', function()
    local opened_url = nil
    setup_open(function(url) opened_url = url end)

    local entry = {
      type            = 'job',
      id              = 'job-uuid',
      pipeline_number = 42,
      workflow_id     = 'wf-uuid',
      data            = { id = 'job-uuid', name = 'test', status = 'failed',
                          job_number = 7 },
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    assert.equals(
      'https://app.circleci.com/pipelines/' .. SLUG .. '/42/workflows/wf-uuid/jobs/7',
      opened_url
    )
  end)

  it('opens workflow URL for a workflow row', function()
    local opened_url = nil
    setup_open(function(url) opened_url = url end)

    local entry = {
      type            = 'workflow',
      id              = 'wf-uuid',
      pipeline_number = 10,
      data            = { id = 'wf-uuid', name = 'build', status = 'running' },
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    assert.equals(
      'https://app.circleci.com/pipelines/' .. SLUG .. '/10/workflows/wf-uuid',
      opened_url
    )
  end)

  it('opens pipeline URL for a pipeline row', function()
    local opened_url = nil
    setup_open(function(url) opened_url = url end)

    local entry = {
      type            = 'pipeline',
      id              = 'pipe-uuid',
      pipeline_number = 5,
      data            = { id = 'pipe-uuid', number = 5, state = 'success' },
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    assert.equals(
      'https://app.circleci.com/pipelines/' .. SLUG .. '/5',
      opened_url
    )
  end)

  it('warns and does not open for a status row', function()
    local opened_url = nil
    local warned     = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end
    setup_open(function(url) opened_url = url end)

    local entry = { type = 'status' }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    vim.notify = orig_notify
    assert.is_true(warned)
    assert.is_nil(opened_url)
  end)

  it('warns and does not open for a help row', function()
    local opened_url = nil
    local warned     = false
    local orig_notify = vim.notify
    vim.notify = function(_, level) if level == vim.log.levels.WARN then warned = true end end
    setup_open(function(url) opened_url = url end)

    local entry = { type = 'help' }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    vim.notify = orig_notify
    assert.is_true(warned)
    assert.is_nil(opened_url)
  end)

  it('falls back to workflow URL when job_number is missing (pending jobs)', function()
    local opened_url = nil
    setup_open(function(url) opened_url = url end)

    local entry = {
      type            = 'job',
      id              = 'job-uuid',
      pipeline_number = 42,
      workflow_id     = 'wf-uuid',
      data            = { id = 'job-uuid', name = 'build', status = 'blocked', type = 'build' },
      -- job_number intentionally missing
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    local expected = 'https://app.circleci.com/pipelines/' .. SLUG .. '/42/workflows/wf-uuid'
    assert.equals(expected, opened_url)
  end)

  it('falls back to workflow URL for approval jobs even when job_number is set', function()
    local opened_url = nil
    setup_open(function(url) opened_url = url end)

    local entry = {
      type            = 'job',
      id              = 'job-uuid',
      pipeline_number = 42,
      workflow_id     = 'wf-uuid',
      data            = { id = 'job-uuid', name = 'hold', status = 'on_hold', type = 'approval',
                          job_number = 3 },  -- CircleCI sets job_number even for approvals
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    local expected = 'https://app.circleci.com/pipelines/' .. SLUG .. '/42/workflows/wf-uuid'
    assert.equals(expected, opened_url)
  end)

  it('errors and does not open when pipeline_number is missing', function()
    local opened_url    = nil
    local notified_level = nil
    local orig_notify = vim.notify
    vim.notify = function(_, level) notified_level = level end
    setup_open(function(url) opened_url = url end)

    local entry = {
      type = 'pipeline',
      id   = 'pipe-uuid',
      -- pipeline_number intentionally missing
      data = { id = 'pipe-uuid', state = 'success' },
    }
    actions.open_browser({ [1] = entry }, 1, SLUG)

    vim.notify = orig_notify
    assert.equals(vim.log.levels.ERROR, notified_level)
    assert.is_nil(opened_url)
  end)
end)

-- ── render.line_map integration (smoke test) ─────────────────────────────────

describe('render.line_map exposure', function()
  it('build_lines includes data field in each entry', function()
    -- Minimal vim stub for render
    if not vim.api then
      vim.api = {
        nvim_set_hl              = function() end,
        nvim_buf_set_lines       = function() end,
        nvim_buf_add_highlight   = function() end,
        nvim_buf_clear_namespace = function() end,
        nvim_create_namespace    = function() return 0 end,
      }
      vim.bo = setmetatable({}, { __newindex = function() end })
    end

    local render = require('nvim-cci.ui.render')
    local state = {
      pipelines = { { id = 'p1', state = 'success', created_at = '2020-01-01T00:00:00Z',
                      vcs = { branch = 'main' } } },
      expanded  = {},
      workflows = {},
      jobs      = {},
      loading   = false,
    }
    local _, _, meta = render.build_lines(state)
    assert.is_not_nil(meta[1].data)
    assert.equals('p1', meta[1].data.id)
  end)
end)

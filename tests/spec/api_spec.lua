-- Minimal vim stub for running outside Neovim
if not vim then
  _G.vim = {
    fn = {
      executable  = function() return 0 end,
      system      = function() return '' end,
      shellescape = function(s) return "'" .. s .. "'" end,
      stdpath     = function() return '/tmp/nvim-cci-test' end,
      mkdir       = function() end,
      fnamemodify = function(p, mod)
        if mod == ':h' then return p:match('(.+)/[^/]+$') or '.' end
        return p
      end,
      has      = function() return 0 end,
      jobstart = function() end,
      input    = function() return '' end,
    },
    v      = { shell_error = 0 },
    trim   = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end,
    notify = function() end,
    log    = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
  }
end

local auth = require('nvim-cci.auth')
local api  = require('nvim-cci.api')

-- ── Helpers ───────────────────────────────────────────────────────────────────

local FAKE_TOKEN = 'test-token-abc'
local BASE_URL   = 'https://circleci.com/api/v2'

-- Mock auth backend that always returns FAKE_TOKEN
local mock_auth_backend = {
  store    = function(t) FAKE_TOKEN = t; return true end,
  retrieve = function() return FAKE_TOKEN end,
  delete   = function() FAKE_TOKEN = nil; return true end,
}

-- Build a synchronous mock curl that fires callback immediately.
-- captured stores the last call: { method, url, opts }
local function make_mock_curl(status, decoded_data)
  local captured = {}
  local curl = {
    get = function(url, opts)
      captured.method = 'GET'
      captured.url    = url
      captured.opts   = opts
      opts.callback({ status = status, body = '__fixture__' })
    end,
    post = function(url, opts)
      captured.method = 'POST'
      captured.url    = url
      captured.opts   = opts
      opts.callback({ status = status, body = '__fixture__' })
    end,
    _captured = captured,
  }
  return curl
end

-- ── Setup / teardown ──────────────────────────────────────────────────────────

local function setup_api(status, decoded_data)
  auth._backend = mock_auth_backend
  local mock_curl = make_mock_curl(status, decoded_data)
  api._curl = mock_curl
  -- Return decoded_data directly (bypasses vim.json.decode)
  api._decode = function() return decoded_data end
  return mock_curl
end

local function teardown_api()
  auth._backend = nil
  api._curl     = nil
  api._decode   = nil
end

-- ── Tests: successful responses ───────────────────────────────────────────────

describe('api (success responses)', function()
  after_each(teardown_api)

  describe('get_pipelines()', function()
    it('calls GET /project/{slug}/pipeline', function()
      local fixture = { items = { { id = 'pipe-1' } }, next_page_token = nil }
      local mock_curl = setup_api(200, fixture)

      local got_err, got_data
      api.get_pipelines('github/org/repo', function(err, data)
        got_err  = err
        got_data = data
      end)

      assert.is_nil(got_err)
      assert.same(fixture, got_data)
      assert.equals('GET', mock_curl._captured.method)
      assert.equals(BASE_URL .. '/project/github/org/repo/pipeline', mock_curl._captured.url)
    end)

    it('sends the Circle-Token header', function()
      local mock_curl = setup_api(200, {})
      api.get_pipelines('github/org/repo', function() end)
      assert.equals(FAKE_TOKEN, mock_curl._captured.opts.headers['Circle-Token'])
    end)
  end)

  describe('get_workflows()', function()
    it('calls GET /pipeline/{id}/workflow', function()
      local fixture = { items = { { id = 'wf-1', status = 'running' } } }
      local mock_curl = setup_api(200, fixture)

      local got_err, got_data
      api.get_workflows('pipe-abc', function(err, data)
        got_err  = err
        got_data = data
      end)

      assert.is_nil(got_err)
      assert.same(fixture, got_data)
      assert.equals(BASE_URL .. '/pipeline/pipe-abc/workflow', mock_curl._captured.url)
    end)
  end)

  describe('get_jobs()', function()
    it('calls GET /workflow/{id}/job', function()
      local fixture = { items = { { id = 'job-1', name = 'build' } } }
      local mock_curl = setup_api(200, fixture)

      local got_err, got_data
      api.get_jobs('wf-abc', function(err, data)
        got_err  = err
        got_data = data
      end)

      assert.is_nil(got_err)
      assert.same(fixture, got_data)
      assert.equals(BASE_URL .. '/workflow/wf-abc/job', mock_curl._captured.url)
    end)
  end)

  describe('cancel_workflow()', function()
    it('calls POST /workflow/{id}/cancel', function()
      local mock_curl = setup_api(200, { message = 'Accepted' })

      local got_err
      api.cancel_workflow('wf-xyz', function(err) got_err = err end)

      assert.is_nil(got_err)
      assert.equals('POST', mock_curl._captured.method)
      assert.equals(BASE_URL .. '/workflow/wf-xyz/cancel', mock_curl._captured.url)
    end)
  end)

  describe('rerun_workflow()', function()
    it('calls POST /workflow/{id}/rerun', function()
      local mock_curl = setup_api(200, { workflow_id = 'new-wf' })

      local got_err
      api.rerun_workflow('wf-xyz', function(err) got_err = err end)

      assert.is_nil(got_err)
      assert.equals('POST', mock_curl._captured.method)
      assert.equals(BASE_URL .. '/workflow/wf-xyz/rerun', mock_curl._captured.url)
    end)
  end)

  describe('approve_job()', function()
    it('calls POST /workflow/approval/{id}', function()
      local mock_curl = setup_api(200, {})

      local got_err
      api.approve_job('approval-123', function(err) got_err = err end)

      assert.is_nil(got_err)
      assert.equals('POST', mock_curl._captured.method)
      assert.equals(BASE_URL .. '/workflow/approval/approval-123', mock_curl._captured.url)
    end)
  end)
end)

-- ── Tests: error handling ─────────────────────────────────────────────────────

describe('api (error handling)', function()
  after_each(teardown_api)

  it('returns "401: Unauthorized" on 401 status', function()
    local notified = false
    local orig_notify = vim.notify
    vim.notify = function() notified = true end

    setup_api(401, nil)
    local got_err, got_data
    api.get_pipelines('github/org/repo', function(err, data)
      got_err  = err
      got_data = data
    end)

    vim.notify = orig_notify

    assert.equals('401: Unauthorized', got_err)
    assert.is_nil(got_data)
    assert.is_true(notified)  -- auth.handle_401() fired vim.notify
  end)

  it('returns network error string on status 0', function()
    setup_api(0, nil)
    local got_err, got_data
    api.get_pipelines('github/org/repo', function(err, data)
      got_err  = err
      got_data = data
    end)
    assert.is_not_nil(got_err)
    assert.truthy(got_err:find('Network error'))
    assert.is_nil(got_data)
  end)

  it('returns API error string on 5xx status', function()
    setup_api(500, nil)
    local got_err, got_data
    api.get_pipelines('github/org/repo', function(err, data)
      got_err  = err
      got_data = data
    end)
    assert.is_not_nil(got_err)
    assert.truthy(got_err:find('500'))
    assert.is_nil(got_data)
  end)

  it('returns API error string on 404 status', function()
    setup_api(404, nil)
    local got_err, got_data
    api.get_workflows('bad-id', function(err, data)
      got_err  = err
      got_data = data
    end)
    assert.truthy(got_err:find('404'))
    assert.is_nil(got_data)
  end)

  it('returns decode error when _decode returns nil', function()
    auth._backend = mock_auth_backend
    api._decode   = function() return nil, 'invalid json' end
    local mock_curl = make_mock_curl(200, nil)
    api._curl = mock_curl

    local got_err
    api.get_pipelines('github/org/repo', function(err) got_err = err end)
    assert.truthy(got_err:find('Failed to decode'))
  end)
end)

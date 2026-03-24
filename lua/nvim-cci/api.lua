local M = {}

local BASE_URL = 'https://circleci.com/api/v2'

-- ── Injectable dependencies (override in tests) ───────────────────────────────

-- Set to a table with .get(url, opts) and .post(url, opts) to mock curl.
M._curl = nil

-- Set to a decode function to mock vim.json.decode.
M._decode = nil

-- ── Internal helpers ──────────────────────────────────────────────────────────

local function get_curl()
  if M._curl then return M._curl end
  return require('plenary.curl')
end

local function json_decode(s)
  if M._decode then return M._decode(s) end
  local ok, result = pcall(vim.json.decode, s)
  if not ok then return nil, tostring(result) end
  return result, nil
end

local function make_headers()
  local token = require('nvim-cci.auth').retrieve()
  return { ['Circle-Token'] = token or '' }
end

local function handle_response(res, cb)
  if res.status == 401 then
    require('nvim-cci.auth').handle_401()
    cb('401: Unauthorized', nil)
    return
  end
  if res.status == 0 then
    cb('Network error: no response from server', nil)
    return
  end
  if res.status >= 400 then
    cb(string.format('API error: %d', res.status), nil)
    return
  end
  local data, err = json_decode(res.body)
  if err then
    cb('Failed to decode response: ' .. err, nil)
    return
  end
  cb(nil, data)
end

local function get(path, cb)
  get_curl().get(BASE_URL .. path, {
    headers  = make_headers(),
    callback = function(res) handle_response(res, cb) end,
  })
end

local function post(path, cb)
  get_curl().post(BASE_URL .. path, {
    headers  = make_headers(),
    callback = function(res) handle_response(res, cb) end,
  })
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- GET /project/{slug}/pipeline[?branch=<branch>] — returns first page of pipelines.
--- @param project_slug string  e.g. "github/org/repo"
--- @param branch string|nil  optional branch filter
--- @param cb function  cb(err, data)
function M.get_pipelines(project_slug, branch, cb)
  local path = '/project/' .. project_slug .. '/pipeline'
  if branch then
    path = path .. '?branch=' .. branch
  end
  get(path, cb)
end

--- GET /pipeline/{id}/workflow — returns workflows for a pipeline.
--- @param pipeline_id string
--- @param cb function  cb(err, data)
function M.get_workflows(pipeline_id, cb)
  get('/pipeline/' .. pipeline_id .. '/workflow', cb)
end

--- GET /workflow/{id}/job — returns jobs for a workflow.
--- @param workflow_id string
--- @param cb function  cb(err, data)
function M.get_jobs(workflow_id, cb)
  get('/workflow/' .. workflow_id .. '/job', cb)
end

--- POST /workflow/{id}/cancel — cancels a running workflow.
--- @param workflow_id string
--- @param cb function  cb(err, data)
function M.cancel_workflow(workflow_id, cb)
  post('/workflow/' .. workflow_id .. '/cancel', cb)
end

--- POST /workflow/{id}/rerun — reruns a workflow from failed.
--- @param workflow_id string
--- @param cb function  cb(err, data)
function M.rerun_workflow(workflow_id, cb)
  post('/workflow/' .. workflow_id .. '/rerun', cb)
end

--- POST /workflow/{workflow_id}/approve/{approval_request_id} — approves a hold job.
--- @param workflow_id string
--- @param approval_request_id string
--- @param cb function  cb(err, data)
function M.approve_job(workflow_id, approval_request_id, cb)
  post('/workflow/' .. workflow_id .. '/approve/' .. approval_request_id, cb)
end

--- Parse a git remote URL into a CircleCI project slug.
--- Supports SSH (git@github.com:org/repo.git) and HTTPS (https://github.com/org/repo).
--- @param remote_url string
--- @return string|nil  slug e.g. "github/org/repo", or nil if unparseable
function M.slug_from_remote(remote_url)
  if not remote_url then return nil end
  local url = vim.trim(remote_url)

  -- Strip trailing slash and .git suffix
  url = url:gsub('/$', ''):gsub('%.git$', '')

  -- SSH: git@github.com:org/repo
  local host, path = url:match('^git@([^:]+):(.+)$')
  if host and path then
    local provider = host:match('^([^.]+)')
    return provider .. '/' .. path
  end

  -- HTTPS: https://github.com/org/repo  or  http://github.com/org/repo
  host, path = url:match('^https?://([^/]+)/(.+)$')
  if host and path then
    local provider = host:match('^([^.]+)')
    return provider .. '/' .. path
  end

  return nil
end

return M

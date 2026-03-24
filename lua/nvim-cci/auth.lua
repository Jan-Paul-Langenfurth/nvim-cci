local M = {}

local SERVICE = 'nvim-cci'
local ACCOUNT = 'circleci_token'

-- ── Backend: secret-tool (Linux / libsecret) ─────────────────────────────────

local secret_tool = {}

function secret_tool.store(token)
  vim.fn.system(string.format(
    'echo -n %s | secret-tool store --label=%s service %s account %s',
    vim.fn.shellescape(token),
    vim.fn.shellescape('nvim-cci CircleCI token'),
    SERVICE,
    ACCOUNT
  ))
  return vim.v.shell_error == 0
end

function secret_tool.retrieve()
  local out = vim.fn.system(string.format(
    'secret-tool lookup service %s account %s',
    SERVICE,
    ACCOUNT
  ))
  if vim.v.shell_error ~= 0 then return nil end
  local t = vim.trim(out)
  return t ~= '' and t or nil
end

function secret_tool.delete()
  vim.fn.system(string.format(
    'secret-tool clear service %s account %s',
    SERVICE,
    ACCOUNT
  ))
  return true
end

-- ── Backend: security (macOS Keychain) ───────────────────────────────────────

local keychain = {}

function keychain.store(token)
  vim.fn.system({
    'security', 'add-generic-password', '-U',
    '-s', SERVICE, '-a', ACCOUNT, '-w', token,
  })
  return vim.v.shell_error == 0
end

function keychain.retrieve()
  local out = vim.fn.system({
    'security', 'find-generic-password',
    '-s', SERVICE, '-a', ACCOUNT, '-w',
  })
  if vim.v.shell_error ~= 0 then return nil end
  local t = vim.trim(out)
  return t ~= '' and t or nil
end

function keychain.delete()
  vim.fn.system({
    'security', 'delete-generic-password',
    '-s', SERVICE, '-a', ACCOUNT,
  })
  return true
end

-- ── Backend: file fallback ────────────────────────────────────────────────────

local file_backend = {}

local function fallback_path()
  return vim.fn.stdpath('config') .. '/nvim-cci/token'
end

function file_backend.store(token)
  local path = fallback_path()
  local dir = vim.fn.fnamemodify(path, ':h')
  vim.fn.mkdir(dir, 'p')
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(token)
  f:close()
  vim.fn.system('chmod 600 ' .. vim.fn.shellescape(path))
  vim.notify(
    '[nvim-cci] Token stored in plain file (keyring unavailable): ' .. path
    .. '\nThis is less secure than the OS keyring.',
    vim.log.levels.WARN
  )
  return true
end

function file_backend.retrieve()
  local path = fallback_path()
  local f = io.open(path, 'r')
  if not f then return nil end
  local token = f:read('*a')
  f:close()
  local t = vim.trim(token)
  return t ~= '' and t or nil
end

function file_backend.delete()
  local path = fallback_path()
  os.remove(path)
  return true
end

-- ── Backend selection ─────────────────────────────────────────────────────────

-- Set M._backend to a backend table to override auto-detection (useful in tests).
M._backend = nil

local function select_backend()
  if M._backend then return M._backend end
  if vim.fn.executable('secret-tool') == 1 then
    return secret_tool
  elseif vim.fn.executable('security') == 1 then
    return keychain
  else
    return file_backend
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Store a token in the OS keyring (or file fallback).
--- @param token string
--- @return boolean
function M.store(token)
  return select_backend().store(token)
end

--- Retrieve the stored token, or nil if not found.
--- @return string|nil
function M.retrieve()
  return select_backend().retrieve()
end

--- Delete the stored token.
--- @return boolean
function M.delete()
  return select_backend().delete()
end

--- Return true if a token is currently stored.
--- @return boolean
function M.is_authenticated()
  return M.retrieve() ~= nil
end

--- Notify the user that the current token is invalid and they must re-login.
--- Called by the API client on 401 responses.
function M.handle_401()
  vim.notify(
    '[nvim-cci] CircleCI returned 401 – your token may be expired or invalid.\n'
    .. 'Run :CCILogin to re-authenticate.',
    vim.log.levels.ERROR
  )
end

return M

-- Minimal vim stub for running outside Neovim
if not vim then
  _G.vim = {
    fn = {
      executable  = function() return 0 end,
      system      = function() return '' end,
      shellescape = function(s) return "'" .. s:gsub("'", "'\\''") .. "'" end,
      stdpath     = function() return '/tmp/nvim-cci-test' end,
      mkdir       = function(path)
        os.execute('mkdir -p ' .. path)
      end,
      fnamemodify = function(p, mod)
        if mod == ':h' then
          return p:match('(.+)/[^/]+$') or '.'
        end
        return p
      end,
      has = function() return 0 end,
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

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function make_mock_backend()
  local store = nil
  return {
    store    = function(token) store = token; return true end,
    retrieve = function() return store end,
    delete   = function() store = nil; return true end,
    _get     = function() return store end,
  }
end

-- ── Tests: public API via injected backend ────────────────────────────────────

describe('auth (mock backend)', function()
  local mock

  before_each(function()
    mock = make_mock_backend()
    auth._backend = mock
  end)

  after_each(function()
    auth._backend = nil
  end)

  describe('store()', function()
    it('stores the token and returns true', function()
      local ok = auth.store('tok-abc')
      assert.is_true(ok)
      assert.equals('tok-abc', mock._get())
    end)
  end)

  describe('retrieve()', function()
    it('returns nil when no token is stored', function()
      assert.is_nil(auth.retrieve())
    end)

    it('returns the stored token', function()
      auth.store('tok-xyz')
      assert.equals('tok-xyz', auth.retrieve())
    end)
  end)

  describe('delete()', function()
    it('removes the stored token', function()
      auth.store('tok-del')
      auth.delete()
      assert.is_nil(auth.retrieve())
    end)

    it('returns true', function()
      assert.is_true(auth.delete())
    end)
  end)

  describe('is_authenticated()', function()
    it('returns false when no token exists', function()
      assert.is_false(auth.is_authenticated())
    end)

    it('returns true after storing a token', function()
      auth.store('tok-auth')
      assert.is_true(auth.is_authenticated())
    end)

    it('returns false after deleting a token', function()
      auth.store('tok-del')
      auth.delete()
      assert.is_false(auth.is_authenticated())
    end)
  end)
end)

-- ── Tests: file fallback backend ──────────────────────────────────────────────

describe('auth (file fallback)', function()
  local tmp_dir = '/tmp/nvim-cci-test-auth-' .. tostring(os.time())
  local tmp_token_path = tmp_dir .. '/nvim-cci/token'

  -- Override stdpath to use a temp dir
  local orig_stdpath = vim.fn.stdpath
  local orig_notify  = vim.notify

  before_each(function()
    vim.fn.stdpath = function() return tmp_dir end
    vim.notify     = function() end  -- suppress warnings in tests
    os.execute('mkdir -p ' .. tmp_dir .. '/nvim-cci')
    -- Force file backend by setting _backend to nil and making keyring unavailable
    auth._backend = nil
    vim.fn.executable = function() return 0 end  -- no secret-tool / security
  end)

  after_each(function()
    vim.fn.stdpath = orig_stdpath
    vim.notify     = orig_notify
    os.execute('rm -rf ' .. tmp_dir)
    auth._backend = nil
  end)

  it('stores token to file', function()
    auth.store('file-token')
    local f = io.open(tmp_token_path, 'r')
    assert.is_not_nil(f)
    local content = f:read('*a')
    f:close()
    assert.equals('file-token', content)
  end)

  it('retrieves token from file', function()
    local f = io.open(tmp_token_path, 'w')
    f:write('read-token')
    f:close()
    assert.equals('read-token', auth.retrieve())
  end)

  it('returns nil when no file exists', function()
    os.remove(tmp_token_path)
    assert.is_nil(auth.retrieve())
  end)

  it('deletes the token file', function()
    local f = io.open(tmp_token_path, 'w')
    f:write('del-token')
    f:close()
    auth.delete()
    local f2 = io.open(tmp_token_path, 'r')
    assert.is_nil(f2)
  end)

  it('trims whitespace when reading token', function()
    local f = io.open(tmp_token_path, 'w')
    f:write('  padded-token  \n')
    f:close()
    assert.equals('padded-token', auth.retrieve())
  end)
end)

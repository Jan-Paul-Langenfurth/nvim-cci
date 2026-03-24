-- Minimal vim stub
if not vim then
  _G.vim = {
    trim = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end,
    fn   = {},
    log  = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
  }
end

local api = require('nvim-cci.api')

describe('api.slug_from_remote()', function()
  describe('SSH remotes', function()
    it('parses a standard SSH remote', function()
      assert.equals('github/org/repo', api.slug_from_remote('git@github.com:org/repo.git'))
    end)

    it('strips .git suffix', function()
      assert.equals('github/org/repo', api.slug_from_remote('git@github.com:org/repo.git'))
    end)

    it('works without .git suffix', function()
      assert.equals('github/org/repo', api.slug_from_remote('git@github.com:org/repo'))
    end)

    it('works with bitbucket host', function()
      assert.equals('bitbucket/org/repo', api.slug_from_remote('git@bitbucket.org:org/repo.git'))
    end)

    it('works with gitlab host', function()
      assert.equals('gitlab/org/repo', api.slug_from_remote('git@gitlab.com:org/repo.git'))
    end)
  end)

  describe('HTTPS remotes', function()
    it('parses a standard HTTPS remote', function()
      assert.equals('github/org/repo', api.slug_from_remote('https://github.com/org/repo'))
    end)

    it('strips .git suffix', function()
      assert.equals('github/org/repo', api.slug_from_remote('https://github.com/org/repo.git'))
    end)

    it('strips trailing slash', function()
      assert.equals('github/org/repo', api.slug_from_remote('https://github.com/org/repo/'))
    end)

    it('works with http (non-TLS)', function()
      assert.equals('github/org/repo', api.slug_from_remote('http://github.com/org/repo'))
    end)

    it('works with bitbucket', function()
      assert.equals('bitbucket/org/repo', api.slug_from_remote('https://bitbucket.org/org/repo.git'))
    end)

    it('works with gitlab', function()
      assert.equals('gitlab/org/repo', api.slug_from_remote('https://gitlab.com/org/repo'))
    end)
  end)

  describe('edge cases', function()
    it('returns nil for nil input', function()
      assert.is_nil(api.slug_from_remote(nil))
    end)

    it('returns nil for empty string', function()
      assert.is_nil(api.slug_from_remote(''))
    end)

    it('returns nil for unrecognised format', function()
      assert.is_nil(api.slug_from_remote('not-a-url'))
    end)

    it('trims leading/trailing whitespace', function()
      assert.equals('github/org/repo', api.slug_from_remote('  git@github.com:org/repo.git  \n'))
    end)
  end)
end)

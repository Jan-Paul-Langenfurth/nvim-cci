-- Minimal vim stub for running outside Neovim
if not vim then
  _G.vim = {
    deepcopy = function(t)
      local function copy(obj)
        if type(obj) ~= 'table' then return obj end
        local res = {}
        for k, v in pairs(obj) do res[copy(k)] = copy(v) end
        return res
      end
      return copy(t)
    end,
  }
end

local config = require('nvim-cci.config')

describe('nvim-cci config', function()
  describe('defaults', function()
    it('has a keymap table', function()
      assert.is_table(config.defaults.keymap)
    end)

    it('defines toggle keymap', function()
      assert.equals('<leader>ci', config.defaults.keymap.toggle)
    end)

    it('defines all expected keymap keys', function()
      local expected = { 'toggle', 'refresh', 'approve', 'abort', 'rerun', 'close' }
      for _, key in ipairs(expected) do
        assert.is_not_nil(config.defaults.keymap[key], 'missing keymap: ' .. key)
      end
    end)
  end)

  describe('merge()', function()
    it('returns defaults when called with nil', function()
      local result = config.merge(nil)
      assert.same(config.defaults, result)
    end)

    it('returns defaults when called with empty table', function()
      local result = config.merge({})
      assert.same(config.defaults, result)
    end)

    it('overrides a keymap entry', function()
      local result = config.merge({ keymap = { toggle = '<leader>cc' } })
      assert.equals('<leader>cc', result.keymap.toggle)
    end)

    it('preserves unoverridden keymap entries', function()
      local result = config.merge({ keymap = { toggle = '<leader>cc' } })
      assert.equals('r', result.keymap.refresh)
    end)

    it('does not mutate the defaults', function()
      config.merge({ keymap = { toggle = '<leader>cc' } })
      assert.equals('<leader>ci', config.defaults.keymap.toggle)
    end)

    it('accepts a top-level scalar override', function()
      local result = config.merge({ custom_field = 42 })
      assert.equals(42, result.custom_field)
    end)
  end)
end)

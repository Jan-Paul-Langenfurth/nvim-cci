-- luacheck configuration for nvim-CCI
-- https://luacheck.readthedocs.io/en/stable/config.html

-- Neovim global
globals = { 'vim' }

-- busted test globals (available in tests/spec/)
files['tests/**/*.lua'] = {
  globals = {
    'describe', 'it', 'before_each', 'after_each',
    'pending', 'assert', 'spy', 'stub', 'mock',
  },
}

-- Suppress warnings for unused function arguments prefixed with '_'
unused_args = true
self = false

-- Line length limit (120 is common for Lua/nvim plugin code)
max_line_length = 120

-- Allow defining the same variable in different scopes (common in Lua)
redefined_vars = false

# PRD — Phase 1: Project Scaffold

## Goal
Establish the plugin's directory structure, entry point, and test runner so all subsequent phases have a consistent foundation to build on.

---

## Acceptance Criteria

- **Given** a user adds `nvim-cci` via `lazy.nvim`, **when** nvim starts, **then** the plugin loads without errors.
- **Given** the user calls `require('nvim-cci').setup({})`, **when** no config is provided, **then** it applies sensible defaults without crashing.
- **Given** a developer runs `make test`, **when** the test suite is empty, **then** `busted` runs and exits 0.
- **Given** any Lua file in `lua/nvim-cci/`, **when** it is `require`d, **then** it resolves correctly relative to the plugin root.

---

## Technical Design Notes

**Directory structure:**
```
nvim-cci/
├── lua/
│   └── nvim-cci/
│       ├── init.lua        -- setup() entry point
│       ├── config.lua      -- default config + merge logic
│       ├── api.lua         -- CircleCI HTTP client (Phase 3)
│       ├── auth.lua        -- OAuth + keyring (Phase 2)
│       ├── ui/
│       │   ├── panel.lua   -- side panel (Phase 4)
│       │   └── render.lua  -- buffer rendering helpers
│       └── actions.lua     -- approve / abort / rerun (Phase 5)
├── plugin/
│   └── nvim-cci.lua        -- auto-loaded, registers vim commands
├── tests/
│   └── spec/
│       └── config_spec.lua -- first test file
├── Makefile
└── README.md
```

**`setup()` signature:**
```lua
require('nvim-cci').setup({
  keymap = {
    toggle = '<leader>ci',  -- open/close panel
    refresh = 'r',
    approve = 'a',
    abort = 'x',
    rerun = 'R',
    close = 'q',
  },
})
```

**Makefile targets:**
```makefile
test:
    busted tests/spec/
lint:
    luacheck lua/
```

**Dependencies (declared in plugin spec):**
- `MunifTanjim/nui.nvim`
- `nvim-lua/plenary.nvim`

---

## Implementation Tasks

- [ ] Create directory structure as defined above
- [ ] Write `lua/nvim-cci/config.lua` — default config table + `merge(user_config)` function
- [ ] Write `lua/nvim-cci/init.lua` — `setup(opts)` that merges config and is a no-op otherwise
- [ ] Write `plugin/nvim-cci.lua` — register `:CCIOpen`, `:CCIClose`, `:CCIToggle`, `:CCILogin`, `:CCILogout` commands (stubs at this stage)
- [ ] Write `Makefile` with `test` and `lint` targets
- [ ] Install `busted` and `luacheck` in dev environment, document in README
- [ ] Write `tests/spec/config_spec.lua` — test default config and user override merging
- [ ] Verify `lazy.nvim` spec loads the plugin cleanly

---

## Out of Scope

- Any real functionality (auth, API, UI) — stubs only
- CI for the plugin itself (Phase 6)

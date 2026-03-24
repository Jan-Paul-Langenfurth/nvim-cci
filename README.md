> **Note:** This repository exists to explore **Spec-Driven Development (SDD)** — a workflow where PRDs and acceptance criteria are written first, then used to drive implementation via AI-assisted coding. The plugin itself is real and functional, but the primary goal is to experiment with the SDD process.

# nvim-CCI

[![Tests](https://github.com/your-username/nvim-CCI/actions/workflows/test.yml/badge.svg)](https://github.com/your-username/nvim-CCI/actions/workflows/test.yml)

> Interact with CircleCI from inside Neovim — view pipelines, expand workflows and jobs, approve hold jobs, abort running workflows, and rerun failed ones, all without leaving your editor.


---

## Features

- Side panel listing pipelines for the current git project (auto-detected from `git remote`)
- Expand/collapse drilldown into workflows and jobs
- Status icons and colour highlights (`✓` success · `✗` failed · `⧗` running · `⏸` on hold · `○` canceled)
- Approve hold jobs (`a`), abort running workflows (`x`), rerun failed workflows (`R`)
- Confirmation prompts before destructive actions
- GitHub OAuth — paste a CircleCI Personal API Token; stored in OS keyring (secret-tool / macOS Keychain) with a plain-file fallback
- All-Lua, no external daemons; async HTTP via `plenary.curl`

---

## Requirements

| Requirement | Version |
|---|---|
| Neovim | ≥ 0.9 |
| [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | latest |
| [nui.nvim](https://github.com/MunifTanjim/nui.nvim) | latest |
| Linux: `libsecret` / `secret-tool` | for keyring (optional) |
| macOS: Keychain (`security` CLI) | for keyring (optional) |

---

## Installation

### lazy.nvim

```lua
{
  'your-username/nvim-CCI',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
  },
  config = function()
    require('nvim-cci').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'your-username/nvim-CCI',
  requires = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
  },
  config = function()
    require('nvim-cci').setup()
  end,
}
```

---

## Configuration

All options are optional. The table below shows the defaults:

```lua
require('nvim-cci').setup({
  keymap = {
    toggle  = '<leader>ci',  -- open / close the CCI panel
    refresh = 'r',           -- refresh pipeline list
    approve = 'a',           -- approve on-hold approval job
    abort   = 'x',           -- abort running workflow
    rerun   = 'R',           -- rerun failed workflow
    close   = 'q',           -- close the panel
  },
})
```

> Keymaps are buffer-local — they only apply inside the CCI panel and do not pollute your global keymap.

---

## Usage

### Commands

| Command      | Description                              |
|--------------|------------------------------------------|
| `:CCIToggle` | Toggle the CircleCI panel open / closed  |
| `:CCIOpen`   | Open the CircleCI panel                  |
| `:CCIClose`  | Close the CircleCI panel                 |
| `:CCILogin`  | Authenticate with a CircleCI API token   |
| `:CCILogout` | Remove the stored token                  |

### Panel keybindings

These are active only when the cursor is inside the CCI panel:

| Key       | Action                                   |
|-----------|------------------------------------------|
| `<Enter>` | Expand / collapse the pipeline under the cursor |
| `r`       | Refresh the pipeline list                |
| `a`       | Approve the on-hold job under the cursor |
| `x`       | Abort the running workflow under the cursor |
| `R`       | Rerun the failed workflow under the cursor |
| `q`       | Close the panel                          |

### Workflow

1. Open the panel in any directory that has a git remote pointing to a CircleCI-connected repository.
2. Press `<leader>ci` (or `:CCIToggle`) to open the panel.
3. Navigate to a pipeline and press `<Enter>` to expand its workflows and jobs.
4. Press `R` on a failed workflow to rerun, `a` on an on-hold job to approve, or `x` on a running workflow to cancel.
5. Press `r` to refresh the list after an action.

---

## Authentication

nvim-CCI uses CircleCI **Personal API Tokens** (not a full OAuth redirect flow).

**Step-by-step:**

1. Run `:CCILogin` in Neovim.
2. The plugin opens `https://app.circleci.com/settings/user/tokens` in your browser.
3. Click **Create New Token**, give it a name (e.g. `nvim-cci`), and copy the token.
4. Paste the token into the prompt that appears in Neovim and press `<Enter>`.
5. The token is stored securely in the OS keyring (or in `~/.config/nvim-cci/token` with a warning if no keyring is available).

To remove your token, run `:CCILogout`.

**Token storage backends (in order of preference):**

| Platform | Backend                             |
|----------|-------------------------------------|
| Linux    | `secret-tool` (GNOME Keyring / KWallet) |
| macOS    | macOS Keychain (`security` CLI)     |
| Fallback | `~/.config/nvim-cci/token` (chmod 600, less secure) |

---

## Contributing

Contributions are welcome! Please:

1. Fork the repo and create a feature branch.
2. Run `make test` and `make lint` before opening a PR — CI will enforce this.
3. Keep new code covered by tests in `tests/spec/`.

### Dev setup

```bash
# Install LuaRocks (if not present)
luarocks install busted
luarocks install luacheck

# Run tests
make test

# Run linter
make lint
```
## License

MIT — see [LICENSE](LICENSE).

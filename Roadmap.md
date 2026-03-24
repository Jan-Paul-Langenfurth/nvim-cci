# nvim-CCI Roadmap

A Neovim plugin written in Lua to interact with CircleCI from within your editor.

---

## Decisions

| Topic | Decision |
|---|---|
| Language | Lua |
| Auth | GitHub OAuth via CircleCI |
| Credential storage | OS keyring (via nvim secrets) |
| Project detection | Auto-detect from git remote URL |
| UI | Side panel (vertical split) |
| Dependencies | `nui.nvim` + `plenary.nvim` |
| Refresh | Manual (`r` to refresh) |
| Testing | Unit tests with `busted`, mocked API |

---

## Phase 1 — Project Scaffold

- [ ] Set up plugin directory structure (`lua/nvim-cci/`, `plugin/`, `tests/`)
- [ ] Define `setup()` entry point with user config options
- [ ] Add `lazy.nvim` / `packer` spec and README install instructions
- [ ] Configure `busted` test runner with a `Makefile` target

---

## Phase 2 — Authentication

- [ ] Implement GitHub OAuth flow via CircleCI (open browser, handle redirect/token exchange)
- [ ] Store the resulting CircleCI API token securely using the OS keyring
- [ ] Provide `:CCILogin` command to initiate auth and `:CCILogout` to clear credentials
- [ ] On startup, check for stored token and prompt to login if missing
- [ ] Unit tests: token storage, retrieval, and missing-token handling

---

## Phase 3 — CircleCI API Client

- [ ] Wrap `plenary.curl` for async HTTP requests with auth headers
- [ ] Implement API calls:
  - `GET /project/{slug}/pipeline` — list recent pipelines
  - `GET /pipeline/{id}/workflow` — get workflows for a pipeline
  - `GET /workflow/{id}/job` — get jobs for a workflow
  - `POST /workflow/{id}/cancel` — cancel a running workflow
  - `POST /workflow/{id}/rerun` — re-run a failed workflow
  - `POST /workflow/approval/{approval_request_id}` — approve a held job
- [ ] Auto-detect project slug from `git remote get-url origin`
- [ ] Unit tests: each API call with mocked responses, error handling, slug parsing

---

## Phase 4 — Side Panel UI

- [ ] Open/close side panel with `:CCIOpen` / `:CCIClose` / `:CCIToggle` (and a default keybind)
- [ ] Pipeline list view: branch name, status icon, trigger time
  - Status icons: `✓` passed, `✗` failed, `⧗` running, `⏸` on hold
- [ ] Highlight failed pipelines prominently
- [ ] Drilldown: press `<Enter>` on a pipeline to expand and show its workflows and jobs
- [ ] Keybindings (vim-native, all configurable):
  - `r` — refresh
  - `<Enter>` — expand / collapse pipeline
  - `a` — approve held job (when cursor is on an approval job)
  - `x` — abort running workflow
  - `R` — re-run failed workflow
  - `q` — close panel
- [ ] Unit tests: rendering pipeline list, status icons, expand/collapse state

---

## Phase 5 — Actions

- [ ] Approve held job: confirm prompt → call approval API
- [ ] Abort workflow: confirm prompt → call cancel API
- [ ] Re-run workflow: confirm prompt → call rerun API
- [ ] Show feedback (success / error) in the panel after each action
- [ ] Refresh the panel automatically after a successful action
- [ ] Unit tests: each action, confirmation flow, error display

---

## Phase 6 — Polish & Distribution

- [ ] Full README with install, setup, and keybindings docs
- [ ] Screencast / demo GIF
- [ ] CI for the plugin itself (run `busted` tests on push)
- [ ] Submit to `awesome-neovim` / announce

---

## Out of Scope (for now)

- Real-time auto-polling
- Triggering new pipelines
- Viewing raw job logs

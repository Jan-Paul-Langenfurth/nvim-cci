# PRD — Phase 6: Polish & Distribution

## Goal
Make the plugin ready for public use: complete documentation, a demo, and CI so it stays healthy after release.

---

## Acceptance Criteria

- **Given** a new user visits the repo, **when** they read the README, **then** they can install, configure, and use the plugin without any other reference.
- **Given** a developer opens a PR, **when** tests or lint fail, **then** the CI check fails and blocks the merge.
- **Given** CI runs on push, **when** all tests pass, **then** the badge in the README shows green.
- **Given** the plugin is submitted to `awesome-neovim`, **when** reviewers check the repo, **then** it meets the listing criteria (README, license, CI badge).

---

## Technical Design Notes

**README sections:**
1. Demo GIF (top of file)
2. Features list
3. Requirements (nvim version, dependencies)
4. Installation (`lazy.nvim` and `packer` snippets)
5. Configuration (full `setup()` options table with defaults)
6. Usage (keybindings table, commands list)
7. Auth setup (step-by-step `:CCILogin` walkthrough)
8. Contributing

**CI (GitHub Actions):**
```yaml
# .github/workflows/test.yml
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Neovim
        uses: rhysd/action-setup-vim@v1
        with: { neovim: true, version: stable }
      - name: Install busted
        run: luarocks install busted
      - name: Run tests
        run: make test
      - name: Run lint
        run: make lint
```

**Demo GIF:**
Record with `asciinema` + `agg` (converts to GIF):
1. Open nvim in a repo with CircleCI
2. Run `:CCIToggle` — panel opens, pipelines load
3. Navigate to a failed pipeline, press `<Enter>` to expand
4. Press `R` to re-run, confirm
5. Press `r` to refresh, see status update

**License:** MIT

---

## Implementation Tasks

- [ ] Write full README with all sections listed above
- [ ] Add MIT `LICENSE` file
- [ ] Set up `.github/workflows/test.yml` for CI on push + PR
- [ ] Add CI badge to README
- [ ] Record demo screencast and convert to GIF, add to README
- [ ] Add `.luacheckrc` config file with sensible defaults for nvim plugin development
- [ ] Review all `TODO` / `FIXME` comments and resolve or document them
- [ ] Submit to `awesome-neovim` via PR to the `rockerBOO/awesome-neovim` repo

---

## Out of Scope

- Auto-polling / real-time updates
- Published to LuaRocks (optional future step)
- Versioned releases / changelog automation

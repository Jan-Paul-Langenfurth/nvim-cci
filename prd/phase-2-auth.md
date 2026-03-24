# PRD — Phase 2: Authentication

## Goal
Allow the user to authenticate with CircleCI via GitHub OAuth, store the resulting token securely in the OS keyring, and expose login/logout commands.

---

## Acceptance Criteria

- **Given** the user runs `:CCILogin`, **when** they are not authenticated, **then** a browser opens to the CircleCI GitHub OAuth URL.
- **Given** the OAuth flow completes successfully, **when** CircleCI returns a token, **then** the token is stored in the OS keyring and a success message is shown in nvim.
- **Given** a token exists in the keyring, **when** the plugin initialises, **then** it retrieves the token silently without prompting.
- **Given** no token exists in the keyring, **when** the plugin initialises, **then** it notifies the user to run `:CCILogin`.
- **Given** the user runs `:CCILogout`, **when** a token is stored, **then** it is removed from the keyring and a confirmation message is shown.
- **Given** the user runs `:CCILogout`, **when** no token exists, **then** a message says "not logged in".
- **Given** an expired or invalid token, **when** any API call returns 401, **then** the plugin notifies the user to re-run `:CCILogin`.

---

## Technical Design Notes

**OAuth flow:**
CircleCI supports token-based auth. The practical flow for a CLI/plugin tool:
1. User generates a CircleCI Personal API Token at `app.circleci.com/settings/user/tokens` (GitHub OAuth login on that page covers the "GitHub login" requirement).
2. Plugin opens that URL via `vim.fn.jobstart({'xdg-open', url})` (Linux) / `open` (macOS).
3. User pastes the token back into a nvim input prompt (`vim.fn.input()`).
4. Token is saved to keyring.

> Note: A full programmatic OAuth redirect flow requires a local HTTP server to catch the callback, which adds significant complexity. The token-paste approach is the standard pattern used by CircleCI's own CLI tool.

**Keyring integration:**
Use the system keyring via a shell call to `secret-tool` (Linux/libsecret) or `security` (macOS Keychain). Abstract behind `auth.store(token)` / `auth.retrieve()` / `auth.delete()` so the backend can be swapped.

```lua
-- lua/nvim-cci/auth.lua
M.store(token)     -- saves to keyring
M.retrieve()       -- returns token string or nil
M.delete()         -- removes from keyring
M.is_authenticated() -- returns bool
```

**Keyring key:** `service = "nvim-cci"`, `account = "circleci_token"`

**Fallback:** If keyring is unavailable, fall back to `~/.config/nvim-cci/token` (warn the user that file-based storage is less secure).

---

## Implementation Tasks

- [ ] Write `lua/nvim-cci/auth.lua` with `store`, `retrieve`, `delete`, `is_authenticated`
- [ ] Implement keyring backend: detect OS, call `secret-tool` / `security` via `vim.fn.jobstart`
- [ ] Implement file-based fallback at `~/.config/nvim-cci/token` with a security warning
- [ ] Implement `:CCILogin` — open browser to CircleCI token settings page, prompt for token, store it
- [ ] Implement `:CCILogout` — delete token from keyring, confirm to user
- [ ] On `setup()`, call `auth.retrieve()` and notify if missing
- [ ] Handle 401 API responses → notify user to re-login (hook into Phase 3 API client)
- [ ] Write `tests/spec/auth_spec.lua` — mock keyring calls, test store/retrieve/delete/fallback logic

---

## Out of Scope

- Full programmatic OAuth redirect (requires local HTTP server)
- Multi-account / multi-token support
- Token rotation / expiry detection beyond 401 handling

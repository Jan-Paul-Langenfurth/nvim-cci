# PRD — Phase 3: CircleCI API Client

## Goal
Build an async HTTP client that wraps the CircleCI v2 API, covering all endpoints needed by the UI and actions phases.

---

## Acceptance Criteria

- **Given** a valid token, **when** `api.get_pipelines(slug, cb)` is called, **then** it calls `cb(nil, pipelines)` with a list of pipeline objects.
- **Given** an invalid token, **when** any API function is called, **then** it calls `cb("401: Unauthorized", nil)` and does not crash.
- **Given** a network error, **when** any API function is called, **then** it calls `cb(err_string, nil)` with a descriptive error.
- **Given** a pipeline id, **when** `api.get_workflows(pipeline_id, cb)` is called, **then** it returns the workflows for that pipeline.
- **Given** a workflow id, **when** `api.get_jobs(workflow_id, cb)` is called, **then** it returns the jobs for that workflow.
- **Given** a running workflow id, **when** `api.cancel_workflow(workflow_id, cb)` is called, **then** it calls the cancel endpoint and returns success/error.
- **Given** a failed workflow id, **when** `api.rerun_workflow(workflow_id, cb)` is called, **then** it calls the rerun endpoint.
- **Given** an approval request id, **when** `api.approve_job(approval_request_id, cb)` is called, **then** it calls the approval endpoint.
- **Given** a git remote URL (`git@github.com:org/repo.git` or `https://github.com/org/repo`), **when** `api.slug_from_remote(url)` is called, **then** it returns `"github/org/repo"`.

---

## Technical Design Notes

**Base URL:** `https://circleci.com/api/v2`

**Auth header:** `Circle-Token: <token>`

**HTTP via plenary:**
```lua
local curl = require('plenary.curl')
curl.get(url, {
  headers = { ['Circle-Token'] = auth.retrieve() },
  callback = function(res) ... end,
})
```

**API surface (`lua/nvim-cci/api.lua`):**
```lua
M.get_pipelines(project_slug, cb)       -- GET /project/{slug}/pipeline
M.get_workflows(pipeline_id, cb)        -- GET /pipeline/{id}/workflow
M.get_jobs(workflow_id, cb)             -- GET /workflow/{id}/job
M.cancel_workflow(workflow_id, cb)      -- POST /workflow/{id}/cancel
M.rerun_workflow(workflow_id, cb)       -- POST /workflow/{id}/rerun
M.approve_job(approval_request_id, cb)  -- POST /workflow/approval/{id}
M.slug_from_remote(remote_url)          -- pure function, returns slug string or nil
```

All callbacks follow `cb(err, data)` — `err` is nil on success, `data` is nil on error.

**Slug detection:**
```lua
-- Handles both SSH and HTTPS remotes
-- git@github.com:org/repo.git  -> github/org/repo
-- https://github.com/org/repo  -> github/org/repo
```
Uses `vim.fn.system('git remote get-url origin')` to fetch the remote.

**Pagination:** CircleCI v2 returns a `next_page_token`. For the initial implementation, fetch only the first page (20 items). Add pagination in a future iteration.

---

## Implementation Tasks

- [ ] Write `lua/nvim-cci/api.lua` with all functions listed above
- [ ] Implement `slug_from_remote` — parse both SSH and HTTPS git remote formats
- [ ] Implement `get_pipelines` with `plenary.curl`, JSON decode response
- [ ] Implement `get_workflows` and `get_jobs`
- [ ] Implement `cancel_workflow`, `rerun_workflow`, `approve_job` (POST endpoints)
- [ ] Centralise error handling — surface 401 to auth module, format other errors
- [ ] Write `tests/spec/api_spec.lua` — mock `plenary.curl`, test each function with fixture JSON responses
- [ ] Write `tests/spec/slug_spec.lua` — test slug parsing for SSH, HTTPS, trailing slash, `.git` suffix variants

---

## Out of Scope

- Pagination beyond the first page
- Triggering new pipelines
- Fetching raw job logs
- Caching API responses

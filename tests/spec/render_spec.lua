-- Minimal vim stub for running outside Neovim
if not vim then
  _G.vim = {
    fn  = {},
    api = {
      nvim_set_hl              = function() end,
      nvim_buf_set_lines       = function() end,
      nvim_buf_add_highlight   = function() end,
      nvim_buf_clear_namespace = function() end,
      nvim_create_namespace    = function() return 0 end,
    },
    bo      = setmetatable({}, { __newindex = function() end }),
    trim    = function(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end,
    notify  = function() end,
    log     = { levels = { INFO = 2, WARN = 3, ERROR = 4 } },
  }
end

local render = require('nvim-cci.ui.render')

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function make_state(overrides)
  local base = {
    pipelines = {},
    expanded  = {},
    workflows = {},
    jobs      = {},
    loading   = false,
  }
  if overrides then
    for k, v in pairs(overrides) do base[k] = v end
  end
  return base
end

local function pipeline(id, status, branch, created_at)
  return {
    id         = id,
    state      = status,
    created_at = created_at or '2020-01-01T00:00:00Z',
    vcs        = { branch = branch or 'main' },
  }
end

local function workflow(id, name, status)
  return { id = id, name = name, status = status }
end

local function job(id, name, status)
  return { id = id, name = name, status = status }
end

-- ── Tests: status icons ───────────────────────────────────────────────────────

describe('render.status_icon()', function()
  it('returns ✓ for success', function()
    assert.equals('✓', render.status_icon('success'))
  end)
  it('returns ✗ for failed', function()
    assert.equals('✗', render.status_icon('failed'))
  end)
  it('returns ✗ for error', function()
    assert.equals('✗', render.status_icon('error'))
  end)
  it('returns ⧗ for running', function()
    assert.equals('⧗', render.status_icon('running'))
  end)
  it('returns ⏸ for on_hold', function()
    assert.equals('⏸', render.status_icon('on_hold'))
  end)
  it('returns ○ for canceled', function()
    assert.equals('○', render.status_icon('canceled'))
  end)
  it('returns ? for unknown status', function()
    assert.equals('?', render.status_icon('bogus'))
  end)
end)

-- ── Tests: status highlight groups ───────────────────────────────────────────

describe('render.status_hl()', function()
  it('returns CCIStatusPassed for success', function()
    assert.equals('CCIStatusPassed', render.status_hl('success'))
  end)
  it('returns CCIStatusFailed for failed', function()
    assert.equals('CCIStatusFailed', render.status_hl('failed'))
  end)
  it('returns CCIStatusRunning for running', function()
    assert.equals('CCIStatusRunning', render.status_hl('running'))
  end)
  it('returns CCIStatusOnHold for on_hold', function()
    assert.equals('CCIStatusOnHold', render.status_hl('on_hold'))
  end)
  it('returns nil for unknown', function()
    assert.is_nil(render.status_hl('bogus'))
  end)
end)

-- ── Tests: loading state ──────────────────────────────────────────────────────

describe('render.build_lines() — loading', function()
  it('shows Loading… when state.loading is true', function()
    local lines = render.build_lines(make_state({ loading = true }))
    assert.equals(4, #lines)  -- 1 loading + 3 legend
    assert.truthy(lines[1]:find('Loading'))
  end)
end)

-- ── Tests: empty state ────────────────────────────────────────────────────────

describe('render.build_lines() — empty', function()
  it('shows "No pipelines found" when pipelines list is empty', function()
    local lines = render.build_lines(make_state())
    assert.equals(4, #lines)  -- 1 empty + 3 legend
    assert.truthy(lines[1]:find('No pipelines'))
  end)
end)

-- ── Tests: pipeline rows ──────────────────────────────────────────────────────

describe('render.build_lines() — pipelines', function()
  it('renders one line per pipeline', function()
    local lines = render.build_lines(make_state({
      pipelines = {
        pipeline('p1', 'success', 'main'),
        pipeline('p2', 'running', 'feat/foo'),
      },
    }))
    assert.equals(5, #lines)  -- 2 pipelines + 3 legend
  end)

  it('includes the branch name in the line', function()
    local lines = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'success', 'my-branch') },
    }))
    assert.truthy(lines[1]:find('my%-branch'))
  end)

  it('includes the status icon in the line', function()
    local lines = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'failed', 'main') },
    }))
    assert.truthy(lines[1]:find('✗'))
  end)

  it('returns a highlight entry for a pipeline with known status', function()
    local _, highlights = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
    }))
    -- first highlight is the pipeline status; legend highlights follow
    assert.equals('CCIStatusPassed', highlights[1].hl_group)
  end)

  it('produces no pipeline status highlight entry for an unknown status', function()
    local _, highlights = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'bogus', 'main') },
    }))
    -- only legend highlights present; none should be CCIStatus*
    for _, h in ipairs(highlights) do
      assert.is_nil(h.hl_group:find('^CCIStatus'),
        'unexpected pipeline status highlight: ' .. h.hl_group)
    end
  end)
end)

-- ── Tests: line metadata ──────────────────────────────────────────────────────

describe('render.build_lines() — line_meta', function()
  it('marks pipeline rows with type="pipeline"', function()
    local _, _, meta = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
    }))
    assert.equals('pipeline', meta[1].type)
    assert.equals('p1', meta[1].id)
  end)
end)

-- ── Tests: expand/collapse ────────────────────────────────────────────────────

describe('render.build_lines() — expand/collapse', function()
  it('shows no extra lines when pipeline is collapsed', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
    })
    -- expanded is empty — pipeline is collapsed
    local lines = render.build_lines(s)
    assert.equals(4, #lines)  -- 1 pipeline + 3 legend
  end)

  it('shows workflow lines when pipeline is expanded', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
      jobs      = {},
    })
    local lines = render.build_lines(s)
    -- 1 pipeline + 1 workflow + 3 legend
    assert.equals(5, #lines)
    assert.truthy(lines[2]:find('build'))
  end)

  it('shows loading placeholder when workflows are not yet fetched', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
    })
    local lines = render.build_lines(s)
    assert.equals(5, #lines)  -- 1 pipeline + 1 placeholder + 3 legend
    assert.truthy(lines[2]:find('loading'))
  end)

  it('shows job lines indented under workflow when jobs are loaded', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
      jobs      = { ['w1'] = { job('j1', 'test', 'success'), job('j2', 'deploy', 'failed') } },
    })
    local lines = render.build_lines(s)
    -- 1 pipeline + 1 workflow + 2 jobs + 3 legend
    assert.equals(7, #lines)
    assert.truthy(lines[3]:find('test'))
    assert.truthy(lines[4]:find('deploy'))
  end)

  it('marks workflow rows with type="workflow" in meta', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
    })
    local _, _, meta = render.build_lines(s)
    assert.equals('workflow', meta[2].type)
    assert.equals('w1', meta[2].id)
    assert.equals('p1', meta[2].pipeline_id)
  end)

  it('marks job rows with type="job" in meta', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
      jobs      = { ['w1'] = { job('j1', 'test', 'success') } },
    })
    local _, _, meta = render.build_lines(s)
    assert.equals('job', meta[3].type)
    assert.equals('j1', meta[3].id)
  end)

  it('collapses correctly — removes workflow/job lines', function()
    -- First build expanded
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
      expanded  = { p1 = true },
      workflows = { ['p1'] = { workflow('w1', 'build', 'success') } },
    })
    local expanded_lines = render.build_lines(s)
    assert.equals(5, #expanded_lines)  -- 1 pipeline + 1 workflow + 3 legend

    -- Collapse
    s.expanded['p1'] = nil
    local collapsed_lines = render.build_lines(s)
    assert.equals(4, #collapsed_lines)  -- 1 pipeline + 3 legend
  end)
end)

-- ── Tests: branch filter header ──────────────────────────────────────────────

describe('render.build_lines() — branch_filter header', function()
  it('emits a [branch: ...] header line when branch_filter is set', function()
    local s = make_state({
      branch_filter = 'feat/my-branch',
      pipelines     = { pipeline('p1', 'success', 'feat/my-branch') },
    })
    local lines = render.build_lines(s)
    -- first line is the header, second is the pipeline row, then 3 legend
    assert.equals(5, #lines)
    assert.truthy(lines[1]:find('%[branch: feat/my%-branch%]'))
  end)

  it('emits no header line when branch_filter is nil', function()
    local s = make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
    })
    local lines = render.build_lines(s)
    assert.equals(4, #lines)  -- 1 pipeline + 3 legend
    assert.is_nil(lines[1]:find('%[branch:'))
  end)

  it('header appears before pipelines and before loading message', function()
    local s = make_state({ branch_filter = 'main', loading = true })
    local lines = render.build_lines(s)
    assert.equals(5, #lines)  -- 1 branch header + 1 loading + 3 legend
    assert.truthy(lines[1]:find('%[branch:'))
    assert.truthy(lines[2]:find('Loading'))
  end)
end)

-- ── Tests: keybinding legend ─────────────────────────────────────────────────

describe('render.build_lines() — legend', function()
  local function legend_lines(lines)
    -- return only lines whose text contains '─' or known legend content
    local result = {}
    for _, l in ipairs(lines) do
      if l:find('─') or l:find('expand') or l:find('approve') then
        result[#result + 1] = l
      end
    end
    return result
  end

  it('appends separator + 2 legend rows in empty state', function()
    local lines = render.build_lines(make_state())
    -- last 3 lines: separator + 2 legend rows
    local n = #lines
    assert.is_true(n >= 3)
    assert.truthy(lines[n - 2]:find('─'))
    assert.truthy(lines[n - 1]:find('expand'))
    assert.truthy(lines[n]:find('approve'))
  end)

  it('appends separator + 2 legend rows in loading state', function()
    local lines = render.build_lines(make_state({ loading = true }))
    local n = #lines
    assert.is_true(n >= 3)
    assert.truthy(lines[n - 2]:find('─'))
    assert.truthy(lines[n - 1]:find('expand'))
    assert.truthy(lines[n]:find('approve'))
  end)

  it('appends legend even when pipelines are present', function()
    local lines = render.build_lines(make_state({
      pipelines = { pipeline('p1', 'success', 'main') },
    }))
    local n = #lines
    assert.truthy(lines[n]:find('approve'))
  end)

  it('legend lines carry type="help" in line_meta', function()
    local lines, _, meta = render.build_lines(make_state())
    local n = #lines
    assert.equals('help', meta[n - 2].type)
    assert.equals('help', meta[n - 1].type)
    assert.equals('help', meta[n].type)
  end)

  it('legend text contains all bound keys', function()
    local lines = render.build_lines(make_state())
    local legend_text = table.concat(lines, '\n')
    for _, key in ipairs({ '<CR>', 'r', 'f', 'a', 'x', 'R', 'q' }) do
      assert.truthy(legend_text:find(key, 1, true),
        'expected key "' .. key .. '" in legend')
    end
  end)

  it('each legend line fits within 50 characters', function()
    local lines = render.build_lines(make_state())
    local n = #lines
    for i = n - 1, n do
      assert.is_true(#lines[i] <= 50,
        'legend line too long: ' .. #lines[i] .. ' chars: ' .. lines[i])
    end
  end)
end)

-- ── Tests: time_ago (basic smoke) ────────────────────────────────────────────

describe('render.time_ago()', function()
  it('returns ? for nil', function()
    assert.equals('?', render.time_ago(nil))
  end)
  it('returns ? for empty string', function()
    assert.equals('?', render.time_ago(''))
  end)
  it('returns ? for invalid format', function()
    assert.equals('?', render.time_ago('not-a-date'))
  end)
  it('returns a relative string for a valid timestamp', function()
    -- Use a timestamp from 1 hour ago (approximate, timezone offset may apply)
    local ts = os.date('!%Y-%m-%dT%H:%M:%SZ', os.time() - 3600)
    local result = render.time_ago(ts)
    -- Should be something like "1h ago" or "59m ago" or "61m ago" depending on offset
    assert.truthy(result:find('ago'))
  end)
end)

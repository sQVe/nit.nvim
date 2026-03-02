# Reactor usernames popup proposal

**Task:** nit.nvim-xw7.1
**Goal:** Show reactor usernames in popup when pressing key on reaction summary line (e.g., `👍 2  ❤️ 1`)

## Research findings

### 1. Current data retention

`normalize_reaction_groups()` in `lua/nit/api/util.lua:138-151` retains:
- `content` (reaction type)
- `count` (totalCount)
- `viewer_has_reacted`

**Does NOT retain reactor usernames.**

### 2. GraphQL query gap

Current query in `lua/nit/api/comments.lua:36-40`:

```graphql
reactionGroups {
  content
  viewerHasReacted
  reactors { totalCount }
}
```

To get usernames, expand to:

```graphql
reactionGroups {
  content
  viewerHasReacted
  reactors(first: 10) {
    totalCount
    nodes {
      ... on User { login }
      ... on Bot { login }
      ... on Mannequin { login }
    }
  }
}
```

### 3. Reaction line detection

`format_thread()` returns `reaction_line_indices: table<integer, boolean>` mapping line numbers to `viewer_has_reacted`. This identifies which buffer lines are reaction summary lines.

Comment mapping via `current_ranges` and `M._find_comment_at_line(line, ranges)` links cursor line → comment index.

### 4. Popup pattern

`help_popup.lua` pattern:
- `nui.Popup` with `position = '50%'`, `relative = 'editor'`
- Module state: `active_popup` variable
- Functions: `show(data)`, `close()`, `is_open()`, `toggle(data)`
- Key mappings: `q`, `Esc` to close

## Implementation plan

### Step 1: Expand GraphQL query

**File:** `lua/nit/api/comments.lua`

Change lines 36-40 from:

```graphql
reactionGroups {
  content
  viewerHasReacted
  reactors { totalCount }
}
```

To:

```graphql
reactionGroups {
  content
  viewerHasReacted
  reactors(first: 10) {
    totalCount
    nodes {
      ... on User { login }
      ... on Bot { login }
      ... on Mannequin { login }
    }
  }
}
```

### Step 2: Update normalize_reaction_groups

**File:** `lua/nit/api/util.lua`

Extend to extract reactor logins:

```lua
function M.normalize_reaction_groups(reaction_groups)
  if not reaction_groups then
    return {}
  end
  local result = {}
  for _, rg in ipairs(reaction_groups) do
    local reactors = {}
    if rg.reactors and rg.reactors.nodes then
      for _, node in ipairs(rg.reactors.nodes) do
        if node.login then
          reactors[#reactors + 1] = node.login
        end
      end
    end
    result[#result + 1] = {
      content = rg.content,
      count = rg.reactors and rg.reactors.totalCount or 0,
      viewer_has_reacted = rg.viewerHasReacted == true,
      reactors = reactors,
    }
  end
  return result
end
```

### Step 3: Update types

**File:** `lua/nit/api/types.lua`

Add `reactors` field to `Nit.Api.ReactionGroup`:

```lua
---@field reactors string[] First 10 reactor logins
```

### Step 4: Create reactor popup module

**File:** `lua/nit/display/reactor_popup.lua`

New module following `help_popup.lua` pattern:

```lua
---Reactor popup for showing who reacted
---@class Nit.Display.ReactorPopup
local M = {}

local Popup = require('nui.popup')

---@type any?
local active_popup = nil

---@type table<string, string>
local REACTION_EMOJI = {
  THUMBS_UP = '👍',
  THUMBS_DOWN = '👎',
  LAUGH = '😄',
  HOORAY = '🎉',
  CONFUSED = '😕',
  HEART = '❤️',
  ROCKET = '🚀',
  EYES = '👀',
}

---@param reactions Nit.Api.ReactionGroup[]
---@return string[]
function M.format_lines(reactions)
  local lines = {}
  for _, rg in ipairs(reactions) do
    if rg.count > 0 then
      local emoji = REACTION_EMOJI[rg.content] or rg.content
      local names = table.concat(rg.reactors, ', ')
      if rg.count > #rg.reactors then
        names = names .. ' +' .. (rg.count - #rg.reactors) .. ' more'
      end
      table.insert(lines, '  ' .. emoji .. '  ' .. names)
    end
  end
  return lines
end

function M.show(reactions)
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end

  local lines = M.format_lines(reactions)
  if #lines == 0 then
    return
  end

  local width = 40
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
  end

  local popup = Popup({
    position = '50%',
    size = { width = width, height = #lines },
    relative = 'editor',
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = { top = ' Reactions ', top_align = 'center' },
    },
    buf_options = { modifiable = true },
  })

  popup:mount()
  pcall(vim.api.nvim_buf_set_lines, popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  popup:map('n', 'q', function() M.close() end, { noremap = true })
  popup:map('n', '<Esc>', function() M.close() end, { noremap = true })

  active_popup = popup
end

function M.close()
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end
end

function M.is_open()
  return active_popup ~= nil
end

return M
```

### Step 5: Add keybinding in thread_panel

**File:** `lua/nit/display/thread_panel.lua`

1. Add module-level variable near line 60 (after `current_ranges`):

```lua
---@type table<integer, boolean>
local current_reaction_lines = {}
```

2. Update `current_reaction_lines` in `update()` after `format_thread()` returns (around line 769):

```lua
local lines, author_indices, ranges, reaction_line_indices = M.format_thread(thread)
current_ranges = ranges
current_reaction_lines = reaction_line_indices  -- ADD THIS LINE
```

3. Add `<CR>` mapping in `show()` (around line 646, after other panel mappings):

```lua
local reactor_popup = require('nit.display.reactor_popup')

panel:map('n', '<CR>', function()
  local cursor = vim.api.nvim_win_get_cursor(panel.winid)
  local line = cursor[1]
  if current_reaction_lines[line] ~= nil then
    local comment_idx = M._find_comment_at_line(line, current_ranges)
    if comment_idx and current_thread then
      local comment = current_thread.comments[comment_idx]
      if comment and comment.reactions then
        reactor_popup.show(comment.reactions)
      end
    end
  end
end, { noremap = true })
```

4. Add hint to registry:

```lua
{ key = 'CR', label = 'Show reactors (on reaction line)' }
```

## Files changed

1. `lua/nit/api/comments.lua` - Expand GraphQL query
2. `lua/nit/api/util.lua` - Extract reactor logins in normalize
3. `lua/nit/api/types.lua` - Add reactors field to type
4. `lua/nit/display/reactor_popup.lua` - New popup module
5. `lua/nit/display/thread_panel.lua` - Add CR keybinding, track reaction lines

## Anti-patterns avoided

- **NO new API call at popup time** - Data fetched upfront in existing query
- **NO modifying reaction summary line format** - Popup shows details separately
- **Uses existing nui popup pattern** - Matches help_popup.lua structure

## Testing strategy

### Unit tests

**File:** `tests/api/util_spec.lua`

Add tests for `normalize_reaction_groups()` extracting reactors:

```lua
describe('normalize_reaction_groups', function()
  it('extracts reactor logins from nodes', function()
    local input = {
      {
        content = 'THUMBS_UP',
        viewerHasReacted = false,
        reactors = {
          totalCount = 2,
          nodes = { { login = 'alice' }, { login = 'bob' } },
        },
      },
    }
    local result = util.normalize_reaction_groups(input)
    assert.are.same({ 'alice', 'bob' }, result[1].reactors)
  end)

  it('handles missing reactors.nodes gracefully', function()
    local input = {
      { content = 'HEART', viewerHasReacted = true, reactors = { totalCount = 1 } },
    }
    local result = util.normalize_reaction_groups(input)
    assert.are.same({}, result[1].reactors)
  end)
end)
```

**File:** `tests/display/reactor_popup_spec.lua` (new)

```lua
describe('reactor_popup', function()
  local reactor_popup = require('nit.display.reactor_popup')

  describe('format_lines', function()
    it('formats reactions with usernames', function()
      local reactions = {
        { content = 'THUMBS_UP', count = 2, reactors = { 'alice', 'bob' } },
      }
      local lines = reactor_popup.format_lines(reactions)
      assert.are.equal(1, #lines)
      assert.is_true(lines[1]:find('alice') ~= nil)
      assert.is_true(lines[1]:find('bob') ~= nil)
    end)

    it('shows +N more when count exceeds reactors', function()
      local reactions = {
        { content = 'HEART', count = 15, reactors = { 'alice', 'bob' } },
      }
      local lines = reactor_popup.format_lines(reactions)
      assert.is_true(lines[1]:find('%+13 more') ~= nil)
    end)

    it('skips reactions with zero count', function()
      local reactions = {
        { content = 'THUMBS_UP', count = 0, reactors = {} },
      }
      local lines = reactor_popup.format_lines(reactions)
      assert.are.equal(0, #lines)
    end)
  end)
end)
```

### Integration tests

**File:** `tests/display/thread_panel_spec.lua`

Add test for CR keybinding behavior:

```lua
describe('CR keybinding', function()
  it('opens reactor popup when cursor on reaction line', function()
    -- Setup: render thread with reactions
    -- Move cursor to reaction line
    -- Press CR
    -- Assert reactor_popup.is_open() == true
  end)

  it('does nothing when cursor not on reaction line', function()
    -- Setup: render thread with reactions
    -- Move cursor to author line
    -- Press CR
    -- Assert reactor_popup.is_open() == false
  end)
end)
```

## Review: CHANGES NEEDED

**Reviewer:** worker-2
**Date:** 2026-03-02

### File paths and line numbers
✅ All cited paths exist and line numbers are accurate.

### Pattern observations
✅ All correct. GraphQL query structure, `normalize_reaction_groups` behavior, `reaction_line_indices` return, and `help_popup.lua` pattern verified.

### Feasibility issues

1. **`REACTION_EMOJI` access bug (Step 4, line 157)**

   `REACTION_EMOJI` is declared as `local` in `thread_panel.lua:35`:
   ```lua
   local REACTION_EMOJI = {
   ```

   The proposal's `reactor_popup.lua` references it as:
   ```lua
   local emoji = require('nit.display.thread_panel').REACTION_EMOJI[rg.content]
   ```

   This will fail at runtime (`nil` access).

   **Fix options:**
   - Export from thread_panel: `M.REACTION_EMOJI = REACTION_EMOJI`
   - Define locally in reactor_popup.lua (duplicates data but decouples modules)
   - Extract to shared constants module

   ✅ **ADDRESSED:** Defined `REACTION_EMOJI` locally in `reactor_popup.lua` (decouples modules, avoids cross-module dependency).

2. **Missing module variable (Step 5)**

   Proposal says "Track `reaction_line_indices` as module-level variable" but doesn't show adding:
   ```lua
   local current_reaction_lines = {}
   ```

   Nor updating it in `update()` after `format_thread()` returns.

   ✅ **ADDRESSED:** Step 5 now shows explicit variable declaration and update in `update()`.

### Testing strategy
❌ **Missing entirely.** No tests specified.

Recommended tests:
- `normalize_reaction_groups()` extracting `reactors` field from GraphQL response
- `reactor_popup.format_lines()` with various reaction counts
- `reactor_popup.format_lines()` "+N more" overflow when count > #reactors
- CR keybinding invokes popup on reaction line (not on other lines)

✅ **ADDRESSED:** Testing strategy section added with unit tests for `normalize_reaction_groups()`, `reactor_popup.format_lines()`, and integration tests for CR keybinding.

---

## Quick Plan Complete

**Proposal:** `docs/proposals/2026-03-02-quick-plan-proposal.md`

**Epic:** `nit.nvim-hpd` — Reactor usernames popup

### Tasks

| ID | Title | Status |
|----|-------|--------|
| nit.nvim-hpd.1 | Expand GraphQL query to fetch reactor usernames | open |
| nit.nvim-hpd.2 | Update normalize_reaction_groups to extract reactor logins | open |
| nit.nvim-hpd.3 | Add reactors field to Nit.Api.ReactionGroup type | open |
| nit.nvim-hpd.4 | Create reactor_popup.lua display module | open |
| nit.nvim-hpd.5 | Add CR keybinding and reaction line tracking in thread_panel | open |

### Dependency chain

```
nit.nvim-hpd (epic)
├── .1 GraphQL query expansion
├── .2 normalize_reaction_groups update
├── .3 Type annotation
├── .4 reactor_popup.lua module
└── .5 CR keybinding in thread_panel
```

Tasks .1-.3 modify data layer (can be done together).
Task .4 creates display module (depends on .3 for types).
Task .5 wires keybinding (depends on .4 for popup).

**Suggested order:** .1 → .2 → .3 → .4 → .5

### Next steps for implementation

1. Run `br update nit.nvim-hpd --status=in_progress` to start the epic
2. Begin with task .1 (GraphQL query) — foundation for data
3. Use TDD: write tests first, then implement
4. Run `make ci` after each task to verify no regressions
5. Commit after each task with `feat(reactions):` prefix

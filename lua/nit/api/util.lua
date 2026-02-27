---@class Nit.Api.Util
local M = {}

local tracker = require('nit.api.tracker')

---Normalize vim.NIL to nil
---@param value any
---@return any
function M.nil_if_vim_nil(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---Get owner and repo from git remote asynchronously
---@param callback fun(owner: string?, repo: string?)
---@return fun() cancel Cancel function
function M.get_repo_info(callback)
  local completed = false
  local request_id = nil

  local process = vim.system(
    { 'git', 'remote', 'get-url', 'origin' },
    { text = true },
    vim.schedule_wrap(function(result)
      if completed then
        return
      end
      completed = true
      if request_id then
        tracker.untrack(request_id)
      end

      if result.code ~= 0 then
        callback(nil, nil)
        return
      end

      local stdout = result.stdout or ''
      local owner, repo = stdout:match('github%.com[:/]([^/]+)/([^%s]+)')
      if owner and repo then
        callback(owner, repo:gsub('%.git$', ''):gsub('/$', ''))
      else
        callback(nil, nil)
      end
    end)
  )

  local cancel = function()
    if completed then
      return
    end
    completed = true
    if request_id then
      tracker.untrack(request_id)
    end
    if process then
      process:kill(9)
    end
  end

  request_id = tracker.track(cancel)

  return cancel
end

---Resolve repo info and PR number, then call inner function.
---Handles cancellation, repo resolution, and PR number detection.
---@param opts? Nit.Api.RequestOpts|{ number?: Nit.Api.PrNumber }
---@param inner fun(owner: string, repo: string, pr_number: integer, request_opts: Nit.Api.RequestOpts): fun()? Inner function returning optional cancel
---@param on_error fun(result: Nit.Api.Result)
---@return fun() cancel
function M.with_pr_context(opts, inner, on_error)
  opts = opts or {}

  local cancel_repo = nil
  local cancel_inner = nil
  local cancelled = false

  local request_opts = {
    timeout = opts.timeout,
    retry = opts.retry,
  }

  cancel_repo = M.get_repo_info(function(owner, repo)
    if cancelled then
      return
    end

    if not owner or not repo then
      on_error({
        ok = false,
        error = 'Could not determine repository from git remote',
      })
      return
    end

    if opts.number then
      cancel_inner = inner(owner, repo, opts.number, request_opts)
      return
    end

    local gh = require('nit.api.gh')
    cancel_inner = gh.execute({ 'pr', 'view', '--json', 'number' }, request_opts, function(result)
      if not result.ok then
        on_error(result)
        return
      end

      local ok, pr_data = pcall(vim.json.decode, result.data)
      if not ok or not pr_data.number then
        on_error({
          ok = false,
          error = 'No PR found for current branch',
        })
        return
      end

      cancel_inner = inner(owner, repo, pr_data.number, request_opts)
    end)
  end)

  return function()
    cancelled = true
    if cancel_repo then
      cancel_repo()
    end
    if cancel_inner then
      cancel_inner()
    end
  end
end

---Normalize GraphQL reactionGroups to Nit.Api.ReactionGroup format
---@param reaction_groups table[]?
---@return Nit.Api.ReactionGroup[]
function M.normalize_reaction_groups(reaction_groups)
  if not reaction_groups then
    return {}
  end
  local result = {}
  for _, rg in ipairs(reaction_groups) do
    result[#result + 1] = {
      content = rg.content,
      count = rg.reactors and rg.reactors.totalCount or 0,
      viewer_has_reacted = rg.viewerHasReacted or false,
    }
  end
  return result
end

return M

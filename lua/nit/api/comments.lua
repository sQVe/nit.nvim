local gh = require('nit.api.gh')
local tracker = require('nit.api.tracker')

local M = {}

---Normalize vim.NIL to nil
---@param value any
---@return any
local function nil_if_vim_nil(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---Normalize GitHub comment to Nit.Api.Comment format
---@param raw_comment table Raw comment from GitHub API
---@return Nit.Api.Comment
local function normalize_comment(raw_comment)
  local user = raw_comment.user
  return {
    id = raw_comment.id,
    author = user and {
      login = user.login,
      name = nil_if_vim_nil(user.name),
    } or { login = 'unknown' },
    body = raw_comment.body,
    createdAt = raw_comment.created_at,
    path = raw_comment.path,
    line = raw_comment.line or raw_comment.original_line,
    side = raw_comment.side,
  }
end

---Group comments into threads based on in_reply_to_id
---@param comments table[] Raw comments from GitHub API
---@return Nit.Api.Thread[]
local function group_into_threads(comments)
  local comment_map = {}
  local threads = {}

  for _, raw_comment in ipairs(comments) do
    comment_map[raw_comment.id] = {
      raw = raw_comment,
      normalized = normalize_comment(raw_comment),
      replies = {},
    }
  end

  for _, raw_comment in ipairs(comments) do
    if raw_comment.in_reply_to_id then
      local parent = comment_map[raw_comment.in_reply_to_id]
      if parent then
        table.insert(parent.replies, comment_map[raw_comment.id])
      end
    else
      table.insert(threads, comment_map[raw_comment.id])
    end
  end

  local normalized_threads = {}
  for _, thread_root in ipairs(threads) do
    local thread_comments = { thread_root.normalized }

    local function collect_replies(node)
      for _, reply in ipairs(node.replies) do
        table.insert(thread_comments, reply.normalized)
        collect_replies(reply)
      end
    end
    collect_replies(thread_root)

    table.insert(normalized_threads, {
      id = thread_root.normalized.id,
      comments = thread_comments,
      isResolved = thread_root.raw.resolved or false,
      path = thread_root.normalized.path,
      line = thread_root.normalized.line,
      side = thread_root.normalized.side,
    })
  end

  table.sort(normalized_threads, function(a, b)
    local a_path = a.path or ''
    local b_path = b.path or ''
    if a_path ~= b_path then
      return a_path < b_path
    end
    return (a.line or 0) < (b.line or 0)
  end)

  return normalized_threads
end

---Get owner and repo from git remote asynchronously
---@param callback fun(owner: string|nil, repo: string|nil)
---@return fun() cancel Cancel function
local function get_repo_info(callback)
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

---Fetch PR comments organized into threads
---@param opts? Nit.Api.RequestOpts|{ number?: integer }
---@param callback fun(result: Nit.Api.Result<Nit.Api.Thread[]>)
---@return fun() cancel Cancel function
function M.fetch_comments(opts, callback)
  opts = opts or {}

  local cancel_repo = nil
  local cancel_inner = nil
  local cancelled = false

  local request_opts = {
    timeout = opts.timeout,
    retry = opts.retry,
  }

  cancel_repo = get_repo_info(function(owner, repo)
    if cancelled then
      return
    end

    if not owner or not repo then
      callback({
        ok = false,
        error = 'Could not determine repository from git remote',
      })
      return
    end

    local function fetch_with_pr_number(pr_number)
      local args = {
        'api',
        string.format('repos/%s/%s/pulls/%d/comments', owner, repo, pr_number),
        '--paginate',
      }

      return gh.execute(args, request_opts, function(result)
        if not result.ok then
          callback(result)
          return
        end

        local ok, comments = pcall(vim.json.decode, result.data)
        if not ok then
          callback({
            ok = false,
            error = 'Failed to parse comments JSON',
          })
          return
        end

        local threads = group_into_threads(comments)
        callback({
          ok = true,
          data = threads,
        })
      end)
    end

    if opts.number then
      cancel_inner = fetch_with_pr_number(opts.number)
      return
    end

    cancel_inner = gh.execute({ 'pr', 'view', '--json', 'number' }, request_opts, function(result)
      if not result.ok then
        callback(result)
        return
      end

      local ok, pr_data = pcall(vim.json.decode, result.data)
      if not ok or not pr_data.number then
        callback({
          ok = false,
          error = 'No PR found for current branch',
        })
        return
      end

      cancel_inner = fetch_with_pr_number(pr_data.number)
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

return M

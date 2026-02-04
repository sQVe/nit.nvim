local gh = require('nit.api.gh')

local M = {}

local FIELDS = 'number,title,state,author,body,createdAt,updatedAt,mergeable,isDraft'

---Normalize PR state from GitHub API format to plugin format
---@param state string
---@return 'open'|'closed'|'merged'
local function normalize_state(state)
  return state:lower()
end

---Normalize PR mergeable status from GitHub API format to plugin format
---@param mergeable string
---@return 'clean'|'dirty'|'unknown'
local function normalize_mergeable(mergeable)
  if mergeable == 'MERGEABLE' then
    return 'clean'
  elseif mergeable == 'CONFLICTING' then
    return 'dirty'
  else
    return 'unknown'
  end
end

---Normalize vim.NIL to nil
---@param value any
---@return any
local function nil_if_vim_nil(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---Normalize PR data from GitHub API format to plugin format
---@param data table
---@return Nit.Api.PR
local function normalize_pr(data)
  local author = nil_if_vim_nil(data.author)
  return {
    number = data.number,
    title = data.title,
    state = normalize_state(data.state),
    author = author and {
      login = author.login,
      name = nil_if_vim_nil(author.name),
    } or { login = 'unknown' },
    body = nil_if_vim_nil(data.body),
    createdAt = data.createdAt,
    updatedAt = data.updatedAt,
    mergeable = normalize_mergeable(nil_if_vim_nil(data.mergeable)),
    isDraft = data.isDraft,
  }
end

---@class Nit.Api.FetchPROpts : Nit.Api.RequestOpts
---@field number? integer PR number to fetch
---@field branch? string Branch name to fetch PR for

---Fetch PR metadata from GitHub
---@param opts Nit.Api.FetchPROpts Options
---@param callback fun(result: Nit.Api.Result) Callback function
---@return fun() cancel Cancel function
function M.fetch_pr(opts, callback)
  opts = opts or {}

  local args = { 'pr', 'view' }
  if opts.number then
    table.insert(args, tostring(opts.number))
  elseif opts.branch then
    table.insert(args, opts.branch)
  end
  vim.list_extend(args, { '--json', FIELDS })

  local request_opts = {
    timeout = opts.timeout,
    retry = opts.retry,
  }

  return gh.execute(args, request_opts, function(result)
    if not result.ok then
      callback(result)
      return
    end

    local ok, data = pcall(vim.json.decode, result.data)
    if not ok then
      callback({ ok = false, error = 'Could not parse PR data' })
      return
    end

    local normalized = normalize_pr(data)
    callback({ ok = true, data = normalized })
  end)
end

return M

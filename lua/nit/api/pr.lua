local gh = require('nit.api.gh')

local M = {}

local FIELDS =
  'number,title,state,author,body,createdAt,updatedAt,mergeable,isDraft,labels,assignees,reviewRequests,reviews,comments'

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

---Normalize labels array
---@param labels table[]?
---@return Nit.Api.Label[]
local function normalize_labels(labels)
  if not labels then
    return {}
  end
  local result = {}
  for _, label in ipairs(labels) do
    table.insert(result, {
      name = label.name,
      color = label.color,
      description = nil_if_vim_nil(label.description),
    })
  end
  return result
end

---Normalize assignees array
---@param assignees table[]?
---@return Nit.Api.User[]
local function normalize_assignees(assignees)
  if not assignees then
    return {}
  end
  local result = {}
  for _, assignee in ipairs(assignees) do
    table.insert(result, {
      login = assignee.login,
      name = nil_if_vim_nil(assignee.name),
    })
  end
  return result
end

---Normalize reviewRequests and reviews into unified reviewers array
---@param reviewRequests table[]?
---@param reviews table[]?
---@return Nit.Api.Reviewer[]
local function normalize_reviewers(reviewRequests, reviews)
  local result = {}
  if reviewRequests then
    for _, request in ipairs(reviewRequests) do
      table.insert(result, {
        login = request.login,
        state = 'PENDING',
      })
    end
  end
  if reviews then
    for _, review in ipairs(reviews) do
      local author = nil_if_vim_nil(review.author)
      if author then
        table.insert(result, {
          login = author.login,
          state = review.state,
        })
      end
    end
  end
  return result
end

---Normalize reactions array into emoji count map
---@param reactions table[]?
---@return Nit.Api.Reactions
local function normalize_reactions(reactions)
  if not reactions then
    return {}
  end
  local result = {}
  for _, reaction in ipairs(reactions) do
    local users = reaction.users or {}
    result[reaction.content] = #users
  end
  return result
end

---Normalize comments array
---@param comments table[]?
---@return Nit.Api.IssueComment[]
local function normalize_comments(comments)
  if not comments then
    return {}
  end
  local result = {}
  for _, comment in ipairs(comments) do
    local author = nil_if_vim_nil(comment.author)
    table.insert(result, {
      id = comment.id,
      author = author and {
        login = author.login,
        name = nil_if_vim_nil(author.name),
      } or { login = 'unknown' },
      body = comment.body,
      createdAt = comment.createdAt,
      reactions = normalize_reactions(comment.reactions),
    })
  end
  return result
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
    labels = normalize_labels(data.labels),
    assignees = normalize_assignees(data.assignees),
    reviewers = normalize_reviewers(data.reviewRequests, data.reviews),
    comments = normalize_comments(data.comments),
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

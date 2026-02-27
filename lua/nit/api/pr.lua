---@class Nit.Api.Pr
local M = {}

local gh = require('nit.api.gh')
local util = require('nit.api.util')

local nil_if_vim_nil = util.nil_if_vim_nil

local FIELDS =
  'number,title,state,author,body,createdAt,updatedAt,mergeable,isDraft,labels,assignees,reviewRequests,reviews,comments,headRefName,baseRefName'

---@type table<string, Nit.Api.PrState>
local PR_STATES = {
  open = 'open',
  closed = 'closed',
  merged = 'merged',
}

---Normalize PR state from GitHub API format to plugin format
---@param state Nit.Api.PrStateRaw
---@return Nit.Api.PrState
local function normalize_state(state)
  return PR_STATES[state:lower()] or 'open'
end

---Normalize PR mergeable status from GitHub API format to plugin format
---@param mergeable string
---@return Nit.Api.MergeableState
local function normalize_mergeable(mergeable)
  if mergeable == 'MERGEABLE' then
    return 'clean'
  elseif mergeable == 'CONFLICTING' then
    return 'dirty'
  else
    return 'unknown'
  end
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
  local seen = {}
  local result = {}

  if reviews then
    local sorted = vim.list_extend({}, reviews)
    table.sort(sorted, function(a, b)
      return (a.submittedAt or '') < (b.submittedAt or '')
    end)
    for _, review in ipairs(sorted) do
      local author = nil_if_vim_nil(review.author)
      if author then
        if seen[author.login] then
          for _, r in ipairs(result) do
            if r.login == author.login then
              r.state = review.state
              break
            end
          end
        else
          seen[author.login] = true
          table.insert(result, {
            login = author.login,
            state = review.state,
          })
        end
      end
    end
  end

  if reviewRequests then
    for _, request in ipairs(reviewRequests) do
      local login = nil_if_vim_nil(request.login)
      if login and not seen[login] then
        seen[login] = true
        table.insert(result, {
          login = login,
          state = 'PENDING',
        })
      end
    end
  end

  return result
end

---@param reactions table[]?
---@param viewer_login? string
---@return Nit.Api.ReactionGroup[]
local function normalize_reactions(reactions, viewer_login)
  if not reactions then
    return {}
  end
  local result = {}
  for _, reaction in ipairs(reactions) do
    local users = reaction.users or {}
    local viewer_has_reacted = false
    if viewer_login then
      for _, user in ipairs(users) do
        if user.login == viewer_login then
          viewer_has_reacted = true
          break
        end
      end
    end
    result[#result + 1] = {
      content = reaction.content,
      count = #users,
      viewer_has_reacted = viewer_has_reacted,
    }
  end
  return result
end

---Normalize issue comments and review body comments into a single sorted list
---@param comments table[]?
---@param reviews table[]?
---@return Nit.Api.IssueComment[]
local function normalize_comments(comments, reviews)
  local result = {}

  if comments then
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
  end

  if reviews then
    for _, review in ipairs(reviews) do
      local body = nil_if_vim_nil(review.body)
      if body and body ~= '' then
        local author = nil_if_vim_nil(review.author)
        table.insert(result, {
          id = review.id,
          author = author and {
            login = author.login,
            name = nil_if_vim_nil(author.name),
          } or { login = 'unknown' },
          body = body,
          createdAt = review.submittedAt,
          reactions = {},
        })
      end
    end
  end

  table.sort(result, function(a, b)
    return (a.createdAt or '') < (b.createdAt or '')
  end)

  return result
end

---Normalize PR data from GitHub API format to plugin format
---@param data table
---@return Nit.Api.PR
local function normalize_pr(data)
  local author = nil_if_vim_nil(data.author)
  return {
    assignees = normalize_assignees(data.assignees),
    author = author and { login = author.login, name = nil_if_vim_nil(author.name) }
      or { login = 'unknown' },
    baseRefName = nil_if_vim_nil(data.baseRefName),
    body = nil_if_vim_nil(data.body),
    comments = normalize_comments(data.comments, data.reviews),
    createdAt = data.createdAt,
    headRefName = nil_if_vim_nil(data.headRefName),
    isDraft = data.isDraft,
    labels = normalize_labels(data.labels),
    mergeable = normalize_mergeable(nil_if_vim_nil(data.mergeable)),
    number = data.number,
    reviewers = normalize_reviewers(data.reviewRequests, data.reviews),
    state = normalize_state(data.state),
    title = data.title,
    updatedAt = data.updatedAt,
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

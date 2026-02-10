---@class Nit.Api.Comments
local M = {}

local gh = require('nit.api.gh')
local util = require('nit.api.util')

local nil_if_vim_nil = util.nil_if_vim_nil

local REVIEW_THREADS_QUERY = [[
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            diffSide
            comments(first: 100) {
              nodes {
                databaseId
                author { login }
                body
                createdAt
              }
            }
          }
        }
      }
    }
  }
]]

---Normalize GraphQL thread nodes to Nit.Api.Thread format
---@param thread_nodes table[]
---@return Nit.Api.Thread[]
local function normalize_threads(thread_nodes)
  local threads = {}

  for _, thread_node in ipairs(thread_nodes) do
    local comments = {}
    local comment_nodes = thread_node.comments and thread_node.comments.nodes or {}

    for _, comment_node in ipairs(comment_nodes) do
      local author = comment_node.author
      comments[#comments + 1] = {
        id = comment_node.databaseId,
        author = author and author.login and { login = author.login } or { login = 'unknown' },
        body = comment_node.body or '',
        createdAt = comment_node.createdAt or '',
        path = nil_if_vim_nil(thread_node.path),
        line = nil_if_vim_nil(thread_node.line),
        side = nil_if_vim_nil(thread_node.diffSide),
      }
    end

    threads[#threads + 1] = {
      id = thread_node.id,
      comments = comments,
      isResolved = thread_node.isResolved or false,
      path = nil_if_vim_nil(thread_node.path),
      line = nil_if_vim_nil(thread_node.line),
      side = nil_if_vim_nil(thread_node.diffSide),
    }
  end

  table.sort(threads, function(a, b)
    local a_path = a.path or ''
    local b_path = b.path or ''
    if a_path ~= b_path then
      return a_path < b_path
    end
    return (a.line or 0) < (b.line or 0)
  end)

  return threads
end

---Fetch PR review threads via GraphQL
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

  cancel_repo = util.get_repo_info(function(owner, repo)
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
        'graphql',
        '-f',
        'query=' .. REVIEW_THREADS_QUERY,
        '-f',
        'owner=' .. owner,
        '-f',
        'repo=' .. repo,
        '-F',
        'number=' .. tostring(pr_number),
      }

      return gh.execute(args, request_opts, function(result)
        if not result.ok then
          callback(result)
          return
        end

        local ok, data = pcall(vim.json.decode, result.data)
        if not ok then
          callback({
            ok = false,
            error = 'Failed to parse GraphQL response',
          })
          return
        end

        if data.errors then
          local msg = data.errors[1] and data.errors[1].message or 'GraphQL error'
          callback({ ok = false, error = msg })
          return
        end

        local pull_request = data.data and data.data.repository and data.data.repository.pullRequest
        if not pull_request then
          callback({ ok = false, error = 'Pull request not found' })
          return
        end

        local thread_nodes = pull_request.reviewThreads and pull_request.reviewThreads.nodes or {}
        local threads = normalize_threads(thread_nodes)
        callback({ ok = true, data = threads })
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

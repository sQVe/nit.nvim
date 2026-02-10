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
          pageInfo {
            hasNextPage
          }
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            diffSide
            startLine
            startDiffSide
            comments(first: 100) {
              pageInfo {
                hasNextPage
              }
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
        start_line = nil_if_vim_nil(thread_node.startLine),
        start_side = nil_if_vim_nil(thread_node.startDiffSide),
      }
    end

    threads[#threads + 1] = {
      id = thread_node.id,
      comments = comments,
      isResolved = thread_node.isResolved or false,
      isOutdated = thread_node.isOutdated or false,
      path = nil_if_vim_nil(thread_node.path),
      line = nil_if_vim_nil(thread_node.line),
      side = nil_if_vim_nil(thread_node.diffSide),
      start_line = nil_if_vim_nil(thread_node.startLine),
      start_side = nil_if_vim_nil(thread_node.startDiffSide),
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
---@param opts? Nit.Api.RequestOpts|{ number?: Nit.Api.PrNumber }
---@param callback fun(result: Nit.Api.Result<Nit.Api.Thread[]>)
---@return fun() cancel Cancel function
function M.fetch_comments(opts, callback)
  return util.with_pr_context(opts, function(owner, repo, pr_number, request_opts)
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
        callback({ ok = false, error = 'Failed to parse GraphQL response' })
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

      local review_threads = pull_request.reviewThreads
      local thread_nodes = review_threads and review_threads.nodes or {}

      local warnings = {}
      if review_threads and review_threads.pageInfo and review_threads.pageInfo.hasNextPage then
        table.insert(warnings, 'PR has more than 100 review threads; some may not be shown')
      end

      local comments_truncated = false
      for _, thread in ipairs(thread_nodes) do
        if
          thread.comments
          and thread.comments.pageInfo
          and thread.comments.pageInfo.hasNextPage
        then
          comments_truncated = true
          break
        end
      end

      if comments_truncated then
        table.insert(
          warnings,
          'Some review threads have more than 100 comments; some may not be shown'
        )
      end

      if #warnings > 0 then
        vim.schedule(function()
          for _, msg in ipairs(warnings) do
            vim.notify('[nit] ' .. msg, vim.log.levels.WARN)
          end
        end)
      end

      local threads = normalize_threads(thread_nodes)
      callback({ ok = true, data = threads })
    end)
  end, callback)
end

return M

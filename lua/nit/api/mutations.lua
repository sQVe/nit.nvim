---@class Nit.Api.Mutations
local M = {}

---@class Nit.Api.ValidReactionOpts
---@field node_id string
---@field content string

---@class Nit.Api.ValidReplyOpts
---@field thread_id string
---@field body string

---@class Nit.Api.ValidUpdateCommentOpts
---@field comment_id string
---@field body string

local gh = require('nit.api.gh')
local util = require('nit.api.util')

local nil_if_vim_nil = util.nil_if_vim_nil
local normalize_reaction_groups = util.normalize_reaction_groups

local REPLY_MUTATION = [[
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $threadId, body: $body }) {
      comment {
        databaseId
        author { login }
        body
        createdAt
      }
    }
  }
]]

local RESOLVE_MUTATION = [[
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread {
        id
        isResolved
      }
    }
  }
]]

local UNRESOLVE_MUTATION = [[
  mutation($threadId: ID!) {
    unresolveReviewThread(input: { threadId: $threadId }) {
      thread {
        id
        isResolved
      }
    }
  }
]]

local ADD_REACTION_MUTATION = [[
  mutation($subjectId: ID!, $content: ReactionContent!) {
    addReaction(input: { subjectId: $subjectId, content: $content }) {
      subject {
        ... on PullRequestReviewComment {
          reactionGroups {
            content
            viewerHasReacted
            reactors { totalCount }
          }
        }
      }
    }
  }
]]

local REMOVE_REACTION_MUTATION = [[
  mutation($subjectId: ID!, $content: ReactionContent!) {
    removeReaction(input: { subjectId: $subjectId, content: $content }) {
      subject {
        ... on PullRequestReviewComment {
          reactionGroups {
            content
            viewerHasReacted
            reactors { totalCount }
          }
        }
      }
    }
  }
]]

local UPDATE_COMMENT_MUTATION = [[
  mutation($commentId: ID!, $body: String!) {
    updatePullRequestReviewComment(input: { pullRequestReviewCommentId: $commentId, body: $body }) {
      pullRequestReviewComment {
        id
        databaseId
        author { login }
        body
        createdAt
      }
    }
  }
]]

local VALID_REACTION_CONTENTS = {
  THUMBS_UP = true,
  THUMBS_DOWN = true,
  LAUGH = true,
  HOORAY = true,
  CONFUSED = true,
  HEART = true,
  ROCKET = true,
  EYES = true,
}

---@param opts table
---@return Nit.Api.ValidReactionOpts?, string?
local function validate_reaction_opts(opts)
  if not opts.node_id or type(opts.node_id) ~= 'string' or opts.node_id == '' then
    return nil, 'node_id is required'
  end
  if not opts.content or not VALID_REACTION_CONTENTS[opts.content] then
    return nil, 'content must be a valid ReactionContent'
  end
  return { node_id = opts.node_id, content = opts.content }, nil
end

---Normalize GraphQL comment response to Nit.Api.Comment
---@param comment_node table
---@return Nit.Api.Comment
local function normalize_comment(comment_node)
  local author = nil_if_vim_nil(comment_node.author)
  return {
    id = comment_node.databaseId,
    node_id = nil_if_vim_nil(comment_node.id),
    author = author and author.login and { login = author.login } or { login = 'unknown' },
    body = nil_if_vim_nil(comment_node.body) or '',
    createdAt = nil_if_vim_nil(comment_node.createdAt) or '',
    path = nil,
    line = nil,
    side = nil,
    start_line = nil,
    start_side = nil,
    reactions = {},
  }
end

---Parse GraphQL response and extract mutation data
---@param result Nit.Api.Result
---@param mutation_key string
---@param callback fun(err: string?, data: any)
local function parse_graphql_response(result, mutation_key, callback)
  if not result.ok then
    callback(result.error, nil)
    return
  end

  local ok, data = pcall(vim.json.decode, result.data)
  if not ok then
    callback('Failed to parse GraphQL response', nil)
    return
  end

  if data.errors then
    local msg = data.errors[1] and data.errors[1].message or 'GraphQL error'
    callback(msg, nil)
    return
  end

  local mutation_data = data.data and data.data[mutation_key]
  if not mutation_data then
    callback('Mutation response missing data', nil)
    return
  end

  callback(nil, mutation_data)
end

---Validate thread_id is present, a string, and non-empty
---@param thread_id any
---@return string? error
local function validate_thread_id(thread_id)
  if thread_id == nil then
    return 'thread_id is required'
  end
  if type(thread_id) ~= 'string' then
    return 'thread_id must be a string'
  end
  if thread_id == '' then
    return 'thread_id cannot be empty'
  end
  return nil
end

---Validate and trim body text
---@param body any
---@return string?, string? error
local function validate_body(body)
  if body == nil then
    return nil, 'body is required'
  end
  if type(body) ~= 'string' then
    return nil, 'body must be a string'
  end

  local trimmed = body:match('^%s*(.-)%s*$')
  if trimmed == '' then
    return nil, 'body cannot be empty'
  end

  return trimmed, nil
end

---Validate reply options and trim body
---@param opts table
---@return Nit.Api.ValidReplyOpts?, string? error
local function validate_reply_opts(opts)
  local err = validate_thread_id(opts.thread_id)
  if err then
    return nil, err
  end

  local trimmed_body, body_err = validate_body(opts.body)
  if not trimmed_body then
    return nil, body_err
  end

  return { thread_id = opts.thread_id, body = trimmed_body }, nil
end

---Submit a reply to a review thread
---@param opts Nit.Api.RequestOpts|Nit.Api.ValidReplyOpts
---@param callback fun(result: Nit.Api.Result<Nit.Api.Comment>)
---@return fun() cancel Cancel function
function M.reply_to_thread(opts, callback)
  local validated, err = validate_reply_opts(opts)
  if not validated then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. REPLY_MUTATION,
    '-f',
    'threadId=' .. validated.thread_id,
    '-f',
    'body=' .. validated.body,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'addPullRequestReviewThreadReply', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      if not data.comment then
        callback({ ok = false, error = 'Comment not found in response' })
        return
      end

      local normalized = normalize_comment(data.comment)
      callback({ ok = true, data = normalized })
    end)
  end)
end

---Resolve a review thread
---@param opts Nit.Api.RequestOpts|{ thread_id: string }
---@param callback fun(result: Nit.Api.Result<{ id: string, isResolved: boolean }>)
---@return fun() cancel Cancel function
function M.resolve_thread(opts, callback)
  local thread_id = opts.thread_id
  local err = validate_thread_id(thread_id)
  if err then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. RESOLVE_MUTATION,
    '-f',
    'threadId=' .. thread_id,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'resolveReviewThread', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      if not data.thread then
        callback({ ok = false, error = 'Thread not found in response' })
        return
      end

      callback({
        ok = true,
        data = {
          id = data.thread.id,
          isResolved = data.thread.isResolved,
        },
      })
    end)
  end)
end

---Unresolve a review thread
---@param opts Nit.Api.RequestOpts|{ thread_id: string }
---@param callback fun(result: Nit.Api.Result<{ id: string, isResolved: boolean }>)
---@return fun() cancel Cancel function
function M.unresolve_thread(opts, callback)
  local thread_id = opts.thread_id
  local err = validate_thread_id(thread_id)
  if err then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. UNRESOLVE_MUTATION,
    '-f',
    'threadId=' .. thread_id,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'unresolveReviewThread', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      if not data.thread then
        callback({ ok = false, error = 'Thread not found in response' })
        return
      end

      callback({
        ok = true,
        data = {
          id = data.thread.id,
          isResolved = data.thread.isResolved,
        },
      })
    end)
  end)
end

---Update a pull request review comment body
---@param opts Nit.Api.RequestOpts|Nit.Api.ValidUpdateCommentOpts
---@param callback fun(result: Nit.Api.Result<Nit.Api.Comment>)
---@return fun() cancel Cancel function
function M.update_comment(opts, callback)
  if opts.comment_id == nil then
    callback({ ok = false, error = 'comment_id is required' })
    return function() end
  end
  if type(opts.comment_id) ~= 'string' or opts.comment_id == '' then
    callback({ ok = false, error = 'comment_id is required' })
    return function() end
  end

  local trimmed_body, err = validate_body(opts.body)
  if not trimmed_body then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. UPDATE_COMMENT_MUTATION,
    '-f',
    'commentId=' .. opts.comment_id,
    '-f',
    'body=' .. trimmed_body,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'updatePullRequestReviewComment', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      if not data.pullRequestReviewComment then
        callback({ ok = false, error = 'Comment not found in response' })
        return
      end

      local normalized = normalize_comment(data.pullRequestReviewComment)
      callback({ ok = true, data = normalized })
    end)
  end)
end

---Add a reaction to a pull request review comment
---@param opts Nit.Api.RequestOpts|Nit.Api.ValidReactionOpts
---@param callback fun(result: Nit.Api.Result<Nit.Api.ReactionGroup[]>)
---@return fun() cancel Cancel function
function M.add_reaction(opts, callback)
  local validated, err = validate_reaction_opts(opts)
  if not validated then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. ADD_REACTION_MUTATION,
    '-f',
    'subjectId=' .. validated.node_id,
    '-f',
    'content=' .. validated.content,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'addReaction', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      local reaction_groups = data.subject and data.subject.reactionGroups
      callback({ ok = true, data = normalize_reaction_groups(reaction_groups) })
    end)
  end)
end

---Remove a reaction from a pull request review comment
---@param opts Nit.Api.RequestOpts|Nit.Api.ValidReactionOpts
---@param callback fun(result: Nit.Api.Result<Nit.Api.ReactionGroup[]>)
---@return fun() cancel Cancel function
function M.remove_reaction(opts, callback)
  local validated, err = validate_reaction_opts(opts)
  if not validated then
    callback({ ok = false, error = err })
    return function() end
  end

  local request_opts = { timeout = opts.timeout, retry = opts.retry }
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. REMOVE_REACTION_MUTATION,
    '-f',
    'subjectId=' .. validated.node_id,
    '-f',
    'content=' .. validated.content,
  }

  return gh.execute(args, request_opts, function(result)
    parse_graphql_response(result, 'removeReaction', function(parse_err, data)
      if parse_err then
        callback({ ok = false, error = parse_err })
        return
      end

      local reaction_groups = data.subject and data.subject.reactionGroups
      callback({ ok = true, data = normalize_reaction_groups(reaction_groups) })
    end)
  end)
end

return M

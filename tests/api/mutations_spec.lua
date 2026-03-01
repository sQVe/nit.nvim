local mutations = require('nit.api.mutations')

---Helper to build a GraphQL mutation response
---@param mutation_key string
---@param data table
---@return string
local function mutation_response(mutation_key, data)
  return vim.json.encode({
    data = {
      [mutation_key] = data,
    },
  })
end

---Helper to build a GraphQL error response
---@param message string
---@return string
local function error_response(message)
  return vim.json.encode({
    errors = { { message = message } },
  })
end

local original_system
local original_uv_new_timer
local mock_system_results
local mock_call_index
local mock_timers

local function setup_mocks()
  original_system = vim.system
  original_uv_new_timer = vim.uv.new_timer

  mock_system_results = {}
  mock_call_index = 1
  mock_timers = {}

  vim.system = function(_cmd, _opts, callback)
    local result = mock_system_results[mock_call_index]
    mock_call_index = mock_call_index + 1
    vim.schedule(function()
      callback(result)
    end)
    return {
      kill = function() end,
    }
  end

  vim.uv.new_timer = function()
    local timer = {
      started = false,
      stopped = false,
      closed = false,
      callback = nil,
    }
    table.insert(mock_timers, timer)
    return {
      start = function(_, _timeout, _, cb)
        timer.started = true
        timer.callback = cb
        return timer
      end,
      stop = function()
        timer.stopped = true
      end,
      close = function()
        timer.closed = true
      end,
    }
  end
end

local function teardown_mocks()
  vim.system = original_system
  vim.uv.new_timer = original_uv_new_timer
end

describe('reply_to_thread', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('submits reply and returns normalized comment', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = { login = 'testuser' },
            body = 'This is a reply',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'This is a reply',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal(42, result.data.id)
    assert.are.equal('testuser', result.data.author.login)
    assert.are.equal('This is a reply', result.data.body)
    assert.are.equal('2024-01-01T10:00:00Z', result.data.createdAt)
    assert.is_nil(result.data.path)
    assert.is_nil(result.data.line)
  end)

  it('validates thread_id is required', function()
    local result = nil
    mutations.reply_to_thread({
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('thread_id', result.error)
  end)

  it('validates empty thread_id', function()
    local result = nil
    mutations.reply_to_thread({
      thread_id = '',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('thread_id', result.error)
  end)

  it('validates non-string thread_id', function()
    local result = nil
    mutations.reply_to_thread({
      thread_id = 123,
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('thread_id', result.error)
  end)

  it('validates body is required', function()
    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('body', result.error)
  end)

  it('trims whitespace and rejects empty-after-trim', function()
    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = '   ',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('body', result.error)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Permission denied'),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Permission denied', result.error)
  end)

  it('handles gh CLI errors', function()
    mock_system_results = {
      {
        code = 1,
        stdout = '',
        stderr = 'not authenticated',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = { login = 'testuser' },
            body = 'hello',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local cancel = mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function() end)

    assert.is_function(cancel)
  end)

  it('falls back to unknown for nil author', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = vim.NIL,
            body = 'Ghost comment',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal('unknown', result.data.author.login)
  end)

  it('falls back to unknown when author exists but login is nil', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = {},
            body = 'A reply',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal('unknown', result.data.author.login)
  end)

  it('defaults body and createdAt to empty string when nil', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = { login = 'testuser' },
            body = vim.NIL,
            createdAt = vim.NIL,
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal('', result.data.body)
    assert.are.equal('', result.data.createdAt)
  end)

  it('handles invalid JSON response', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'not valid json{{{',
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Failed to parse GraphQL response', result.error)
  end)

  it('handles missing comment in mutation response', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {}),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Comment not found in response', result.error)
  end)

  it('handles empty GraphQL errors array', function()
    mock_system_results = {
      {
        code = 0,
        stdout = vim.json.encode({ errors = {} }),
        stderr = '',
      },
    }

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('GraphQL error', result.error)
  end)

  it('trims whitespace from body while preserving content', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addPullRequestReviewThreadReply', {
          comment = {
            databaseId = 42,
            author = { login = 'testuser' },
            body = 'trimmed body',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local captured_cmd = nil
    vim.system = function(cmd, _opts, callback)
      captured_cmd = cmd
      local r = mock_system_results[1]
      vim.schedule(function()
        callback(r)
      end)
      return { kill = function() end }
    end

    local result = nil
    mutations.reply_to_thread({
      thread_id = 'PRRT_123',
      body = '  trimmed body  ',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(captured_cmd)
    local found_body = false
    for _, arg in ipairs(captured_cmd) do
      if arg == 'body=trimmed body' then
        found_body = true
      end
    end
    assert.is_true(found_body)
  end)
end)

describe('resolve_thread', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('resolves thread', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('resolveReviewThread', {
          thread = {
            id = 'PRRT_123',
            isResolved = true,
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.resolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal('PRRT_123', result.data.id)
    assert.is_true(result.data.isResolved)
  end)

  it('validates thread_id is required', function()
    local result = nil
    mutations.resolve_thread({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('thread_id', result.error)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Thread not found'),
        stderr = '',
      },
    }

    local result = nil
    mutations.resolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Thread not found', result.error)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('resolveReviewThread', {
          thread = { id = 'PRRT_123', isResolved = true },
        }),
        stderr = '',
      },
    }

    local cancel = mutations.resolve_thread({
      thread_id = 'PRRT_123',
    }, function() end)

    assert.is_function(cancel)
  end)

  it('handles missing thread in mutation response', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('resolveReviewThread', {}),
        stderr = '',
      },
    }

    local result = nil
    mutations.resolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Thread not found in response', result.error)
  end)
end)

describe('unresolve_thread', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('unresolves thread', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('unresolveReviewThread', {
          thread = {
            id = 'PRRT_123',
            isResolved = false,
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.unresolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal('PRRT_123', result.data.id)
    assert.is_false(result.data.isResolved)
  end)

  it('validates thread_id is required', function()
    local result = nil
    mutations.unresolve_thread({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
    assert.matches('thread_id', result.error)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('unresolveReviewThread', {
          thread = { id = 'PRRT_123', isResolved = false },
        }),
        stderr = '',
      },
    }

    local cancel = mutations.unresolve_thread({
      thread_id = 'PRRT_123',
    }, function() end)

    assert.is_function(cancel)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Thread not found'),
        stderr = '',
      },
    }

    local result = nil
    mutations.unresolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Thread not found', result.error)
  end)

  it('handles missing thread in mutation response', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('unresolveReviewThread', {}),
        stderr = '',
      },
    }

    local result = nil
    mutations.unresolve_thread({
      thread_id = 'PRRT_123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Thread not found in response', result.error)
  end)
end)

describe('add_reaction', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('adds reaction and returns updated reaction groups', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addReaction', {
          subject = {
            reactionGroups = {
              { content = 'THUMBS_UP', viewerHasReacted = true, reactors = { totalCount = 1 } },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.add_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal(1, #result.data)
    assert.are.equal('THUMBS_UP', result.data[1].content)
    assert.are.equal(1, result.data[1].count)
    assert.is_true(result.data[1].viewer_has_reacted)
  end)

  it('validates node_id is required', function()
    local result = nil
    mutations.add_reaction({
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('node_id', result.error)
  end)

  it('validates node_id cannot be empty', function()
    local result = nil
    mutations.add_reaction({
      node_id = '',
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('node_id', result.error)
  end)

  it('validates content must be a valid ReactionContent', function()
    local result = nil
    mutations.add_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'INVALID',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('content', result.error)
  end)

  it('validates content is required', function()
    local result = nil
    mutations.add_reaction({
      node_id = 'PRRC_kwDOABC123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('content', result.error)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Permission denied'),
        stderr = '',
      },
    }

    local result = nil
    mutations.add_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Permission denied', result.error)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('addReaction', {
          subject = { reactionGroups = {} },
        }),
        stderr = '',
      },
    }

    local cancel = mutations.add_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function() end)

    assert.is_function(cancel)
  end)
end)

describe('remove_reaction', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('removes reaction and returns updated reaction groups', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('removeReaction', {
          subject = {
            reactionGroups = {
              { content = 'THUMBS_UP', viewerHasReacted = false, reactors = { totalCount = 0 } },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.remove_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal(1, #result.data)
    assert.are.equal('THUMBS_UP', result.data[1].content)
    assert.are.equal(0, result.data[1].count)
    assert.is_false(result.data[1].viewer_has_reacted)
  end)

  it('validates node_id is required', function()
    local result = nil
    mutations.remove_reaction({
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('node_id', result.error)
  end)

  it('validates content must be a valid ReactionContent', function()
    local result = nil
    mutations.remove_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'INVALID',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.matches('content', result.error)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Permission denied'),
        stderr = '',
      },
    }

    local result = nil
    mutations.remove_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Permission denied', result.error)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('removeReaction', {
          subject = { reactionGroups = {} },
        }),
        stderr = '',
      },
    }

    local cancel = mutations.remove_reaction({
      node_id = 'PRRC_kwDOABC123',
      content = 'THUMBS_UP',
    }, function() end)

    assert.is_function(cancel)
  end)
end)

describe('update_comment', function()
  before_each(setup_mocks)
  after_each(teardown_mocks)

  it('submits update and returns normalized comment', function()
    mock_system_results = {
      {
        code = 0,
        stdout = mutation_response('updatePullRequestReviewComment', {
          pullRequestReviewComment = {
            id = 'PRRC_kwDOABC123',
            databaseId = 42,
            author = { login = 'alice' },
            body = 'Updated body',
            createdAt = '2024-01-01T10:00:00Z',
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    mutations.update_comment({
      comment_id = 'PRRC_kwDOABC123',
      body = 'Updated body',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal(42, result.data.id)
    assert.are.equal('PRRC_kwDOABC123', result.data.node_id)
    assert.are.equal('alice', result.data.author.login)
    assert.are.equal('Updated body', result.data.body)
  end)

  it('validates comment_id is required', function()
    local result = nil
    mutations.update_comment({
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('comment_id is required', result.error)
  end)

  it('validates body is required', function()
    local result = nil
    mutations.update_comment({
      comment_id = 'PRRC_kwDOABC123',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('body is required', result.error)
  end)

  it('validates body cannot be empty', function()
    local result = nil
    mutations.update_comment({
      comment_id = 'PRRC_kwDOABC123',
      body = '   ',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('body cannot be empty', result.error)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = error_response('Comment not found'),
        stderr = '',
      },
    }

    local result = nil
    mutations.update_comment({
      comment_id = 'PRRC_missing',
      body = 'hello',
    }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.are.equal('Comment not found', result.error)
  end)
end)

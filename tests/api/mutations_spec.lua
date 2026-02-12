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
    assert.equals(42, result.data.id)
    assert.equals('testuser', result.data.author.login)
    assert.equals('This is a reply', result.data.body)
    assert.equals('2024-01-01T10:00:00Z', result.data.createdAt)
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
    assert.equals('Permission denied', result.error)
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
    assert.equals('unknown', result.data.author.login)
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
    assert.equals('unknown', result.data.author.login)
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
    assert.equals('', result.data.body)
    assert.equals('', result.data.createdAt)
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
    assert.equals('Failed to parse GraphQL response', result.error)
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
    assert.equals('Comment not found in response', result.error)
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
    assert.equals('GraphQL error', result.error)
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
    assert.equals('PRRT_123', result.data.id)
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
    assert.equals('Thread not found', result.error)
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
    assert.equals('Thread not found in response', result.error)
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
    assert.equals('PRRT_123', result.data.id)
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
    assert.equals('Thread not found', result.error)
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
    assert.equals('Thread not found in response', result.error)
  end)
end)

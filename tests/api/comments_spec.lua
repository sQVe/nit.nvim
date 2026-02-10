local comments = require('nit.api.comments')

---Helper to build a GraphQL response with review threads
---@param thread_nodes table[]
---@return string
local function graphql_response(thread_nodes)
  return vim.json.encode({
    data = {
      repository = {
        pullRequest = {
          reviewThreads = {
            nodes = thread_nodes,
          },
        },
      },
    },
  })
end

describe('fetch_comments', function()
  local original_system
  local original_uv_new_timer
  local mock_system_results
  local mock_call_index
  local _mock_timers = {}

  before_each(function()
    original_system = vim.system
    original_uv_new_timer = vim.uv.new_timer

    mock_system_results = {}
    mock_call_index = 1
    _mock_timers = {}

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
      table.insert(_mock_timers, timer)
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
  end)

  after_each(function()
    vim.system = original_system
    vim.uv.new_timer = original_uv_new_timer
  end)

  it('fetches threads for current PR via GraphQL', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({
          {
            id = 'PRRT_thread1',
            isResolved = false,
            path = 'src/main.lua',
            line = 10,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 1,
                  author = { login = 'alice' },
                  body = 'First comment',
                  createdAt = '2024-01-01T10:00:00Z',
                },
                {
                  databaseId = 2,
                  author = { login = 'bob' },
                  body = 'Reply to first',
                  createdAt = '2024-01-01T11:00:00Z',
                },
              },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.equals(1, #result.data)

    local thread = result.data[1]
    assert.equals('PRRT_thread1', thread.id)
    assert.equals('src/main.lua', thread.path)
    assert.equals(10, thread.line)
    assert.is_false(thread.isResolved)
    assert.equals(2, #thread.comments)

    assert.equals('alice', thread.comments[1].author.login)
    assert.equals('First comment', thread.comments[1].body)
    assert.equals('2024-01-01T10:00:00Z', thread.comments[1].createdAt)

    assert.equals('bob', thread.comments[2].author.login)
    assert.equals('Reply to first', thread.comments[2].body)
  end)

  it('handles empty threads list', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({}),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_table(result.data)
    assert.equals(0, #result.data)
  end)

  it('preserves resolved state from GraphQL', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({
          {
            id = 'PRRT_resolved',
            isResolved = true,
            path = 'file.lua',
            line = 5,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 1,
                  author = { login = 'reviewer' },
                  body = 'Resolved thread',
                  createdAt = '2024-01-01T10:00:00Z',
                },
              },
            },
          },
          {
            id = 'PRRT_unresolved',
            isResolved = false,
            path = 'file.lua',
            line = 10,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 2,
                  author = { login = 'reviewer' },
                  body = 'Open thread',
                  createdAt = '2024-01-01T11:00:00Z',
                },
              },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals(2, #result.data)
    assert.is_true(result.data[1].isResolved)
    assert.is_false(result.data[2].isResolved)
  end)

  it('sorts threads by path then line', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({
          {
            id = 'PRRT_3',
            isResolved = false,
            path = 'file1.lua',
            line = 20,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 3,
                  author = { login = 'alice' },
                  body = 'Comment at line 20',
                  createdAt = '2024-01-01T10:00:00Z',
                },
              },
            },
          },
          {
            id = 'PRRT_1',
            isResolved = false,
            path = 'file1.lua',
            line = 5,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 1,
                  author = { login = 'bob' },
                  body = 'Comment at line 5',
                  createdAt = '2024-01-01T11:00:00Z',
                },
              },
            },
          },
          {
            id = 'PRRT_2',
            isResolved = false,
            path = 'file2.lua',
            line = 1,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 2,
                  author = { login = 'charlie' },
                  body = 'Comment in file2',
                  createdAt = '2024-01-01T12:00:00Z',
                },
              },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals(3, #result.data)

    assert.equals('file1.lua', result.data[1].path)
    assert.equals(5, result.data[1].line)

    assert.equals('file1.lua', result.data[2].path)
    assert.equals(20, result.data[2].line)

    assert.equals('file2.lua', result.data[3].path)
    assert.equals(1, result.data[3].line)
  end)

  it('returns cancel function', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
    }

    local cancel = comments.fetch_comments({}, function() end)

    assert.is_function(cancel)
  end)

  it('handles gh CLI errors gracefully', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 1,
        stdout = '',
        stderr = 'error: could not find pull request',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
  end)

  it('handles nil path and line from GraphQL', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({
          {
            id = 'PRRT_outdated',
            isResolved = false,
            path = vim.NIL,
            line = vim.NIL,
            diffSide = vim.NIL,
            comments = {
              nodes = {
                {
                  databaseId = 1,
                  author = { login = 'alice' },
                  body = 'Outdated comment',
                  createdAt = '2024-01-01T10:00:00Z',
                },
              },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals(1, #result.data)

    local thread = result.data[1]
    assert.is_nil(thread.path)
    assert.is_nil(thread.line)
    assert.is_nil(thread.side)
  end)

  it('handles GraphQL errors', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({
          errors = { { message = 'Could not resolve to a Repository' } },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.equals('Could not resolve to a Repository', result.error)
  end)

  it('falls back to unknown for null author', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = vim.json.encode({ number = 123 }),
        stderr = '',
      },
      {
        code = 0,
        stdout = graphql_response({
          {
            id = 'PRRT_ghost',
            isResolved = false,
            path = 'file.lua',
            line = 1,
            diffSide = 'RIGHT',
            comments = {
              nodes = {
                {
                  databaseId = 1,
                  author = vim.NIL,
                  body = 'Ghost comment',
                  createdAt = '2024-01-01T10:00:00Z',
                },
              },
            },
          },
        }),
        stderr = '',
      },
    }

    local result = nil
    comments.fetch_comments({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals('unknown', result.data[1].comments[1].author.login)
  end)
end)

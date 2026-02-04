local comments = require('nit.api.comments')

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

  it('fetches comments for current PR', function()
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
          {
            id = 1,
            user = { login = 'alice', name = 'Alice Smith' },
            body = 'First comment',
            created_at = '2024-01-01T10:00:00Z',
            path = 'src/main.lua',
            line = 10,
            side = 'RIGHT',
          },
          {
            id = 2,
            user = { login = 'bob' },
            body = 'Reply to first',
            created_at = '2024-01-01T11:00:00Z',
            path = 'src/main.lua',
            line = 10,
            side = 'RIGHT',
            in_reply_to_id = 1,
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
    assert.equals(1, thread.id)
    assert.equals('src/main.lua', thread.path)
    assert.equals(10, thread.line)
    assert.equals(2, #thread.comments)

    assert.equals('alice', thread.comments[1].author.login)
    assert.equals('Alice Smith', thread.comments[1].author.name)
    assert.equals('First comment', thread.comments[1].body)
    assert.equals('2024-01-01T10:00:00Z', thread.comments[1].createdAt)

    assert.equals('bob', thread.comments[2].author.login)
    assert.is_nil(thread.comments[2].author.name)
    assert.equals('Reply to first', thread.comments[2].body)
  end)

  it('handles empty comments list', function()
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
        stdout = '[]',
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

  it('groups multiple threads by path and line', function()
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
          {
            id = 1,
            user = { login = 'alice' },
            body = 'Thread 1',
            created_at = '2024-01-01T10:00:00Z',
            path = 'file1.lua',
            line = 5,
            side = 'RIGHT',
          },
          {
            id = 2,
            user = { login = 'bob' },
            body = 'Thread 2',
            created_at = '2024-01-01T11:00:00Z',
            path = 'file2.lua',
            line = 10,
            side = 'LEFT',
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

    assert.equals(1, result.data[1].id)
    assert.equals('file1.lua', result.data[1].path)
    assert.equals(1, #result.data[1].comments)

    assert.equals(2, result.data[2].id)
    assert.equals('file2.lua', result.data[2].path)
    assert.equals(1, #result.data[2].comments)
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
        stdout = vim.json.encode({
          {
            id = 3,
            user = { login = 'alice' },
            body = 'Comment at line 20',
            created_at = '2024-01-01T10:00:00Z',
            path = 'file1.lua',
            line = 20,
            side = 'RIGHT',
          },
          {
            id = 1,
            user = { login = 'bob' },
            body = 'Comment at line 5',
            created_at = '2024-01-01T11:00:00Z',
            path = 'file1.lua',
            line = 5,
            side = 'RIGHT',
          },
          {
            id = 2,
            user = { login = 'charlie' },
            body = 'Comment in file2',
            created_at = '2024-01-01T12:00:00Z',
            path = 'file2.lua',
            line = 1,
            side = 'RIGHT',
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
end)

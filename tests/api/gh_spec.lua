local gh = require('nit.api.gh')
local tracker = require('nit.api.tracker')

describe('gh.execute', function()
  local original_system
  local original_uv_new_timer
  local mock_system_result
  local _mock_timers = {}

  before_each(function()
    original_system = vim.system
    original_uv_new_timer = vim.uv.new_timer

    mock_system_result = nil
    _mock_timers = {}

    vim.system = function(_cmd, _opts, callback)
      vim.schedule(function()
        callback(mock_system_result)
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

  it('calls callback with ok=true on success', function()
    mock_system_result = {
      code = 0,
      stdout = '{"title": "Test PR"}',
      stderr = '',
    }

    local result = nil
    gh.execute({ 'pr', 'view', '--json', 'title' }, nil, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals('{"title": "Test PR"}', result.data)
  end)

  it('calls callback with ok=false on error', function()
    mock_system_result = {
      code = 1,
      stdout = '',
      stderr = 'error: unknown command',
    }

    local result = nil
    gh.execute({ 'invalid', 'command' }, nil, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
  end)

  it('returns cancel function that prevents callback', function()
    mock_system_result = {
      code = 0,
      stdout = 'data',
      stderr = '',
    }

    local result = nil
    local cancel = gh.execute({ 'pr', 'view' }, nil, function(r)
      result = r
    end)

    cancel()

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_nil(result)
  end)

  it('tracks request in tracker module', function()
    mock_system_result = {
      code = 0,
      stdout = 'data',
      stderr = '',
    }

    local initial_count = tracker.get_count()

    local _cancel = gh.execute({ 'pr', 'view' }, nil, function() end)

    local count_during = tracker.get_count()
    assert.equals(initial_count + 1, count_during)

    vim.wait(100)

    local count_after = tracker.get_count()
    assert.equals(initial_count, count_after)
  end)

  it('provides user-friendly error for authentication', function()
    mock_system_result = {
      code = 1,
      stdout = '',
      stderr = 'error: authentication required',
    }

    local result = nil
    gh.execute({ 'pr', 'view' }, nil, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.equals('Not authenticated', result.error)
  end)
end)

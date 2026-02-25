local files = require('nit.api.files')

describe('files.fetch_files', function()
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

  it('fetches files for current branch PR', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = '{"number":42}',
        stderr = '',
      },
      {
        code = 0,
        stdout = '[{"filename":"src/foo.lua","additions":10,"deletions":2,"status":"modified"}]',
        stderr = '',
      },
    }

    local result = nil
    files.fetch_files({}, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.are.equal(1, #result.data)
    assert.are.equal('src/foo.lua', result.data[1].filename)
    assert.are.equal('modified', result.data[1].status)
    assert.are.equal(10, result.data[1].additions)
    assert.are.equal(2, result.data[1].deletions)
  end)

  it('fetches files for specific PR', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = '[{"filename":"README.md","additions":5,"deletions":0,"status":"modified"}]',
        stderr = '',
      },
    }

    local result = nil
    files.fetch_files({ number = 123 }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal(1, #result.data)
    assert.are.equal('README.md', result.data[1].filename)
  end)

  it('normalizes file status codes', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = '[{"filename":"new.lua","additions":20,"deletions":0,"status":"added"},{"filename":"old.lua","additions":0,"deletions":15,"status":"removed"},{"filename":"moved.lua","additions":5,"deletions":5,"status":"renamed"}]',
        stderr = '',
      },
    }

    local result = nil
    files.fetch_files({ number = 456 }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal(3, #result.data)
    assert.are.equal('added', result.data[1].status)
    assert.are.equal('removed', result.data[2].status)
    assert.are.equal('renamed', result.data[3].status)
  end)

  it('returns error when not on PR', function()
    mock_system_results = {
      {
        code = 1,
        stdout = '',
        stderr = 'fatal: not a git repository',
      },
    }

    local result = nil
    files.fetch_files({}, function(r)
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
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
    }

    local cancel = files.fetch_files({}, function() end)

    assert.is_not_nil(cancel)
    assert.are.equal('function', type(cancel))
  end)

  it('normalizes copied status to modified', function()
    mock_system_results = {
      {
        code = 0,
        stdout = 'git@github.com:owner/repo.git\n',
        stderr = '',
      },
      {
        code = 0,
        stdout = '[{"filename":"copy.lua","additions":10,"deletions":0,"status":"copied"}]',
        stderr = '',
      },
    }

    local result = nil
    files.fetch_files({ number = 789 }, function(r)
      result = r
    end)

    vim.wait(200, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal(1, #result.data)
    assert.are.equal('modified', result.data[1].status)
  end)
end)

describe('files.fetch_diff', function()
  local original_system
  local mock_system_result

  before_each(function()
    original_system = vim.system

    mock_system_result = nil

    vim.system = function(_cmd, _opts, callback)
      vim.schedule(function()
        callback(mock_system_result)
      end)
      return {
        kill = function() end,
      }
    end
  end)

  after_each(function()
    vim.system = original_system
  end)

  it('fetches full PR diff', function()
    mock_system_result = {
      code = 0,
      stdout = 'diff --git a/src/foo.lua b/src/foo.lua\n+new line',
      stderr = '',
    }

    local result = nil
    files.fetch_diff({}, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.are.equal('string', type(result.data))
    assert.is_true(result.data:match('diff %-%-git'))
  end)

  it('fetches diff for specific file', function()
    mock_system_result = {
      code = 0,
      stdout = 'diff --git a/src/foo.lua b/src/foo.lua\n+change',
      stderr = '',
    }

    local result = nil
    files.fetch_diff({ path = 'src/foo.lua' }, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
  end)

  it('fetches diff for specific PR and file', function()
    mock_system_result = {
      code = 0,
      stdout = 'diff --git a/README.md b/README.md\n+update',
      stderr = '',
    }

    local result = nil
    files.fetch_diff({ number = 123, path = 'README.md' }, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
  end)

  it('returns error on failure', function()
    mock_system_result = {
      code = 1,
      stdout = '',
      stderr = 'error: no pull requests found',
    }

    local result = nil
    files.fetch_diff({}, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_false(result.ok)
    assert.is_not_nil(result.error)
  end)

  it('returns cancel function', function()
    mock_system_result = {
      code = 0,
      stdout = 'diff content',
      stderr = '',
    }

    local cancel = files.fetch_diff({}, function() end)

    assert.is_not_nil(cancel)
    assert.are.equal('function', type(cancel))
  end)
end)

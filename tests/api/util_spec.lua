local util = require('nit.api.util')

describe('util.get_repo_info', function()
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

  it('parses SSH remote URL', function()
    mock_system_result = {
      code = 0,
      stdout = 'git@github.com:owner/repo.git\n',
      stderr = '',
    }

    local owner, repo
    util.get_repo_info(function(o, r)
      owner = o
      repo = r
    end)

    vim.wait(100, function()
      return owner ~= nil
    end)

    assert.are.equal('owner', owner)
    assert.are.equal('repo', repo)
  end)

  it('parses HTTPS remote URL', function()
    mock_system_result = {
      code = 0,
      stdout = 'https://github.com/myorg/myrepo.git\n',
      stderr = '',
    }

    local owner, repo
    util.get_repo_info(function(o, r)
      owner = o
      repo = r
    end)

    vim.wait(100, function()
      return owner ~= nil
    end)

    assert.are.equal('myorg', owner)
    assert.are.equal('myrepo', repo)
  end)

  it('strips .git suffix from repo name', function()
    mock_system_result = {
      code = 0,
      stdout = 'https://github.com/org/project.git\n',
      stderr = '',
    }

    local repo
    util.get_repo_info(function(_, r)
      repo = r
    end)

    vim.wait(100, function()
      return repo ~= nil
    end)

    assert.are.equal('project', repo)
  end)

  it('handles URL without .git suffix', function()
    mock_system_result = {
      code = 0,
      stdout = 'https://github.com/org/project\n',
      stderr = '',
    }

    local repo
    util.get_repo_info(function(_, r)
      repo = r
    end)

    vim.wait(100, function()
      return repo ~= nil
    end)

    assert.are.equal('project', repo)
  end)

  it('returns nil for non-GitHub remote', function()
    mock_system_result = {
      code = 0,
      stdout = 'git@gitlab.com:owner/repo.git\n',
      stderr = '',
    }

    local called = false
    local owner, repo
    util.get_repo_info(function(o, r)
      called = true
      owner = o
      repo = r
    end)

    vim.wait(100, function()
      return called
    end)

    assert.is_nil(owner)
    assert.is_nil(repo)
  end)

  it('returns nil when git command fails', function()
    mock_system_result = {
      code = 128,
      stdout = '',
      stderr = 'fatal: not a git repository',
    }

    local called = false
    local owner, repo
    util.get_repo_info(function(o, r)
      called = true
      owner = o
      repo = r
    end)

    vim.wait(100, function()
      return called
    end)

    assert.is_nil(owner)
    assert.is_nil(repo)
  end)

  it('returns cancel function', function()
    mock_system_result = {
      code = 0,
      stdout = 'git@github.com:owner/repo.git\n',
      stderr = '',
    }

    local cancel = util.get_repo_info(function() end)

    assert.is_function(cancel)
  end)
end)

local files = require('nit.api.files')

describe('files.fetch_files', function()
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

  it('fetches files for current branch PR', function()
    mock_system_result = {
      code = 0,
      stdout = '{"files":[{"path":"src/foo.lua","additions":10,"deletions":2,"status":"modified"}]}',
      stderr = '',
    }

    local result = nil
    files.fetch_files({}, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.is_not_nil(result.data)
    assert.equals(1, #result.data)
    assert.equals('src/foo.lua', result.data[1].filename)
    assert.equals('modified', result.data[1].status)
    assert.equals(10, result.data[1].additions)
    assert.equals(2, result.data[1].deletions)
  end)

  it('fetches files for specific PR', function()
    mock_system_result = {
      code = 0,
      stdout = '{"files":[{"path":"README.md","additions":5,"deletions":0,"status":"modified"}]}',
      stderr = '',
    }

    local result = nil
    files.fetch_files({ number = 123 }, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals(1, #result.data)
    assert.equals('README.md', result.data[1].filename)
  end)

  it('normalizes file status codes', function()
    mock_system_result = {
      code = 0,
      stdout = '{"files":[{"path":"new.lua","additions":20,"deletions":0,"status":"added"},{"path":"old.lua","additions":0,"deletions":15,"status":"removed"},{"path":"moved.lua","additions":5,"deletions":5,"status":"renamed"}]}',
      stderr = '',
    }

    local result = nil
    files.fetch_files({}, function(r)
      result = r
    end)

    vim.wait(100, function()
      return result ~= nil
    end)

    assert.is_not_nil(result)
    assert.is_true(result.ok)
    assert.equals(3, #result.data)
    assert.equals('added', result.data[1].status)
    assert.equals('removed', result.data[2].status)
    assert.equals('renamed', result.data[3].status)
  end)

  it('returns error when not on PR', function()
    mock_system_result = {
      code = 1,
      stdout = '',
      stderr = 'error: no pull requests found',
    }

    local result = nil
    files.fetch_files({}, function(r)
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
      stdout = '{"files":[]}',
      stderr = '',
    }

    local cancel = files.fetch_files({}, function() end)

    assert.is_not_nil(cancel)
    assert.equals('function', type(cancel))
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
    assert.equals('string', type(result.data))
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
    assert.equals('function', type(cancel))
  end)
end)

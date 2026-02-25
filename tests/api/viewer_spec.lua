describe('nit.api.viewer', function()
  local viewer = require('nit.api.viewer')
  local gh = require('nit.api.gh')
  local original_execute

  before_each(function()
    original_execute = original_execute or gh.execute
    gh.execute = function(_args, _opts, _callback)
      return function() end
    end
  end)

  after_each(function()
    gh.execute = original_execute
  end)

  describe('fetch_viewer', function()
    it('returns a cancel function', function()
      local cancel = viewer.fetch_viewer({}, function() end)
      assert.is_function(cancel)
    end)

    it('calls gh api user with jq filter for login', function()
      local called_args = nil
      gh.execute = function(args, _opts, _callback)
        called_args = args
        return function() end
      end

      viewer.fetch_viewer({}, function() end)

      assert.are.same({ 'api', 'user', '--jq', '.login' }, called_args)
    end)

    it('returns trimmed login on success', function()
      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = 'octocat\n' })
        return function() end
      end

      viewer.fetch_viewer({}, function(r)
        result = r
      end)

      assert.is_true(result.ok)
      assert.are.equal('octocat', result.data)
    end)

    it('returns error result when response is empty', function()
      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = '   \n' })
        return function() end
      end

      viewer.fetch_viewer({}, function(r)
        result = r
      end)

      assert.is_false(result.ok)
      assert.is_string(result.error)
    end)

    it('propagates error when gh call fails', function()
      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = false, error = 'Not authenticated' })
        return function() end
      end

      viewer.fetch_viewer({}, function(r)
        result = r
      end)

      assert.is_false(result.ok)
      assert.are.equal('Not authenticated', result.error)
    end)
  end)
end)

describe('nit.api.pr', function()
  local pr = require('nit.api.pr')
  local gh = require('nit.api.gh')
  local original_execute

  describe('fetch_pr', function()
    before_each(function()
      original_execute = original_execute or gh.execute
      gh.execute = function(_args, _opts, _callback)
        return function() end
      end
    end)

    after_each(function()
      gh.execute = original_execute
    end)

    it('returns a cancel function', function()
      local cancel = pr.fetch_pr({}, function() end)
      assert.is_function(cancel)
    end)

    it('fetches PR for current branch when no args provided', function()
      local called_args = nil
      gh.execute = function(args, _opts, _callback)
        called_args = args
        return function() end
      end

      pr.fetch_pr({}, function() end)

      assert.are.same({
        'pr',
        'view',
        '--json',
        'number,title,state,author,body,createdAt,updatedAt,mergeable,isDraft',
      }, called_args)
    end)

    it('fetches PR by number when opts.number provided', function()
      local called_args = nil
      gh.execute = function(args, _opts, _callback)
        called_args = args
        return function() end
      end

      pr.fetch_pr({ number = 123 }, function() end)

      assert.equals('pr', called_args[1])
      assert.equals('view', called_args[2])
      assert.equals('123', called_args[3])
      assert.equals('--json', called_args[4])
      assert.is_truthy(called_args[5]:match('number'))
    end)

    it('fetches PR by branch when opts.branch provided', function()
      local called_args = nil
      gh.execute = function(args, _opts, _callback)
        called_args = args
        return function() end
      end

      pr.fetch_pr({ branch = 'feat/test' }, function() end)

      assert.equals('pr', called_args[1])
      assert.equals('view', called_args[2])
      assert.equals('feat/test', called_args[3])
      assert.equals('--json', called_args[4])
      assert.is_truthy(called_args[5]:match('number'))
    end)

    it('passes timeout option to gh.execute', function()
      local called_opts = nil
      gh.execute = function(_args, opts, _callback)
        called_opts = opts
        return function() end
      end

      pr.fetch_pr({ timeout = 5000 }, function() end)

      assert.equals(5000, called_opts.timeout)
    end)

    it('normalizes successful PR response', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test PR',
        state = 'OPEN',
        author = { login = 'testuser', name = 'Test User' },
        body = 'PR description',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'MERGEABLE',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.is_true(result.ok)
      assert.equals(123, result.data.number)
      assert.equals('Test PR', result.data.title)
      assert.equals('open', result.data.state)
      assert.equals('testuser', result.data.author.login)
      assert.equals('Test User', result.data.author.name)
      assert.equals('PR description', result.data.body)
      assert.equals('2026-01-01T00:00:00Z', result.data.createdAt)
      assert.equals('2026-01-02T00:00:00Z', result.data.updatedAt)
      assert.equals('clean', result.data.mergeable)
      assert.is_false(result.data.isDraft)
    end)

    it('normalizes CLOSED state to lowercase', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'CLOSED',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'UNKNOWN',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('closed', result.data.state)
    end)

    it('normalizes MERGED state to lowercase', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'MERGED',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'UNKNOWN',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('merged', result.data.state)
    end)

    it('normalizes MERGEABLE to clean', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'OPEN',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'MERGEABLE',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('clean', result.data.mergeable)
    end)

    it('normalizes CONFLICTING to dirty', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'OPEN',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'CONFLICTING',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('dirty', result.data.mergeable)
    end)

    it('normalizes UNKNOWN mergeable to unknown', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'OPEN',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'UNKNOWN',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('unknown', result.data.mergeable)
    end)

    it('handles author without name field', function()
      local gh_response = vim.json.encode({
        number = 123,
        title = 'Test',
        state = 'OPEN',
        author = { login = 'test' },
        body = '',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'UNKNOWN',
        isDraft = false,
      })

      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = gh_response })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.equals('test', result.data.author.login)
      assert.is_nil(result.data.author.name)
    end)

    it('returns error when gh.execute fails', function()
      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = false, error = 'Not authenticated' })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.is_false(result.ok)
      assert.equals('Not authenticated', result.error)
    end)

    it('returns error when JSON parsing fails', function()
      local result = nil
      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = 'invalid json' })
        return function() end
      end

      pr.fetch_pr({}, function(r)
        result = r
      end)

      assert.is_false(result.ok)
      assert.is_string(result.error)
      assert.is_truthy(result.error:match('[Cc]ould not parse'))
    end)
  end)
end)

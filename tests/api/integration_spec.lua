describe('nit.api integration', function()
  local api = require('nit.api')
  local gh = require('nit.api.gh')
  local tracker = require('nit.api.tracker')

  describe('public exports', function()
    it('exports fetch_pr', function()
      assert.is_function(api.fetch_pr)
    end)

    it('exports fetch_files', function()
      assert.is_function(api.fetch_files)
    end)

    it('exports fetch_diff', function()
      assert.is_function(api.fetch_diff)
    end)

    it('exports fetch_comments', function()
      assert.is_function(api.fetch_comments)
    end)

    it('exports parallel', function()
      assert.is_function(api.parallel)
    end)

    it('exports cancel_all', function()
      assert.is_function(api.cancel_all)
    end)
  end)

  describe('parallel execution', function()
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

    it('executes multiple API calls in parallel', function()
      local pr_response = vim.json.encode({
        number = 123,
        title = 'Test PR',
        state = 'OPEN',
        author = { login = 'testuser' },
        body = 'Test body',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'MERGEABLE',
        isDraft = false,
      })

      local files_response = vim.json.encode({
        files = {
          { path = 'file1.lua', status = 'modified', additions = 10, deletions = 5 },
          { path = 'file2.lua', status = 'added', additions = 20, deletions = 0 },
        },
      })

      local execute_count = 0
      gh.execute = function(args, _opts, callback)
        execute_count = execute_count + 1

        vim.schedule(function()
          local json_idx = nil
          for i, arg in ipairs(args) do
            if arg == '--json' then
              json_idx = i
              break
            end
          end
          local fields = json_idx and args[json_idx + 1]

          if fields and fields:match('mergeable') then
            callback({ ok = true, data = pr_response })
          elseif fields == 'files' then
            callback({ ok = true, data = files_response })
          end
        end)

        return function() end
      end

      local results = nil
      api.parallel({
        { fn = api.fetch_pr, args = {} },
        { fn = api.fetch_files, args = {} },
      }, function(r)
        results = r
      end)

      vim.wait(100, function()
        return results ~= nil
      end)

      assert.equals(2, execute_count)
      assert.equals(2, #results)
      assert.is_true(results[1].ok)
      assert.equals(123, results[1].data.number)
      assert.is_true(results[2].ok)
      assert.equals(2, #results[2].data)
    end)

    it('handles mixed success and failure in parallel', function()
      gh.execute = function(args, _opts, callback)
        if args[1] == 'pr' and args[2] == 'view' then
          callback({ ok = false, error = 'PR not found' })
        elseif args[2] == 'diff' then
          callback({ ok = true, data = 'diff content' })
        end

        return function() end
      end

      local results = nil
      api.parallel({
        { fn = api.fetch_pr, args = {} },
        { fn = api.fetch_diff, args = {} },
      }, function(r)
        results = r
      end)

      assert.equals(2, #results)
      assert.is_false(results[1].ok)
      assert.equals('PR not found', results[1].error)
      assert.is_true(results[2].ok)
      assert.equals('diff content', results[2].data)
    end)
  end)

  describe('cancel_all', function()
    before_each(function()
      while tracker.get_count() > 0 do
        tracker.cancel_all()
      end
    end)

    it('cancels all in-flight requests', function()
      local cancelled_count = 0
      local original_execute = gh.execute

      gh.execute = function(_args, _opts, _callback)
        local cancel_fn = function()
          cancelled_count = cancelled_count + 1
        end
        local id = tracker.track(cancel_fn)
        return function()
          tracker.untrack(id)
          cancel_fn()
        end
      end

      api.fetch_pr({}, function() end)
      api.fetch_files({}, function() end)
      api.fetch_diff({}, function() end)

      assert.equals(3, tracker.get_count())

      api.cancel_all()

      assert.equals(3, cancelled_count)
      assert.equals(0, tracker.get_count())

      gh.execute = original_execute
    end)

    it('prevents callbacks from being called after cancel', function()
      local callback_called = false
      local original_execute = gh.execute

      gh.execute = function(_args, _opts, callback)
        local cancelled = false

        vim.defer_fn(function()
          if not cancelled then
            callback({ ok = true, data = 'response' })
          end
        end, 10)

        local cancel_fn = function()
          cancelled = true
        end
        local id = tracker.track(cancel_fn)

        return function()
          tracker.untrack(id)
          cancel_fn()
        end
      end

      api.fetch_pr({}, function()
        callback_called = true
      end)

      api.cancel_all()

      vim.wait(50, function()
        return callback_called
      end)

      assert.is_false(callback_called)

      gh.execute = original_execute
    end)
  end)

  describe('type consistency', function()
    it('fetch_pr returns expected PR structure', function()
      local pr_response = vim.json.encode({
        number = 456,
        title = 'Feature PR',
        state = 'MERGED',
        author = { login = 'developer', name = 'Dev Name' },
        body = 'Description',
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'CONFLICTING',
        isDraft = true,
      })

      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = pr_response })
        return function() end
      end

      local result = nil
      api.fetch_pr({}, function(r)
        result = r
      end)

      assert.is_true(result.ok)
      assert.is_number(result.data.number)
      assert.is_string(result.data.title)
      assert.is_string(result.data.state)
      assert.is_table(result.data.author)
      assert.is_string(result.data.author.login)
      assert.is_string(result.data.body)
      assert.is_string(result.data.createdAt)
      assert.is_string(result.data.updatedAt)
      assert.is_string(result.data.mergeable)
      assert.is_boolean(result.data.isDraft)
    end)

    it('fetch_files returns expected file structure', function()
      local files_response = vim.json.encode({
        files = {
          { path = 'src/main.lua', status = 'modified', additions = 15, deletions = 3 },
        },
      })

      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = files_response })
        return function() end
      end

      local result = nil
      api.fetch_files({}, function(r)
        result = r
      end)

      assert.is_true(result.ok)
      assert.equals(1, #result.data)

      local file = result.data[1]
      assert.is_string(file.filename)
      assert.is_string(file.status)
      assert.is_number(file.additions)
      assert.is_number(file.deletions)
    end)

    it('fetch_diff returns string diff content', function()
      local diff_content = [[
diff --git a/file.lua b/file.lua
index 123..456 789
--- a/file.lua
+++ b/file.lua
@@ -1,3 +1,4 @@
+local new_line = true
 local existing = 'value'
]]

      gh.execute = function(_args, _opts, callback)
        callback({ ok = true, data = diff_content })
        return function() end
      end

      local result = nil
      api.fetch_diff({}, function(r)
        result = r
      end)

      assert.is_true(result.ok)
      assert.is_string(result.data)
      assert.is_truthy(result.data:match('diff %-%-git'))
    end)
  end)
end)

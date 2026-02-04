describe('nit.state.data', function()
  local data = require('nit.state.data')
  local observers = require('nit.state.observers')

  after_each(function()
    data.clear()
    observers.clear()
  end)

  describe('PR operations', function()
    it('set_pr stores and get_pr retrieves', function()
      local pr = {
        number = 123,
        title = 'Test PR',
        state = 'open',
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      }

      data.set_pr(pr)

      local result = data.get_pr()
      assert.is_not_nil(result)
      assert.equals(123, result.number)
      assert.equals('Test PR', result.title)
    end)

    it('set_pr with nil clears PR', function()
      local pr = {
        number = 123,
        title = 'Test PR',
        state = 'open',
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      }

      data.set_pr(pr)
      data.set_pr(nil)

      assert.is_nil(data.get_pr())
    end)

    it('set_pr notifies pr key', function()
      local notified_key = nil
      observers.subscribe('pr', function(key)
        notified_key = key
      end)

      data.set_pr({
        number = 1,
        title = 'PR',
        state = 'open',
        author = { login = 'user' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      })

      local ok = vim.wait(100, function()
        return notified_key ~= nil
      end)

      assert.is_true(ok, 'observer was not notified')
      assert.equals('pr', notified_key)
    end)
  end)

  describe('File operations', function()
    it('set_files stores by path, get_file retrieves by path', function()
      local files = {
        { filename = 'src/main.lua', status = 'modified', additions = 10, deletions = 5 },
        { filename = 'src/utils.lua', status = 'added', additions = 20, deletions = 0 },
      }

      data.set_files(files)

      local result = data.get_file('src/main.lua')
      assert.is_not_nil(result)
      assert.equals('src/main.lua', result.filename)
      assert.equals('modified', result.status)
    end)

    it('get_file returns nil for nonexistent path', function()
      data.set_files({
        { filename = 'src/main.lua', status = 'modified', additions = 10, deletions = 5 },
      })

      assert.is_nil(data.get_file('nonexistent.lua'))
    end)

    it('get_files returns all files', function()
      local files = {
        { filename = 'a.lua', status = 'modified', additions = 1, deletions = 0 },
        { filename = 'b.lua', status = 'added', additions = 2, deletions = 0 },
        { filename = 'c.lua', status = 'removed', additions = 0, deletions = 3 },
      }

      data.set_files(files)

      local result = data.get_files()
      assert.equals(3, #result)
    end)

    it('set_files notifies files key', function()
      local notified_key = nil
      observers.subscribe('files', function(key)
        notified_key = key
      end)

      data.set_files({
        { filename = 'test.lua', status = 'added', additions = 1, deletions = 0 },
      })

      local ok = vim.wait(100, function()
        return notified_key ~= nil
      end)

      assert.is_true(ok, 'observer was not notified')
      assert.equals('files', notified_key)
    end)
  end)

  describe('Thread operations', function()
    it('set_threads stores by ID, get_thread retrieves by ID', function()
      local threads = {
        {
          id = 100,
          comments = {
            {
              id = 1,
              author = { login = 'user' },
              body = 'Comment',
              createdAt = '2026-01-01T00:00:00Z',
            },
          },
          isResolved = false,
          path = 'src/main.lua',
          line = 10,
        },
        {
          id = 200,
          comments = {
            {
              id = 2,
              author = { login = 'user' },
              body = 'Comment 2',
              createdAt = '2026-01-01T00:00:00Z',
            },
          },
          isResolved = true,
          path = 'src/utils.lua',
          line = 20,
        },
      }

      data.set_threads(threads)

      local result = data.get_thread(100)
      assert.is_not_nil(result)
      assert.equals(100, result.id)
      assert.equals('src/main.lua', result.path)
    end)

    it('get_thread returns nil for nonexistent ID', function()
      data.set_threads({
        { id = 100, comments = {}, isResolved = false },
      })

      assert.is_nil(data.get_thread(999))
    end)

    it('get_threads returns all threads', function()
      local threads = {
        { id = 1, comments = {}, isResolved = false },
        { id = 2, comments = {}, isResolved = false },
        { id = 3, comments = {}, isResolved = true },
      }

      data.set_threads(threads)

      local result = data.get_threads()
      assert.equals(3, #result)
    end)

    it('set_threads notifies comments key', function()
      local notified_key = nil
      observers.subscribe('comments', function(key)
        notified_key = key
      end)

      data.set_threads({
        { id = 1, comments = {}, isResolved = false },
      })

      local ok = vim.wait(100, function()
        return notified_key ~= nil
      end)

      assert.is_true(ok, 'observer was not notified')
      assert.equals('comments', notified_key)
    end)
  end)

  describe('Index maintenance', function()
    it('set_threads builds threads_by_file index', function()
      local threads = {
        { id = 1, comments = {}, isResolved = false, path = 'src/a.lua', line = 10 },
        { id = 2, comments = {}, isResolved = false, path = 'src/a.lua', line = 20 },
        { id = 3, comments = {}, isResolved = false, path = 'src/b.lua', line = 5 },
      }

      data.set_threads(threads)

      local a_threads = data.get_threads_for_file('src/a.lua')
      assert.equals(2, #a_threads)

      local ids = {}
      for _, t in ipairs(a_threads) do
        table.insert(ids, t.id)
      end
      table.sort(ids)
      assert.same({ 1, 2 }, ids)
    end)

    it('get_threads_for_file returns empty table for path with no threads', function()
      data.set_threads({
        { id = 1, comments = {}, isResolved = false, path = 'src/a.lua', line = 10 },
      })

      local result = data.get_threads_for_file('nonexistent.lua')
      assert.is_table(result)
      assert.equals(0, #result)
    end)

    it('threads without path are not indexed by file', function()
      local threads = {
        { id = 1, comments = {}, isResolved = false, path = 'src/a.lua', line = 10 },
        { id = 2, comments = {}, isResolved = false },
      }

      data.set_threads(threads)

      local a_threads = data.get_threads_for_file('src/a.lua')
      assert.equals(1, #a_threads)
      assert.equals(1, a_threads[1].id)
    end)

    it('index is rebuilt on subsequent set_threads calls', function()
      data.set_threads({
        { id = 1, comments = {}, isResolved = false, path = 'src/a.lua', line = 10 },
        { id = 2, comments = {}, isResolved = false, path = 'src/a.lua', line = 20 },
      })

      assert.equals(2, #data.get_threads_for_file('src/a.lua'))

      data.set_threads({
        { id = 3, comments = {}, isResolved = false, path = 'src/b.lua', line = 5 },
      })

      assert.equals(0, #data.get_threads_for_file('src/a.lua'))
      assert.equals(1, #data.get_threads_for_file('src/b.lua'))
    end)
  end)

  describe('clear', function()
    it('resets all data', function()
      data.set_pr({
        number = 1,
        title = 'PR',
        state = 'open',
        author = { login = 'user' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      })
      data.set_files({
        { filename = 'test.lua', status = 'added', additions = 1, deletions = 0 },
      })
      data.set_threads({
        { id = 1, comments = {}, isResolved = false, path = 'test.lua', line = 10 },
      })

      data.clear()

      assert.is_nil(data.get_pr())
      assert.equals(0, #data.get_files())
      assert.equals(0, #data.get_threads())
      assert.equals(0, #data.get_threads_for_file('test.lua'))
    end)

    it('notifies all keys', function()
      local notified_keys = {}
      observers.subscribe('pr', function(key)
        notified_keys[key] = true
      end)
      observers.subscribe('files', function(key)
        notified_keys[key] = true
      end)
      observers.subscribe('comments', function(key)
        notified_keys[key] = true
      end)

      data.clear()

      local ok = vim.wait(100, function()
        return notified_keys.pr and notified_keys.files and notified_keys.comments
      end)

      assert.is_true(ok, 'all keys should be notified')
      assert.is_true(notified_keys.pr)
      assert.is_true(notified_keys.files)
      assert.is_true(notified_keys.comments)
    end)
  end)
end)

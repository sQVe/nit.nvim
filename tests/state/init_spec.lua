describe('nit.state', function()
  local state

  before_each(function()
    package.loaded['nit.state'] = nil
    package.loaded['nit.state.observers'] = nil
    package.loaded['nit.state.data'] = nil
    package.loaded['nit.state.pending'] = nil
    state = require('nit.state')
  end)

  after_each(function()
    state.reset()
    require('nit.state.observers').clear()
    require('nit.state.pending').clear()
  end)

  describe('module exports', function()
    it('exports subscribe from observers', function()
      assert.is_function(state.subscribe)
    end)

    it('exports PR functions from data', function()
      assert.is_function(state.get_pr)
      assert.is_function(state.set_pr)
    end)

    it('exports file functions from data', function()
      assert.is_function(state.get_file)
      assert.is_function(state.get_files)
      assert.is_function(state.set_files)
    end)

    it('exports thread functions from data', function()
      assert.is_function(state.get_thread)
      assert.is_function(state.get_threads)
      assert.is_function(state.set_threads)
      assert.is_function(state.get_threads_for_file)
    end)

    it('exports pending functions', function()
      assert.is_function(state.get_pending)
      assert.is_function(state.add_pending)
      assert.is_function(state.update_pending)
      assert.is_function(state.remove_pending)
    end)

    it('exports reset and load_pending', function()
      assert.is_function(state.reset)
      assert.is_function(state.load_pending)
    end)
  end)

  describe('subscribe', function()
    it('works through init module', function()
      local notified_key = nil
      state.subscribe('pr', function(key)
        notified_key = key
      end)

      state.set_pr({
        number = 1,
        title = 'Test',
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

  describe('reset', function()
    it('clears data but not pending', function()
      local persistence = require('nit.state.persistence')
      local original_save = persistence.save_pending
      local original_load = persistence.load_pending
      persistence.save_pending = function() end
      persistence.load_pending = function()
        return {}
      end

      state.set_pr({
        number = 1,
        title = 'Test',
        state = 'open',
        author = { login = 'user' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      })
      state.set_files({
        { filename = 'test.lua', status = 'added', additions = 1, deletions = 0 },
      })
      state.add_pending({
        path = 'test.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Pending comment',
      })

      state.reset()

      assert.is_nil(state.get_pr())
      assert.equals(0, #state.get_files())
      assert.equals(1, #state.get_pending())
      assert.equals('Pending comment', state.get_pending()[1].body)

      persistence.save_pending = original_save
      persistence.load_pending = original_load
    end)
  end)

  describe('end-to-end workflow', function()
    it('validates complete state workflow with observer notifications', function()
      local persistence = require('nit.state.persistence')
      local original_save = persistence.save_pending
      local original_load = persistence.load_pending
      persistence.save_pending = function() end
      persistence.load_pending = function()
        return {}
      end

      local notifications = {}
      state.subscribe('pr', function(key)
        table.insert(notifications, key)
      end)
      state.subscribe('files', function(key)
        table.insert(notifications, key)
      end)
      state.subscribe('comments', function(key)
        table.insert(notifications, key)
      end)
      state.subscribe('pending', function(key)
        table.insert(notifications, key)
      end)

      state.set_pr({
        number = 42,
        title = 'Integration Test PR',
        state = 'open',
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-02T00:00:00Z',
        mergeable = 'clean',
        isDraft = false,
      })

      local ok = vim.wait(100, function()
        return vim.tbl_contains(notifications, 'pr')
      end)
      assert.is_true(ok, 'pr notification not received')

      state.set_files({
        { filename = 'src/main.lua', status = 'modified', additions = 10, deletions = 5 },
        { filename = 'src/utils.lua', status = 'added', additions = 20, deletions = 0 },
      })

      ok = vim.wait(100, function()
        return vim.tbl_contains(notifications, 'files')
      end)
      assert.is_true(ok, 'files notification not received')

      state.set_threads({
        {
          id = 100,
          comments = {
            {
              id = 1,
              author = { login = 'reviewer' },
              body = 'Good!',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
          isResolved = false,
          path = 'src/main.lua',
          line = 5,
        },
        {
          id = 200,
          comments = {
            {
              id = 2,
              author = { login = 'reviewer' },
              body = 'Fix this',
              createdAt = '2026-01-01T13:00:00Z',
            },
          },
          isResolved = true,
          path = 'src/main.lua',
          line = 15,
        },
      })

      ok = vim.wait(100, function()
        return vim.tbl_contains(notifications, 'comments')
      end)
      assert.is_true(ok, 'comments notification not received')

      state.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'My pending comment',
      })

      ok = vim.wait(100, function()
        return vim.tbl_contains(notifications, 'pending')
      end)
      assert.is_true(ok, 'pending notification not received')

      local pr = state.get_pr()
      assert.is_not_nil(pr)
      assert.equals(42, pr.number)
      assert.equals('Integration Test PR', pr.title)

      local files = state.get_files()
      assert.equals(2, #files)

      local main_file = state.get_file('src/main.lua')
      assert.is_not_nil(main_file)
      assert.equals('modified', main_file.status)

      local threads = state.get_threads()
      assert.equals(2, #threads)

      local thread = state.get_thread(100)
      assert.is_not_nil(thread)
      assert.equals('Good!', thread.comments[1].body)

      local main_threads = state.get_threads_for_file('src/main.lua')
      assert.equals(2, #main_threads)

      local utils_threads = state.get_threads_for_file('src/utils.lua')
      assert.equals(0, #utils_threads)

      local pending_comments = state.get_pending()
      assert.equals(1, #pending_comments)
      assert.equals('My pending comment', pending_comments[1].body)

      notifications = {}
      state.reset()

      ok = vim.wait(100, function()
        return vim.tbl_contains(notifications, 'pr')
          and vim.tbl_contains(notifications, 'files')
          and vim.tbl_contains(notifications, 'comments')
      end)
      assert.is_true(ok, 'reset notifications not received')

      assert.is_nil(state.get_pr())
      assert.equals(0, #state.get_files())
      assert.equals(0, #state.get_threads())
      assert.equals(1, #state.get_pending())

      persistence.save_pending = original_save
      persistence.load_pending = original_load
    end)
  end)
end)

describe('nit.orchestration.init', function()
  local data
  local observers
  local orchestration

  local function reset_modules()
    package.loaded['nit.state.data'] = nil
    package.loaded['nit.state.observers'] = nil
    package.loaded['nit.orchestration.init'] = nil
    package.loaded['nit.orchestration.versioning'] = nil
    package.loaded['nit.orchestration.snapshot'] = nil
    package.loaded['nit.orchestration.queue'] = nil
    package.loaded['nit.api.mutations'] = nil
  end

  local function setup_with_mock(mock_mutations)
    reset_modules()
    package.loaded['nit.api.mutations'] = mock_mutations
    data = require('nit.state.data')
    observers = require('nit.state.observers')
    orchestration = require('nit.orchestration.init')
    data.clear()
    observers.clear()
  end

  local function create_test_thread(id, is_resolved)
    return {
      id = id,
      isResolved = is_resolved or false,
      isOutdated = false,
      path = 'test.lua',
      line = 10,
      startLine = 10,
      originalLine = 10,
      originalStartLine = 10,
      diffSide = 'RIGHT',
      comments = {
        {
          id = 100,
          author = { login = 'testuser' },
          body = 'Original comment',
          createdAt = '2026-01-01T00:00:00Z',
          path = 'test.lua',
          line = 10,
          side = 'RIGHT',
          start_line = 10,
          start_side = 'RIGHT',
        },
      },
    }
  end

  describe('submit_reply', function()
    it('adds optimistic comment synchronously', function()
      setup_with_mock({
        reply_to_thread = function()
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      local updated_thread = data.get_thread(1)
      assert.equals(2, #updated_thread.comments)
      assert.equals(0, updated_thread.comments[2].id)
      assert.equals('test reply', updated_thread.comments[2].body)
      assert.equals('you', updated_thread.comments[2].author.login)
    end)

    it('optimistic comment has correct structure', function()
      setup_with_mock({
        reply_to_thread = function()
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      local updated_thread = data.get_thread(1)
      local optimistic = updated_thread.comments[2]

      assert.equals(0, optimistic.id)
      assert.equals('you', optimistic.author.login)
      assert.equals('test reply', optimistic.body)
      assert.is_nil(optimistic.path)
      assert.is_nil(optimistic.line)
      assert.is_nil(optimistic.side)
      assert.is_nil(optimistic.start_line)
      assert.is_nil(optimistic.start_side)
      assert.is_not_nil(optimistic.createdAt)
    end)

    it('notifies observers of optimistic update', function()
      setup_with_mock({
        reply_to_thread = function()
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      local notified = false
      observers.subscribe('comments', function()
        notified = true
      end)

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      vim.wait(100, function()
        return notified
      end)

      assert.is_true(notified)
    end)

    it('replaces optimistic comment on success', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      assert.equals(2, #data.get_thread(1).comments)

      api_callback({
        ok = true,
        data = {
          id = 200,
          author = { login = 'realuser' },
          body = 'test reply',
          createdAt = '2026-01-01T01:00:00Z',
          path = nil,
          line = nil,
          side = nil,
          start_line = nil,
          start_side = nil,
        },
      })

      local updated_thread = data.get_thread(1)
      assert.equals(2, #updated_thread.comments)
      assert.equals(200, updated_thread.comments[2].id)
      assert.equals('realuser', updated_thread.comments[2].author.login)
    end)

    it('reverts state on failure', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      assert.equals(2, #data.get_thread(1).comments)

      api_callback({ ok = false, error = 'Network error' })

      local reverted_thread = data.get_thread(1)
      assert.equals(1, #reverted_thread.comments)
    end)

    it('calls vim.notify on failure', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      local notify_called = false
      local notify_msg = ''
      local notify_level = nil
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notify_called = true
        notify_msg = msg
        notify_level = level
      end

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      api_callback({ ok = false, error = 'Network error' })

      vim.notify = original_notify

      assert.is_true(notify_called)
      assert.equals('[nit] Reply failed: Network error', notify_msg)
      assert.equals(vim.log.levels.ERROR, notify_level)
    end)

    it('returns body on failure', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      local callback_ok = nil
      local callback_body = nil
      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function(ok, body)
        callback_ok = ok
        callback_body = body
      end)

      api_callback({ ok = false, error = 'Network error' })

      assert.is_false(callback_ok)
      assert.equals('test reply', callback_body)
    end)

    it('discards stale response', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'first' }, function() end)

      assert.equals(2, #data.get_thread(1).comments)

      local versioning = require('nit.orchestration.versioning')
      versioning.increment(1)

      api_callback({
        ok = true,
        data = {
          id = 200,
          author = { login = 'user' },
          body = 'first',
          createdAt = '2026-01-01T00:30:00Z',
          path = nil,
          line = nil,
          side = nil,
          start_line = nil,
          start_side = nil,
        },
      })

      local final_thread = data.get_thread(1)
      assert.equals(2, #final_thread.comments)
      assert.equals(0, final_thread.comments[2].id)
    end)

    it('returns false immediately for missing thread', function()
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      data.set_threads({})

      local callback_ok = nil
      local callback_body = nil
      orchestration.submit_reply({ thread_id = 999, body = 'test' }, function(ok, body)
        callback_ok = ok
        callback_body = body
      end)

      assert.is_false(callback_ok)
      assert.equals('test', callback_body)
    end)
  end)

  describe('toggle_resolved', function()
    it('flips isResolved optimistically', function()
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function()
          return function() end
        end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1, false)
      data.set_threads({ thread })

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      local updated_thread = data.get_thread(1)
      assert.is_true(updated_thread.isResolved)
    end)

    it('calls correct mutation', function()
      local resolve_called = false
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function()
          resolve_called = true
          return function() end
        end,
        unresolve_thread = function() end,
      })

      local thread_unresolved = create_test_thread(1, false)
      data.set_threads({ thread_unresolved })

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      assert.is_true(resolve_called)

      local unresolve_called = false
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function() end,
        unresolve_thread = function()
          unresolve_called = true
          return function() end
        end,
      })

      local thread_resolved = create_test_thread(2, true)
      data.set_threads({ thread_resolved })

      orchestration.toggle_resolved({ thread_id = 2 }, function() end)

      assert.is_true(unresolve_called)
    end)

    it('reverts on failure', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1, false)
      data.set_threads({ thread })

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      assert.is_true(data.get_thread(1).isResolved)

      api_callback({ ok = false, error = 'Network error' })

      assert.is_false(data.get_thread(1).isResolved)
    end)

    it('calls vim.notify on failure', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1, false)
      data.set_threads({ thread })

      local notify_msg = ''
      local original_notify = vim.notify
      vim.notify = function(msg)
        notify_msg = msg
      end

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      api_callback({ ok = false, error = 'Network error' })

      vim.notify = original_notify

      assert.equals('[nit] Resolve failed: Network error', notify_msg)
    end)
  end)

  describe('queue integration', function()
    it('serializes same-thread mutations', function()
      local callbacks = {}
      local mutation_call_count = 0
      setup_with_mock({
        reply_to_thread = function(_, callback)
          mutation_call_count = mutation_call_count + 1
          table.insert(callbacks, callback)
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'first' }, function() end)
      orchestration.submit_reply({ thread_id = 1, body = 'second' }, function() end)

      assert.equals(1, mutation_call_count)

      callbacks[1]({
        ok = true,
        data = { id = 200, author = { login = 'user' }, body = 'first', createdAt = '' },
      })

      vim.wait(50)

      assert.equals(2, mutation_call_count)
    end)
  end)

  describe('cleanup', function()
    it('resets versioning and queue', function()
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local versioning = require('nit.orchestration.versioning')
      local queue = require('nit.orchestration.queue')

      versioning.increment('test')
      queue.enqueue('test', function() end)

      orchestration.cleanup()

      assert.equals(0, versioning.get('test'))
    end)
  end)
end)

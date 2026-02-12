describe('nit.orchestration.snapshot', function()
  local snapshot = require('nit.orchestration.snapshot')
  local data = require('nit.state.data')
  local observers = require('nit.state.observers')

  after_each(function()
    data.clear()
    observers.clear()
  end)

  local function create_test_thread(id, body)
    return {
      id = id,
      comments = {
        {
          id = 1,
          author = { login = 'user' },
          body = body or 'Original comment',
          createdAt = '2026-01-01T00:00:00Z',
        },
      },
      isResolved = false,
      isOutdated = false,
      path = 'test.lua',
      line = 10,
      side = 'RIGHT',
    }
  end

  describe('capture', function()
    it('returns snapshot with deep copy of existing thread', function()
      local thread = create_test_thread('thread-1', 'Original')
      data.set_threads({ thread })

      local snap = snapshot.capture('thread-1')

      assert.is_not_nil(snap)
      assert.equals('thread-1', snap.thread_id)
      assert.is_not_nil(snap.thread)
      assert.equals('thread-1', snap.thread.id)
      assert.equals('Original', snap.thread.comments[1].body)

      thread.comments[1].body = 'Modified'
      assert.equals('Original', snap.thread.comments[1].body)
    end)

    it('returns snapshot with nil thread when thread_id does not exist', function()
      data.set_threads({ create_test_thread('other-thread') })

      local snap = snapshot.capture('nonexistent')

      assert.is_not_nil(snap)
      assert.equals('nonexistent', snap.thread_id)
      assert.is_nil(snap.thread)
    end)

    it('returns nil when thread_id is nil', function()
      local snap = snapshot.capture(nil)
      assert.is_nil(snap)
    end)
  end)

  describe('restore', function()
    it('reverts a modified thread back to its captured state', function()
      local original_thread = create_test_thread('thread-1', 'Original')
      data.set_threads({ original_thread })

      local snap = snapshot.capture('thread-1')

      local all_threads = data.get_threads()
      all_threads[1].comments[1].body = 'Modified'
      data.set_threads(all_threads)

      assert.equals('Modified', data.get_thread('thread-1').comments[1].body)

      snapshot.restore(snap)

      local restored = data.get_thread('thread-1')
      assert.is_not_nil(restored)
      assert.equals('Original', restored.comments[1].body)
    end)

    it('removes a thread that did not exist at capture time', function()
      local snap = snapshot.capture('new-thread')

      data.set_threads({ create_test_thread('new-thread') })
      assert.is_not_nil(data.get_thread('new-thread'))

      snapshot.restore(snap)

      assert.is_nil(data.get_thread('new-thread'))
    end)

    it('re-adds a thread that was removed after capture', function()
      local thread = create_test_thread('thread-1')
      data.set_threads({ thread })

      local snap = snapshot.capture('thread-1')

      data.set_threads({})
      assert.is_nil(data.get_thread('thread-1'))

      snapshot.restore(snap)

      local restored = data.get_thread('thread-1')
      assert.is_not_nil(restored)
      assert.equals('thread-1', restored.id)
    end)

    it('triggers observer notification', function()
      local thread = create_test_thread('thread-1', 'Original')
      data.set_threads({ thread })

      local snap = snapshot.capture('thread-1')

      local notified = false
      observers.subscribe('comments', function()
        notified = true
      end)

      snapshot.restore(snap)

      local ok = vim.wait(100, function()
        return notified
      end)

      assert.is_true(ok, 'observer was not notified')
      assert.is_true(notified)
    end)
  end)

  describe('snapshot isolation', function()
    it('is isolated from subsequent state changes', function()
      local thread = create_test_thread('thread-1', 'Original')
      data.set_threads({ thread })

      local snap = snapshot.capture('thread-1')

      local all_threads = data.get_threads()
      all_threads[1].comments[1].body = 'Modified'
      data.set_threads(all_threads)

      assert.equals('Original', snap.thread.comments[1].body)
      assert.equals('Modified', data.get_thread('thread-1').comments[1].body)
    end)
  end)
end)

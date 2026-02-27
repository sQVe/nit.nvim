describe('nit.orchestration.init', function()
  local data
  local observers
  local orchestration
  local original_notify = vim.notify

  after_each(function()
    vim.notify = original_notify
  end)

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
      assert.are.equal(2, #updated_thread.comments)
      assert.are.equal(0, updated_thread.comments[2].id)
      assert.are.equal('test reply', updated_thread.comments[2].body)
      assert.are.equal('you', updated_thread.comments[2].author.login)
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

      assert.are.equal(0, optimistic.id)
      assert.are.equal('you', optimistic.author.login)
      assert.are.equal('test reply', optimistic.body)
      assert.is_nil(optimistic.path)
      assert.is_nil(optimistic.line)
      assert.is_nil(optimistic.side)
      assert.is_nil(optimistic.start_line)
      assert.is_nil(optimistic.start_side)
      assert.is_not_nil(optimistic.createdAt)
    end)

    it('uses viewer login for optimistic comment author when set', function()
      setup_with_mock({
        reply_to_thread = function()
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      data.set_viewer_login('octocat')
      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      local updated_thread = data.get_thread(1)
      assert.are.equal('octocat', updated_thread.comments[2].author.login)
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

      assert.are.equal(2, #data.get_thread(1).comments)

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
      assert.are.equal(2, #updated_thread.comments)
      assert.are.equal(200, updated_thread.comments[2].id)
      assert.are.equal('realuser', updated_thread.comments[2].author.login)
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

      assert.are.equal(2, #data.get_thread(1).comments)

      api_callback({ ok = false, error = 'Network error' })

      local reverted_thread = data.get_thread(1)
      assert.are.equal(1, #reverted_thread.comments)
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
      vim.notify = function(msg, level)
        notify_called = true
        notify_msg = msg
        notify_level = level
      end

      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function() end)

      api_callback({ ok = false, error = 'Network error' })

      assert.is_true(notify_called)
      assert.are.equal('[nit] Reply failed: Network error', notify_msg)
      assert.are.equal(vim.log.levels.ERROR, notify_level)
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
      assert.are.equal('test reply', callback_body)
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

      assert.are.equal(2, #data.get_thread(1).comments)

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
      assert.are.equal(2, #final_thread.comments)
      assert.are.equal(0, final_thread.comments[2].id)
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
      assert.are.equal('test', callback_body)
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
      vim.notify = function(msg)
        notify_msg = msg
      end

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      api_callback({ ok = false, error = 'Network error' })

      assert.are.equal('[nit] Resolve failed: Network error', notify_msg)
    end)

    it('returns false immediately for missing thread', function()
      local mutation_called = false
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function()
          mutation_called = true
          return function() end
        end,
        unresolve_thread = function()
          mutation_called = true
          return function() end
        end,
      })

      data.set_threads({})

      local callback_ok = nil
      orchestration.toggle_resolved({ thread_id = 999 }, function(ok)
        callback_ok = ok
      end)

      assert.is_false(callback_ok)
      assert.is_false(mutation_called)
    end)

    it('discards stale response', function()
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

      local callback_ok = nil
      orchestration.toggle_resolved({ thread_id = 1 }, function(ok)
        callback_ok = ok
      end)

      assert.is_true(data.get_thread(1).isResolved)

      local versioning = require('nit.orchestration.versioning')
      versioning.increment(1)

      api_callback({ ok = true })

      assert.is_false(callback_ok)
    end)

    it('shows Unresolve in notify when unresolve fails', function()
      local api_callback
      setup_with_mock({
        reply_to_thread = function() end,
        resolve_thread = function() end,
        unresolve_thread = function(_, callback)
          api_callback = callback
          return function() end
        end,
      })

      local thread = create_test_thread(1, true)
      data.set_threads({ thread })

      local notify_msg = ''
      vim.notify = function(msg)
        notify_msg = msg
      end

      orchestration.toggle_resolved({ thread_id = 1 }, function() end)

      api_callback({ ok = false, error = 'Network error' })

      assert.are.equal('[nit] Unresolve failed: Network error', notify_msg)
    end)
  end)

  describe('submit_reply edge cases', function()
    it('succeeds without crash when thread is deleted before success response', function()
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
      orchestration.submit_reply({ thread_id = 1, body = 'test reply' }, function(ok)
        callback_ok = ok
      end)

      data.set_threads({})

      api_callback({
        ok = true,
        data = {
          id = 200,
          author = { login = 'user' },
          body = 'test reply',
          createdAt = '2026-01-01T01:00:00Z',
        },
      })

      assert.is_true(callback_ok)
    end)

    it('shows unknown error when error message is nil', function()
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

      local notify_msg = ''
      vim.notify = function(msg)
        notify_msg = msg
      end

      orchestration.submit_reply({ thread_id = 1, body = 'test' }, function() end)

      api_callback({ ok = false })

      assert.are.equal('[nit] Reply failed: unknown error', notify_msg)
    end)

    it('replaces only first optimistic comment when multiple exist', function()
      local api_callbacks = {}
      setup_with_mock({
        reply_to_thread = function(_, callback)
          table.insert(api_callbacks, callback)
          return function() end
        end,
        resolve_thread = function() end,
        unresolve_thread = function() end,
      })

      local thread = create_test_thread(1)
      data.set_threads({ thread })

      orchestration.submit_reply({ thread_id = 1, body = 'first' }, function() end)

      local after_first = data.get_thread(1)
      local updated = vim.deepcopy(after_first)
      table.insert(updated.comments, {
        id = 0,
        author = { login = 'you' },
        body = 'second',
        createdAt = '2026-01-01T00:01:00Z',
      })
      data.set_threads({ updated })

      api_callbacks[1]({
        ok = true,
        data = {
          id = 200,
          author = { login = 'user' },
          body = 'first',
          createdAt = '2026-01-01T01:00:00Z',
        },
      })

      local final_thread = data.get_thread(1)
      assert.are.equal(200, final_thread.comments[2].id)
      assert.are.equal(0, final_thread.comments[3].id)
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

      assert.are.equal(1, mutation_call_count)

      callbacks[1]({
        ok = true,
        data = { id = 200, author = { login = 'user' }, body = 'first', createdAt = '' },
      })

      local after_first = data.get_thread(1)
      assert.are.equal(200, after_first.comments[2].id)
      assert.are.equal(0, after_first.comments[3].id)

      vim.wait(50)

      assert.are.equal(2, mutation_call_count)

      callbacks[2]({
        ok = true,
        data = { id = 201, author = { login = 'user' }, body = 'second', createdAt = '' },
      })

      local after_second = data.get_thread(1)
      assert.are.equal(200, after_second.comments[2].id)
      assert.are.equal(201, after_second.comments[3].id)
    end)
  end)

  local function make_mock_mutations(opts)
    opts = opts or {}
    return {
      reply_to_thread = opts.reply_to_thread or function()
        return function() end
      end,
      resolve_thread = opts.resolve_thread or function()
        return function() end
      end,
      unresolve_thread = opts.unresolve_thread or function()
        return function() end
      end,
      update_comment = opts.update_comment or function()
        return function() end
      end,
      add_reaction = opts.add_reaction or function()
        return function() end
      end,
      remove_reaction = opts.remove_reaction or function()
        return function() end
      end,
    }
  end

  local function create_thread_with_reactions(id, reactions)
    return {
      id = id,
      isResolved = false,
      isOutdated = false,
      path = 'test.lua',
      line = 10,
      comments = {
        {
          id = 100,
          node_id = 'PRRC_abc123',
          author = { login = 'testuser' },
          body = 'Test comment',
          createdAt = '2026-01-01T00:00:00Z',
          path = 'test.lua',
          line = 10,
          side = 'RIGHT',
          start_line = nil,
          start_side = nil,
          reactions = reactions or {},
        },
      },
    }
  end

  describe('toggle_reaction', function()
    it('applies optimistic update before API call returns', function()
      local api_called = false
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, _)
          api_called = true
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {
        { content = 'THUMBS_UP', count = 2, viewer_has_reacted = false },
      })
      data.set_threads({ thread })

      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function() end)

      assert.is_true(api_called)
      local updated = data.get_thread(1)
      local rg = updated.comments[1].reactions[1]
      assert.are.equal('THUMBS_UP', rg.content)
      assert.are.equal(3, rg.count)
      assert.is_true(rg.viewer_has_reacted)
    end)

    it('calls add_reaction when viewer has not reacted', function()
      local called_opts = nil
      setup_with_mock(make_mock_mutations({
        add_reaction = function(opts, _)
          called_opts = opts
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {
        { content = 'HEART', count = 1, viewer_has_reacted = false },
      })
      data.set_threads({ thread })

      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'HEART' }, function() end)

      assert.is_not_nil(called_opts)
      assert.are.equal('PRRC_abc123', called_opts.node_id)
      assert.are.equal('HEART', called_opts.content)
    end)

    it('calls remove_reaction when viewer has already reacted', function()
      local called_fn = nil
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, _)
          called_fn = 'add'
          return function() end
        end,
        remove_reaction = function(_, _)
          called_fn = 'remove'
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {
        { content = 'THUMBS_UP', count = 3, viewer_has_reacted = true },
      })
      data.set_threads({ thread })

      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function() end)

      assert.are.equal('remove', called_fn)
      local updated = data.get_thread(1)
      local rg = updated.comments[1].reactions[1]
      assert.are.equal(2, rg.count)
      assert.is_false(rg.viewer_has_reacted)
    end)

    it('creates new reaction group when content not in reactions', function()
      local api_called = false
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, _)
          api_called = true
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {})
      data.set_threads({ thread })

      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'ROCKET' }, function() end)

      assert.is_true(api_called)
      local updated = data.get_thread(1)
      local reactions = updated.comments[1].reactions
      assert.are.equal(1, #reactions)
      assert.are.equal('ROCKET', reactions[1].content)
      assert.are.equal(1, reactions[1].count)
      assert.is_true(reactions[1].viewer_has_reacted)
    end)

    it('updates reactions from server response on success', function()
      local api_callback = nil
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, cb)
          api_callback = cb
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {
        { content = 'THUMBS_UP', count = 0, viewer_has_reacted = false },
      })
      data.set_threads({ thread })

      local callback_result = nil
      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function(ok)
        callback_result = ok
      end)

      local server_reactions = {
        { content = 'THUMBS_UP', count = 5, viewer_has_reacted = true },
        { content = 'HEART', count = 2, viewer_has_reacted = false },
      }
      api_callback({ ok = true, data = server_reactions })

      assert.is_true(callback_result)
      local updated = data.get_thread(1)
      assert.are.equal(2, #updated.comments[1].reactions)
      assert.are.equal(5, updated.comments[1].reactions[1].count)
      assert.are.equal('HEART', updated.comments[1].reactions[2].content)
    end)

    it('restores snapshot and notifies on failure', function()
      local api_callback = nil
      local notified = nil
      vim.notify = function(msg, _)
        notified = msg
      end
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, cb)
          api_callback = cb
          return function() end
        end,
      }))

      local original_reactions = { { content = 'THUMBS_UP', count = 1, viewer_has_reacted = false } }
      local thread = create_thread_with_reactions(1, vim.deepcopy(original_reactions))
      data.set_threads({ thread })

      local callback_result = nil
      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function(ok)
        callback_result = ok
      end)

      api_callback({ ok = false, error = 'server error' })

      assert.is_false(callback_result)
      local restored = data.get_thread(1)
      assert.are.equal(1, restored.comments[1].reactions[1].count)
      assert.is_false(restored.comments[1].reactions[1].viewer_has_reacted)
      assert.is_not_nil(notified)
      assert.is_true(notified:find('React failed') ~= nil)
    end)

    it('calls callback(false) when thread not found', function()
      setup_with_mock(make_mock_mutations())

      local result = nil
      orchestration.toggle_reaction({ thread_id = 999, comment_idx = 1, content = 'THUMBS_UP' }, function(ok)
        result = ok
      end)

      assert.is_false(result)
    end)

    it('calls callback(false) when comment_idx is out of bounds', function()
      setup_with_mock(make_mock_mutations())

      local thread = create_thread_with_reactions(1, {})
      data.set_threads({ thread })

      local result = nil
      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 99, content = 'THUMBS_UP' }, function(ok)
        result = ok
      end)

      assert.is_false(result)
    end)

    it('calls callback(false) when comment has no node_id', function()
      local add_called = false
      setup_with_mock(make_mock_mutations({
        add_reaction = function(_, _)
          add_called = true
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {})
      thread.comments[1].node_id = nil
      data.set_threads({ thread })

      local result = nil
      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function(ok)
        result = ok
      end)

      assert.is_false(result)
      assert.is_false(add_called)
    end)

    it('floors optimistic count at 0 when count is already 0', function()
      local api_callback = nil
      setup_with_mock(make_mock_mutations({
        remove_reaction = function(_, cb)
          api_callback = cb
          return function() end
        end,
      }))

      local thread = create_thread_with_reactions(1, {
        { content = 'THUMBS_UP', count = 0, viewer_has_reacted = true },
      })
      data.set_threads({ thread })

      orchestration.toggle_reaction({ thread_id = 1, comment_idx = 1, content = 'THUMBS_UP' }, function() end)

      local updated = data.get_thread(1)
      assert.are.equal(0, updated.comments[1].reactions[1].count)
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

      assert.are.equal(0, versioning.get('test'))
    end)
  end)
end)

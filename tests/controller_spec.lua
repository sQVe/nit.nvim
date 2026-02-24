describe('nit.controller', function()
  local controller

  before_each(function()
    package.loaded['nit.controller'] = nil
    package.loaded['nit.api.pr'] = nil
    package.loaded['nit.api.files'] = nil
    package.loaded['nit.api.comments'] = nil
    package.loaded['nit.api.parallel'] = nil
    package.loaded['nit.api.tracker'] = nil
    package.loaded['nit.api.viewer'] = nil
    package.loaded['nit.state.data'] = nil

    package.loaded['nit.api.pr'] = {
      fetch_pr = function(_opts, callback)
        callback({ ok = true, data = { number = 1 } })
        return function() end
      end,
    }

    package.loaded['nit.api.files'] = {
      fetch_files = function() end,
    }

    package.loaded['nit.api.comments'] = {
      fetch_comments = function() end,
    }

    package.loaded['nit.api.parallel'] = {
      parallel = function()
        return function() end
      end,
    }

    package.loaded['nit.api.tracker'] = {
      cancel_all = function() end,
    }

    package.loaded['nit.api.viewer'] = {
      fetch_viewer = function(_opts, callback)
        callback({ ok = true, data = 'octocat' })
        return function() end
      end,
    }

    package.loaded['nit.state.data'] = {
      set_loading = function() end,
      set_error = function() end,
      set_pr = function() end,
      set_comments = function() end,
      set_files = function() end,
      set_threads = function() end,
      set_viewer_login = function() end,
      clear = function() end,
    }

    controller = require('nit.controller')
  end)

  after_each(function()
    package.loaded['nit.controller'] = nil
    package.loaded['nit.api.pr'] = nil
    package.loaded['nit.api.files'] = nil
    package.loaded['nit.api.comments'] = nil
    package.loaded['nit.api.parallel'] = nil
    package.loaded['nit.api.tracker'] = nil
    package.loaded['nit.api.viewer'] = nil
    package.loaded['nit.state.data'] = nil
  end)

  describe('load', function()
    it('sets loading=true before fetching', function()
      local data = require('nit.state.data')

      local loading_calls = {}
      data.set_loading = function(value)
        table.insert(loading_calls, value)
      end

      controller.load()

      assert.equals(true, loading_calls[1])
    end)

    it('fetches PR first then files+comments in parallel', function()
      local pr_api = require('nit.api.pr')
      local files_api = require('nit.api.files')
      local comments_api = require('nit.api.comments')
      local parallel_api = require('nit.api.parallel')

      local fetch_pr_called = false
      local parallel_ops = nil

      pr_api.fetch_pr = function(_opts, callback)
        fetch_pr_called = true
        callback({ ok = true, data = { number = 42 } })
        return function() end
      end

      parallel_api.parallel = function(ops, _callback)
        parallel_ops = ops
        return function() end
      end

      controller.load()

      assert.is_true(fetch_pr_called)
      assert.is_not_nil(parallel_ops)
      assert.equals(2, #parallel_ops)
      assert.equals(files_api.fetch_files, parallel_ops[1].fn)
      assert.equals(comments_api.fetch_comments, parallel_ops[2].fn)
    end)

    it('passes PR number to files and comments', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')

      local parallel_ops = nil
      pr_api.fetch_pr = function(_opts, callback)
        callback({ ok = true, data = { number = 99 } })
        return function() end
      end

      parallel_api.parallel = function(ops, _callback)
        parallel_ops = ops
        return function() end
      end

      controller.load()

      assert.equals(99, parallel_ops[1].args.number)
      assert.equals(99, parallel_ops[2].args.number)
    end)

    it('on all success: populates state and sets loading=false', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')
      local data = require('nit.state.data')

      local parallel_callback = nil
      pr_api.fetch_pr = function(_opts, callback)
        callback({ ok = true, data = { number = 123 } })
        return function() end
      end

      parallel_api.parallel = function(_ops, callback)
        parallel_callback = callback
        return function() end
      end

      local state_calls = {}
      data.set_pr = function(d)
        table.insert(state_calls, { fn = 'set_pr', data = d })
      end
      data.set_files = function(d)
        table.insert(state_calls, { fn = 'set_files', data = d })
      end
      data.set_threads = function(d)
        table.insert(state_calls, { fn = 'set_threads', data = d })
      end
      data.set_loading = function(value)
        table.insert(state_calls, { fn = 'set_loading', value = value })
      end

      controller.load()

      local files_data = { { filename = 'test.lua' } }
      local threads_data = { { id = 1 } }

      parallel_callback({
        { ok = true, data = files_data },
        { ok = true, data = threads_data },
      })

      local set_pr_found = false
      local set_files_found = false
      local set_threads_found = false
      local set_loading_false = false

      for _, call in ipairs(state_calls) do
        if call.fn == 'set_pr' then
          set_pr_found = true
        end
        if call.fn == 'set_files' and call.data == files_data then
          set_files_found = true
        end
        if call.fn == 'set_threads' and call.data == threads_data then
          set_threads_found = true
        end
        if call.fn == 'set_loading' and call.value == false then
          set_loading_false = true
        end
      end

      assert.is_true(set_pr_found, 'set_pr should be called with pr data')
      assert.is_true(set_files_found, 'set_files should be called with files data')
      assert.is_true(set_threads_found, 'set_threads should be called with threads data')
      assert.is_true(set_loading_false, 'set_loading(false) should be called')
    end)

    it('on PR failure: sets error without fetching files/comments', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')
      local data = require('nit.state.data')

      local parallel_called = false
      pr_api.fetch_pr = function(_opts, callback)
        callback({ ok = false, error = 'PR failed' })
        return function() end
      end

      parallel_api.parallel = function()
        parallel_called = true
        return function() end
      end

      local error_msg = nil
      local loading_false = false
      data.set_error = function(msg)
        error_msg = msg
      end
      data.set_loading = function(value)
        if value == false then
          loading_false = true
        end
      end

      controller.load()

      assert.is_false(parallel_called, 'should not fetch files/comments when PR fails')
      assert.equals('PR failed', error_msg)
      assert.is_true(loading_false)
    end)

    it('on partial failure: populates successful results and sets error', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')
      local data = require('nit.state.data')

      local parallel_callback = nil
      pr_api.fetch_pr = function(_opts, callback)
        callback({ ok = true, data = { number = 123 } })
        return function() end
      end

      parallel_api.parallel = function(_ops, callback)
        parallel_callback = callback
        return function() end
      end

      local state_calls = {}
      data.set_pr = function(d)
        table.insert(state_calls, { fn = 'set_pr', data = d })
      end
      data.set_files = function(d)
        table.insert(state_calls, { fn = 'set_files', data = d })
      end
      data.set_threads = function()
        table.insert(state_calls, { fn = 'set_threads' })
      end
      data.set_error = function(msg)
        table.insert(state_calls, { fn = 'set_error', msg = msg })
      end
      data.set_loading = function() end

      controller.load()

      local files_data = { { filename = 'test.lua' } }
      parallel_callback({
        { ok = true, data = files_data },
        { ok = false, error = 'Comments fetch failed' },
      })

      local set_files_found = false
      local set_error_found = false

      for _, call in ipairs(state_calls) do
        if call.fn == 'set_files' and call.data == files_data then
          set_files_found = true
        end
        if call.fn == 'set_error' and call.msg then
          set_error_found = true
          assert.is_truthy(call.msg:match('Comments fetch failed'))
        end
      end

      assert.is_true(set_files_found, 'set_files should be called with successful data')
      assert.is_true(set_error_found, 'set_error should be called with error message')
    end)

    it('cancels previous in-flight load before starting new one', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')

      local first_pr_cancel = 0
      local first_rest_cancel = 0

      local call_count = 0
      pr_api.fetch_pr = function(_opts, callback)
        call_count = call_count + 1
        if call_count == 1 then
          return function()
            first_pr_cancel = first_pr_cancel + 1
          end
        end
        callback({ ok = true, data = { number = 1 } })
        return function() end
      end

      parallel_api.parallel = function()
        return function()
          first_rest_cancel = first_rest_cancel + 1
        end
      end

      controller.load()
      controller.load()

      assert.equals(1, first_pr_cancel, 'first PR fetch should be cancelled')
    end)

    it('ignores stale callback from superseded load', function()
      local pr_api = require('nit.api.pr')
      local data = require('nit.state.data')

      local pr_callbacks = {}
      pr_api.fetch_pr = function(_opts, callback)
        table.insert(pr_callbacks, callback)
        return function() end
      end

      local set_pr_count = 0
      data.set_pr = function()
        set_pr_count = set_pr_count + 1
      end
      data.set_loading = function() end

      controller.load()
      controller.load()

      assert.equals(2, #pr_callbacks)

      pr_callbacks[1]({ ok = true, data = { number = 1 } })
      assert.equals(0, set_pr_count, 'stale callback should be ignored')

      pr_callbacks[2]({ ok = true, data = { number = 2 } })
      assert.equals(1, set_pr_count, 'active callback should populate state')
    end)

    it('clears error on new load attempt', function()
      local data = package.loaded['nit.state.data']

      local set_error_value = 'not_called'
      data.set_error = function(value)
        set_error_value = value
      end

      controller.load()

      assert.is_nil(set_error_value, 'error should be cleared (set to nil)')
    end)

    it('fetches viewer login and stores it in state', function()
      local viewer_api = require('nit.api.viewer')
      local data = require('nit.state.data')

      local viewer_login_stored = nil
      viewer_api.fetch_viewer = function(_opts, callback)
        callback({ ok = true, data = 'octocat' })
        return function() end
      end
      data.set_viewer_login = function(login)
        viewer_login_stored = login
      end

      controller.load()

      assert.equals('octocat', viewer_login_stored)
    end)

    it('silently degrades when viewer fetch fails', function()
      local viewer_api = require('nit.api.viewer')
      local data = require('nit.state.data')

      local error_set = false
      viewer_api.fetch_viewer = function(_opts, callback)
        callback({ ok = false, error = 'Not authenticated' })
        return function() end
      end
      data.set_error = function(msg)
        if msg ~= nil then
          error_set = true
        end
      end

      controller.load()

      assert.is_false(error_set, 'viewer failure should not set error state')
    end)
  end)

  describe('cleanup', function()
    it('cancels in-flight requests if load is in progress', function()
      local pr_api = require('nit.api.pr')

      local pr_cancel_count = 0
      pr_api.fetch_pr = function()
        return function()
          pr_cancel_count = pr_cancel_count + 1
        end
      end

      controller.load()
      controller.cleanup()

      assert.equals(1, pr_cancel_count)
    end)

    it('calls tracker.cancel_all', function()
      local tracker = require('nit.api.tracker')

      local cancel_all_called = false
      tracker.cancel_all = function()
        cancel_all_called = true
      end

      controller.cleanup()

      assert.is_true(cancel_all_called)
    end)

    it('calls data.clear', function()
      local data = require('nit.state.data')

      local clear_called = false
      data.clear = function()
        clear_called = true
      end

      controller.cleanup()

      assert.is_true(clear_called)
    end)

    it('cancels in-flight viewer fetch', function()
      local viewer_api = require('nit.api.viewer')

      local viewer_cancel_count = 0
      viewer_api.fetch_viewer = function()
        return function()
          viewer_cancel_count = viewer_cancel_count + 1
        end
      end

      controller.load()
      controller.cleanup()

      assert.equals(1, viewer_cancel_count)
    end)
  end)

  describe('refresh', function()
    it('calls cleanup then load', function()
      local pr_api = require('nit.api.pr')
      local parallel_api = require('nit.api.parallel')
      local tracker = require('nit.api.tracker')
      local data = require('nit.state.data')

      local call_order = {}

      data.clear = function()
        table.insert(call_order, 'clear')
      end

      tracker.cancel_all = function()
        table.insert(call_order, 'cancel_all')
      end

      data.set_loading = function()
        table.insert(call_order, 'set_loading')
      end

      pr_api.fetch_pr = function(_opts, callback)
        table.insert(call_order, 'fetch_pr')
        callback({ ok = true, data = { number = 1 } })
        return function() end
      end

      parallel_api.parallel = function()
        table.insert(call_order, 'parallel')
        return function() end
      end

      data.set_error = function()
        table.insert(call_order, 'set_error')
      end

      data.set_pr = function() end

      controller.refresh()

      assert.is_true(#call_order >= 3, 'should call multiple functions')

      local clear_idx = nil
      local fetch_pr_idx = nil
      for i, name in ipairs(call_order) do
        if name == 'clear' then
          clear_idx = i
        end
        if name == 'fetch_pr' then
          fetch_pr_idx = i
        end
      end

      assert.is_not_nil(clear_idx, 'clear should be called')
      assert.is_not_nil(fetch_pr_idx, 'fetch_pr should be called')
      assert.is_true(clear_idx < fetch_pr_idx, 'clear should be called before fetch_pr')
    end)
  end)
end)

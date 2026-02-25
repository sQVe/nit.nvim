describe('review', function()
  local review

  local controller_mock = {}
  local display_manager_mock = {}
  local observers_mock = {}
  local thread_panel_mock = {}

  local api_mock = {
    buf_names = {},
    buf_types = {},
    bufs = {},
    loaded_bufs = {},
  }

  local fn_mock = {
    git_succeeds = true,
    systemlist_result = {},
    systemlist_call_count = 0,
  }

  local autocmd_callbacks = {}
  local autocmd_next_id = 1

  local orig_vim = {}

  local function find_autocmd_callback(event)
    local max_id = 0
    local result = nil
    for id, entry in pairs(autocmd_callbacks) do
      if entry.event == event and id > max_id then
        max_id = id
        result = entry.opts.callback
      end
    end
    return result
  end

  before_each(function()
    autocmd_callbacks = {}
    autocmd_next_id = 1
    api_mock.buf_names = {}
    api_mock.buf_types = {}
    api_mock.bufs = {}
    api_mock.loaded_bufs = {}
    fn_mock.git_succeeds = true
    fn_mock.systemlist_result = { '/repo' }
    fn_mock.systemlist_call_count = 0

    controller_mock.load_calls = 0
    controller_mock.cleanup_calls = 0
    controller_mock.load = function()
      controller_mock.load_calls = controller_mock.load_calls + 1
    end
    controller_mock.cleanup = function()
      controller_mock.cleanup_calls = controller_mock.cleanup_calls + 1
    end

    display_manager_mock.setup_calls = 0
    display_manager_mock.attach_calls = {}
    display_manager_mock.detach_all_calls = 0
    display_manager_mock.setup = function()
      display_manager_mock.setup_calls = display_manager_mock.setup_calls + 1
    end
    display_manager_mock.attach = function(bufnr, filepath)
      table.insert(display_manager_mock.attach_calls, { bufnr = bufnr, filepath = filepath })
    end
    display_manager_mock.detach_all = function()
      display_manager_mock.detach_all_calls = display_manager_mock.detach_all_calls + 1
    end

    observers_mock.subscribe_calls = {}
    observers_mock.subscribe = function(event, callback)
      local entry = { event = event, callback = callback, unsubscribed = false }
      table.insert(observers_mock.subscribe_calls, entry)
      return function()
        entry.unsubscribed = true
      end
    end

    thread_panel_mock.close_calls = 0
    thread_panel_mock.close = function()
      thread_panel_mock.close_calls = thread_panel_mock.close_calls + 1
    end

    package.loaded['nit.controller'] = controller_mock
    package.loaded['nit.display.manager'] = display_manager_mock
    package.loaded['nit.state.observers'] = observers_mock
    package.loaded['nit.display.thread_panel'] = thread_panel_mock

    orig_vim.nvim_create_augroup = vim.api.nvim_create_augroup
    orig_vim.nvim_create_autocmd = vim.api.nvim_create_autocmd
    orig_vim.nvim_list_bufs = vim.api.nvim_list_bufs
    orig_vim.nvim_buf_is_loaded = vim.api.nvim_buf_is_loaded
    orig_vim.nvim_buf_get_name = vim.api.nvim_buf_get_name
    orig_vim.bo = vim.bo

    vim.api.nvim_create_augroup = function(name, _)
      return name
    end

    vim.api.nvim_create_autocmd = function(event, opts)
      local id = autocmd_next_id
      autocmd_next_id = autocmd_next_id + 1
      autocmd_callbacks[id] = { event = event, opts = opts }
      return id
    end

    vim.api.nvim_list_bufs = function()
      return api_mock.bufs
    end

    vim.api.nvim_buf_is_loaded = function(bufnr)
      return api_mock.loaded_bufs[bufnr] == true
    end

    vim.api.nvim_buf_get_name = function(bufnr)
      return api_mock.buf_names[bufnr] or ''
    end

    vim.bo = setmetatable({}, {
      __index = function(_, bufnr)
        return { buftype = api_mock.buf_types[bufnr] or '' }
      end,
    })

    vim.fn.systemlist = function(_cmd)
      fn_mock.systemlist_call_count = fn_mock.systemlist_call_count + 1
      if fn_mock.git_succeeds then
        vim.fn.system('true')
      else
        vim.fn.system('false')
      end
      return fn_mock.systemlist_result
    end

    package.loaded['nit.review'] = nil
    review = require('nit.review')
  end)

  after_each(function()
    vim.api.nvim_create_augroup = orig_vim.nvim_create_augroup
    vim.api.nvim_create_autocmd = orig_vim.nvim_create_autocmd
    vim.api.nvim_list_bufs = orig_vim.nvim_list_bufs
    vim.api.nvim_buf_is_loaded = orig_vim.nvim_buf_is_loaded
    vim.api.nvim_buf_get_name = orig_vim.nvim_buf_get_name
    vim.bo = orig_vim.bo
    vim.fn.systemlist = nil

    package.loaded['nit.controller'] = nil
    package.loaded['nit.display.manager'] = nil
    package.loaded['nit.state.observers'] = nil
    package.loaded['nit.display.thread_panel'] = nil
    package.loaded['nit.review'] = nil
  end)

  describe('is_active', function()
    it('returns false before start', function()
      assert.is_false(review.is_active())
    end)

    it('returns true after start', function()
      review.start()

      assert.is_true(review.is_active())
    end)

    it('returns false after stop', function()
      review.start()
      review.stop()

      assert.is_false(review.is_active())
    end)
  end)

  describe('start', function()
    it('is no-op when already active', function()
      review.start()
      local load_count = controller_mock.load_calls

      review.start()

      assert.are.equal(load_count, controller_mock.load_calls)
    end)

    it('calls display_manager.setup', function()
      review.start()

      assert.are.equal(1, display_manager_mock.setup_calls)
    end)

    it('subscribes to comments observer', function()
      review.start()

      assert.are.equal(1, #observers_mock.subscribe_calls)
      assert.are.equal('comments', observers_mock.subscribe_calls[1].event)
    end)

    it('calls controller.load', function()
      review.start()

      assert.are.equal(1, controller_mock.load_calls)
    end)

    it('observer unsubscribes itself after first fire', function()
      review.start()

      local observer = observers_mock.subscribe_calls[1]
      observer.callback()

      assert.is_true(observer.unsubscribed)
    end)

    it('observer attaches loaded buffers on fire', function()
      api_mock.bufs = { 1, 2 }
      api_mock.loaded_bufs = { [1] = true, [2] = false }
      api_mock.buf_names = { [1] = '/repo/src/file.lua' }
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }

      review.start()

      local observer = observers_mock.subscribe_calls[1]
      observer.callback()

      assert.are.equal(1, #display_manager_mock.attach_calls)
      assert.are.equal(1, display_manager_mock.attach_calls[1].bufnr)
      assert.are.equal('src/file.lua', display_manager_mock.attach_calls[1].filepath)
    end)
  end)

  describe('stop', function()
    it('is no-op when not active', function()
      review.stop()

      assert.are.equal(0, controller_mock.cleanup_calls)
    end)

    it('calls display_manager.detach_all', function()
      review.start()

      review.stop()

      assert.are.equal(1, display_manager_mock.detach_all_calls)
    end)

    it('calls thread_panel.close', function()
      review.start()

      review.stop()

      assert.are.equal(1, thread_panel_mock.close_calls)
    end)

    it('calls controller.cleanup', function()
      review.start()

      review.stop()

      assert.are.equal(1, controller_mock.cleanup_calls)
    end)

    it('unsubscribes observer if not yet fired', function()
      review.start()
      local observer = observers_mock.subscribe_calls[1]

      review.stop()

      assert.is_true(observer.unsubscribed)
    end)

    it('resets git state between sessions', function()
      fn_mock.git_succeeds = false
      review.start()

      local callback = find_autocmd_callback('BufEnter')
      api_mock.buf_names = { [1] = '/repo/file.lua' }
      callback({ buf = 1 })
      assert.are.equal(0, #display_manager_mock.attach_calls)

      review.stop()

      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      fn_mock.systemlist_call_count = 0
      review.start()

      callback = find_autocmd_callback('BufEnter')
      api_mock.buf_names = { [1] = '/repo/file.lua' }
      callback({ buf = 1 })
      assert.are.equal(1, #display_manager_mock.attach_calls)
    end)
  end)

  describe('try_attach_buffer', function()
    it('skips buffers with empty name', function()
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '' }
      callback({ buf = 1 })

      assert.are.same({}, display_manager_mock.attach_calls)
    end)

    it('skips buffers with non-empty buftype', function()
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo/file.lua' }
      api_mock.buf_types = { [1] = 'nofile' }
      callback({ buf = 1 })

      assert.are.same({}, display_manager_mock.attach_calls)
    end)

    it('skips without running git when git root previously failed', function()
      fn_mock.git_succeeds = false
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo/file.lua' }
      callback({ buf = 1 })
      local first_call_count = fn_mock.systemlist_call_count

      api_mock.buf_names = { [2] = '/repo/other.lua' }
      callback({ buf = 2 })

      assert.are.equal(first_call_count, fn_mock.systemlist_call_count)
    end)

    it('caches git root across buffer attaches', function()
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo/a.lua' }
      callback({ buf = 1 })
      local first_call_count = fn_mock.systemlist_call_count

      api_mock.buf_names = { [2] = '/repo/b.lua' }
      callback({ buf = 2 })

      assert.are.equal(first_call_count, fn_mock.systemlist_call_count)
    end)

    it('skips buffer outside git root', function()
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/other/path/file.lua' }
      callback({ buf = 1 })

      assert.are.same({}, display_manager_mock.attach_calls)
    end)

    it('skips buffer whose path overlaps git root as prefix', function()
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo-copy/file.lua' }
      callback({ buf = 1 })

      assert.are.same({}, display_manager_mock.attach_calls)
    end)

    it('attaches buffer under git root with relative path', function()
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo/src/file.lua' }
      callback({ buf = 1 })

      assert.are.equal(1, #display_manager_mock.attach_calls)
      assert.are.equal(1, display_manager_mock.attach_calls[1].bufnr)
      assert.are.equal('src/file.lua', display_manager_mock.attach_calls[1].filepath)
    end)

    it('computes correct relative path for root-level file', function()
      fn_mock.git_succeeds = true
      fn_mock.systemlist_result = { '/repo' }
      review.start()
      local callback = find_autocmd_callback('BufEnter')

      api_mock.buf_names = { [1] = '/repo/file.lua' }
      callback({ buf = 1 })

      assert.are.equal('file.lua', display_manager_mock.attach_calls[1].filepath)
    end)
  end)
end)

describe('display.manager', function()
  local manager

  local data_mock = {}
  local signs_mock = {}
  local highlights_mock = {}
  local observers_mock = {}
  local comment_popup_mock = {}

  local api_mock = {
    cursor = { 1, 0 },
    cursor_fails = false,
  }

  local autocmd_next_id = 1
  local del_autocmd_calls = {}

  local orig_vim = {}

  before_each(function()
    api_mock.cursor = { 1, 0 }
    api_mock.cursor_fails = false
    autocmd_next_id = 1
    del_autocmd_calls = {}

    data_mock.threads = {}
    data_mock.get_threads_for_file = function(_)
      return data_mock.threads
    end

    signs_mock.clear_calls = {}
    signs_mock.place_calls = {}
    signs_mock.setup_calls = 0
    signs_mock.clear = function(bufnr)
      table.insert(signs_mock.clear_calls, bufnr)
    end
    signs_mock.place = function(bufnr, threads)
      table.insert(signs_mock.place_calls, { bufnr = bufnr, threads = threads })
    end
    signs_mock.setup = function()
      signs_mock.setup_calls = signs_mock.setup_calls + 1
    end

    highlights_mock.clear_calls = {}
    highlights_mock.set_calls = {}
    highlights_mock.clear = function(bufnr)
      table.insert(highlights_mock.clear_calls, bufnr)
    end
    highlights_mock.set = function(bufnr, thread)
      table.insert(highlights_mock.set_calls, { bufnr = bufnr, thread = thread })
    end

    observers_mock.subscribe_calls = {}
    observers_mock.subscribe = function(event, callback)
      local entry = { event = event, callback = callback, unsubscribed = false }
      table.insert(observers_mock.subscribe_calls, entry)
      return function()
        entry.unsubscribed = true
      end
    end

    comment_popup_mock.show_calls = {}
    comment_popup_mock.show = function(thread)
      table.insert(comment_popup_mock.show_calls, thread)
    end

    package.loaded['nit.state.data'] = data_mock
    package.loaded['nit.state.observers'] = observers_mock
    package.loaded['nit.display.signs'] = signs_mock
    package.loaded['nit.display.highlights'] = highlights_mock
    package.loaded['nit.display.comment_popup'] = comment_popup_mock
    package.loaded['nit.ui.highlights'] = { setup = function() end }

    orig_vim.nvim_create_augroup = vim.api.nvim_create_augroup
    orig_vim.nvim_create_autocmd = vim.api.nvim_create_autocmd
    orig_vim.nvim_del_autocmd = vim.api.nvim_del_autocmd
    orig_vim.nvim_win_get_cursor = vim.api.nvim_win_get_cursor

    vim.api.nvim_create_augroup = function(name, _)
      return name
    end

    vim.api.nvim_create_autocmd = function(_, _)
      local id = autocmd_next_id
      autocmd_next_id = autocmd_next_id + 1
      return id
    end

    vim.api.nvim_del_autocmd = function(id)
      table.insert(del_autocmd_calls, id)
    end

    vim.api.nvim_win_get_cursor = function(_)
      if api_mock.cursor_fails then
        error('cursor API failed')
      end
      return api_mock.cursor
    end

    package.loaded['nit.display.manager'] = nil
    manager = require('nit.display.manager')
  end)

  after_each(function()
    vim.api.nvim_create_augroup = orig_vim.nvim_create_augroup
    vim.api.nvim_create_autocmd = orig_vim.nvim_create_autocmd
    vim.api.nvim_del_autocmd = orig_vim.nvim_del_autocmd
    vim.api.nvim_win_get_cursor = orig_vim.nvim_win_get_cursor

    package.loaded['nit.state.data'] = nil
    package.loaded['nit.state.observers'] = nil
    package.loaded['nit.display.signs'] = nil
    package.loaded['nit.display.highlights'] = nil
    package.loaded['nit.display.comment_popup'] = nil
    package.loaded['nit.ui.highlights'] = nil
    package.loaded['nit.display.manager'] = nil
  end)

  describe('thread filtering', function()
    it('includes RIGHT non-outdated threads with line numbers', function()
      local thread = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = { thread }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same(thread, lines[5])
    end)

    it('excludes LEFT-side threads', function()
      data_mock.threads = { { side = 'LEFT', line = 5, isOutdated = false } }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same({}, lines)
    end)

    it('excludes threads with nil line', function()
      data_mock.threads = { { side = 'RIGHT', line = nil, isOutdated = false } }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same({}, lines)
    end)

    it('excludes outdated threads', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = true } }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same({}, lines)
    end)

    it('excludes resolved threads', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false, isResolved = true } }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same({}, lines)
    end)

    it('filters mixed displayable and non-displayable threads', function()
      local good = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = {
        good,
        { side = 'LEFT', line = 3, isOutdated = false },
        { side = 'RIGHT', line = nil, isOutdated = false },
        { side = 'RIGHT', line = 10, isOutdated = true },
        { side = 'RIGHT', line = 15, isOutdated = false, isResolved = true },
      }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same(good, lines[5])
      assert.is_nil(lines[3])
      assert.is_nil(lines[10])
      assert.is_nil(lines[15])
    end)
  end)

  describe('line lookup', function()
    it('keeps first thread when multiple threads share a line', function()
      local first = { side = 'RIGHT', line = 5, isOutdated = false, id = 'first' }
      local second = { side = 'RIGHT', line = 5, isOutdated = false, id = 'second' }
      data_mock.threads = { first, second }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.equals('first', lines[5].id)
    end)

    it('includes all threads with unique line numbers', function()
      local t1 = { side = 'RIGHT', line = 5, isOutdated = false }
      local t2 = { side = 'RIGHT', line = 10, isOutdated = false }
      data_mock.threads = { t1, t2 }

      manager.attach(1, 'test.lua')

      local lines = manager.get_commented_lines(1)
      assert.same(t1, lines[5])
      assert.same(t2, lines[10])
    end)
  end)

  describe('attach', function()
    it('is no-op when buffer is already attached', function()
      data_mock.threads = {}

      manager.attach(1, 'test.lua')
      local subscribe_count = #observers_mock.subscribe_calls

      manager.attach(1, 'test.lua')

      assert.equals(subscribe_count, #observers_mock.subscribe_calls)
    end)

    it('subscribes to comments observer on attach', function()
      data_mock.threads = {}

      manager.attach(1, 'test.lua')

      assert.equals(1, #observers_mock.subscribe_calls)
      assert.equals('comments', observers_mock.subscribe_calls[1].event)
    end)

    it('places signs for displayable threads', function()
      local thread = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = { thread }

      manager.attach(1, 'test.lua')

      assert.equals(1, #signs_mock.place_calls)
      assert.equals(1, signs_mock.place_calls[1].bufnr)
      assert.same({ thread }, signs_mock.place_calls[1].threads)
    end)

    it('sets highlight when cursor is on commented line during attach', function()
      local thread = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = { thread }
      api_mock.cursor = { 5, 0 }

      manager.attach(1, 'test.lua')

      assert.equals(1, #highlights_mock.set_calls)
      assert.same(thread, highlights_mock.set_calls[1].thread)
    end)

    it('does not set highlight when cursor is not on commented line', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false } }
      api_mock.cursor = { 1, 0 }

      manager.attach(1, 'test.lua')

      assert.same({}, highlights_mock.set_calls)
    end)
  end)

  describe('detach', function()
    it('is no-op when buffer is not attached', function()
      local clear_count = #signs_mock.clear_calls

      manager.detach(999)

      assert.equals(clear_count, #signs_mock.clear_calls)
    end)

    it('removes state from attached buffers', function()
      data_mock.threads = {}
      manager.attach(1, 'test.lua')

      manager.detach(1)

      assert.is_nil(manager.get_commented_lines(1))
    end)

    it('calls observer unsubscribe', function()
      data_mock.threads = {}
      manager.attach(1, 'test.lua')

      manager.detach(1)

      assert.is_true(observers_mock.subscribe_calls[1].unsubscribed)
    end)

    it('clears signs and highlights', function()
      data_mock.threads = {}
      manager.attach(1, 'test.lua')
      local sign_clears = #signs_mock.clear_calls
      local highlight_clears = #highlights_mock.clear_calls

      manager.detach(1)

      assert.equals(sign_clears + 1, #signs_mock.clear_calls)
      assert.equals(highlight_clears + 1, #highlights_mock.clear_calls)
    end)

    it('deletes autocmds', function()
      data_mock.threads = {}
      manager.attach(1, 'test.lua')

      manager.detach(1)

      assert.is_true(#del_autocmd_calls >= 2)
    end)
  end)

  describe('detach_all', function()
    it('detaches all attached buffers', function()
      data_mock.threads = {}
      manager.attach(1, 'a.lua')
      manager.attach(2, 'b.lua')

      manager.detach_all()

      assert.is_nil(manager.get_commented_lines(1))
      assert.is_nil(manager.get_commented_lines(2))
    end)
  end)

  describe('show_popup', function()
    it('is no-op when buffer is not attached', function()
      manager.show_popup(999)

      assert.same({}, comment_popup_mock.show_calls)
    end)

    it('is no-op when cursor API fails', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false } }
      manager.attach(1, 'test.lua')
      api_mock.cursor_fails = true

      manager.show_popup(1)

      assert.same({}, comment_popup_mock.show_calls)
    end)

    it('is no-op when cursor is not on commented line', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false } }
      api_mock.cursor = { 1, 0 }
      manager.attach(1, 'test.lua')
      api_mock.cursor = { 3, 0 }

      manager.show_popup(1)

      assert.same({}, comment_popup_mock.show_calls)
    end)

    it('shows popup when cursor is on commented line', function()
      local thread = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = { thread }
      api_mock.cursor = { 1, 0 }
      manager.attach(1, 'test.lua')
      api_mock.cursor = { 5, 0 }

      manager.show_popup(1)

      assert.equals(1, #comment_popup_mock.show_calls)
      assert.same(thread, comment_popup_mock.show_calls[1])
    end)
  end)

  describe('get_thread_at_cursor', function()
    it('returns nil when buffer is not attached', function()
      assert.is_nil(manager.get_thread_at_cursor(999))
    end)

    it('returns nil when cursor API fails', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false } }
      manager.attach(1, 'test.lua')
      api_mock.cursor_fails = true

      assert.is_nil(manager.get_thread_at_cursor(1))
    end)

    it('returns nil when cursor is not on commented line', function()
      data_mock.threads = { { side = 'RIGHT', line = 5, isOutdated = false } }
      api_mock.cursor = { 1, 0 }
      manager.attach(1, 'test.lua')
      api_mock.cursor = { 3, 0 }

      assert.is_nil(manager.get_thread_at_cursor(1))
    end)

    it('returns thread when cursor is on commented line', function()
      local thread = { side = 'RIGHT', line = 5, isOutdated = false }
      data_mock.threads = { thread }
      api_mock.cursor = { 1, 0 }
      manager.attach(1, 'test.lua')
      api_mock.cursor = { 5, 0 }

      assert.same(thread, manager.get_thread_at_cursor(1))
    end)
  end)

  describe('get_commented_lines', function()
    it('returns nil when buffer is not attached', function()
      assert.is_nil(manager.get_commented_lines(999))
    end)

    it('returns commented lines table when buffer is attached', function()
      data_mock.threads = {}
      manager.attach(1, 'test.lua')

      assert.is_not_nil(manager.get_commented_lines(1))
    end)
  end)
end)

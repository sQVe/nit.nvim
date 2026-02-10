local has_nui, _ = pcall(require, 'nui.split')

local sidebar
if has_nui then
  sidebar = require('nit.ui.sidebar')
end

describe('review panel', function()
  if not has_nui then
    it('skipped: nui.nvim not available', function() end)
    return
  end

  local data = require('nit.state.data')

  before_each(function()
    data.clear()
    data.set_files({})
    data.set_threads({})
    vim.wait(10)
  end)

  after_each(function()
    if sidebar.is_open() then
      sidebar.close()
    end
  end)

  describe('open', function()
    it('opens layout, creates tree, and sets up keybindings', function()
      assert.is_false(sidebar.is_open())

      sidebar.open()

      assert.is_true(sidebar.is_open())

      local layout = require('nit.ui.layout')
      local bufnr = layout.get_sidebar_bufnr()
      assert.is_not_nil(bufnr)

      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_enter = false
      local has_q = false
      local has_m = false

      for _, map in ipairs(keymaps) do
        if map.lhs == '<CR>' then
          has_enter = true
        end
        if map.lhs == 'q' then
          has_q = true
        end
        if map.lhs == 'm' then
          has_m = true
        end
      end

      assert.is_true(has_enter, 'Expected <CR> keymap to be set')
      assert.is_true(has_q, 'Expected q keymap to be set')
      assert.is_true(has_m, 'Expected m keymap to be set')
    end)

    it('is no-op when already open', function()
      sidebar.open()
      local layout = require('nit.ui.layout')
      local first_bufnr = layout.get_sidebar_bufnr()

      sidebar.open()
      local second_bufnr = layout.get_sidebar_bufnr()

      assert.are.equal(first_bufnr, second_bufnr)
    end)
  end)

  describe('close', function()
    it('cleans up tree, layout, and keybindings', function()
      sidebar.open()
      assert.is_true(sidebar.is_open())

      sidebar.close()

      assert.is_false(sidebar.is_open())
    end)

    it('is no-op when already closed', function()
      assert.is_false(sidebar.is_open())

      sidebar.close()

      assert.is_false(sidebar.is_open())
    end)
  end)

  describe('toggle', function()
    it('opens when closed', function()
      assert.is_false(sidebar.is_open())

      sidebar.toggle()

      assert.is_true(sidebar.is_open())
    end)

    it('closes when open', function()
      sidebar.open()
      assert.is_true(sidebar.is_open())

      sidebar.toggle()

      assert.is_false(sidebar.is_open())
    end)
  end)

  describe('refresh', function()
    it('R key calls on_refresh callback when provided', function()
      local refresh_called = false
      sidebar.open({
        on_refresh = function()
          refresh_called = true
        end,
      })

      local layout = require('nit.ui.layout')
      local bufnr = layout.get_sidebar_bufnr()
      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local r_callback = nil
      for _, map in ipairs(keymaps) do
        if map.lhs == 'R' then
          r_callback = map.callback
          break
        end
      end

      assert.is_not_nil(r_callback, 'Expected R keymap to be set')
      r_callback()

      assert.is_true(refresh_called, 'Expected on_refresh callback to be called')
    end)

    it('updates tree with current state data', function()
      sidebar.open()

      data.set_files({
        {
          filename = 'test.lua',
          status = 'modified',
          additions = 10,
          deletions = 5,
        },
      })

      sidebar.refresh()

      assert.is_true(sidebar.is_open())
    end)

    it('shows placeholder when no PR data is loaded', function()
      sidebar.open()

      data.set_files({})
      data.set_threads({})

      sidebar.refresh()

      local layout = require('nit.ui.layout')
      local bufnr = layout.get_sidebar_bufnr()
      assert.is_not_nil(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_placeholder = false
      for _, line in ipairs(lines) do
        if line:match('No PR loaded') then
          has_placeholder = true
          break
        end
      end

      assert.is_true(has_placeholder, 'Expected placeholder text to be shown')
    end)

    it('updates tree when only threads exist', function()
      sidebar.open()

      data.set_files({})
      data.set_threads({
        {
          id = 1,
          path = 'test.lua',
          comments = { { author = { login = 'reviewer' } } },
          isResolved = false,
          line = 10,
        },
      })

      sidebar.refresh()

      local layout = require('nit.ui.layout')
      local bufnr = layout.get_sidebar_bufnr()
      assert.is_not_nil(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_placeholder = false
      for _, line in ipairs(lines) do
        if line:match('No PR loaded') then
          has_placeholder = true
          break
        end
      end

      assert.is_false(has_placeholder, 'Should not show placeholder when threads exist')
    end)

    it('subscribes to comments key for state updates', function()
      local observers = require('nit.state.observers')
      local notify_count = 0

      sidebar.open()

      local original_refresh = sidebar.refresh
      sidebar.refresh = function()
        notify_count = notify_count + 1
        original_refresh()
      end

      observers.notify('comments')
      vim.wait(100)

      assert.is_true(notify_count > 0, 'Expected refresh to be called on comments notify')

      sidebar.refresh = original_refresh
    end)

    it('shows loading message when loading state is true and no files exist', function()
      sidebar.open()

      data.set_loading(true)

      local layout = require('nit.ui.layout')
      local bufnr = layout.get_sidebar_bufnr()
      assert.is_not_nil(bufnr)

      vim.wait(100)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local has_loading = false
      for _, line in ipairs(lines) do
        if line:match('Loading PR data') then
          has_loading = true
          break
        end
      end

      assert.is_true(has_loading, 'Expected loading message to be shown')
    end)
  end)

  describe('callbacks', function()
    it('calls on_close callback when sidebar closes', function()
      local close_called = false
      sidebar.open({
        on_close = function()
          close_called = true
        end,
      })

      sidebar.close()

      assert.is_true(close_called, 'Expected on_close callback to be called')
    end)
  end)

  describe('is_open', function()
    it('returns false when closed', function()
      assert.is_false(sidebar.is_open())
    end)

    it('returns true when open', function()
      sidebar.open()

      assert.is_true(sidebar.is_open())
    end)
  end)
end)

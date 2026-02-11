local manager = require('nit.display.manager')
local data = require('nit.state.data')
local observers = require('nit.state.observers')

describe('display.manager', function()
  before_each(function()
    data.clear()
    observers.clear()
    manager.detach_all()
    manager.setup()
  end)

  after_each(function()
    manager.detach_all()
    data.clear()
    observers.clear()
  end)

  describe('attach/detach lifecycle', function()
    it('attaches to buffer and places signs', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
        {
          id = 2,
          path = 'test.lua',
          side = 'RIGHT',
          line = 10,
          isResolved = true,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr, 'test.lua')

      vim.wait(100, function()
        return false
      end)

      local signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.is_true(#signs > 0)
      assert.is_true(#signs[1].signs == 2)

      manager.detach(bufnr)

      signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.are.equal(0, #signs[1].signs)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('only places signs for RIGHT-side threads', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
        {
          id = 2,
          path = 'test.lua',
          side = 'LEFT',
          line = 10,
          isResolved = false,
          comments = {},
        },
        {
          id = 3,
          path = 'test.lua',
          side = 'RIGHT',
          line = nil,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr, 'test.lua')

      vim.wait(100, function()
        return false
      end)

      local signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.are.equal(1, #signs[1].signs)

      manager.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('detach_all cleans up all buffers', function()
      local bufnr1 = vim.api.nvim_create_buf(false, true)
      local bufnr2 = vim.api.nvim_create_buf(false, true)

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr1, 'test.lua')
      manager.attach(bufnr2, 'test.lua')

      vim.wait(100, function()
        return false
      end)

      manager.detach_all()

      local signs1 = vim.fn.sign_getplaced(bufnr1, { group = 'nit_comments' })
      local signs2 = vim.fn.sign_getplaced(bufnr2, { group = 'nit_comments' })
      assert.are.equal(0, #signs1[1].signs)
      assert.are.equal(0, #signs2[1].signs)

      vim.api.nvim_buf_delete(bufnr1, { force = true })
      vim.api.nvim_buf_delete(bufnr2, { force = true })
    end)

    it('does not re-attach if already attached', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr, 'test.lua')
      manager.attach(bufnr, 'test.lua')

      vim.wait(100, function()
        return false
      end)

      local signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.are.equal(1, #signs[1].signs)

      manager.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('observer-driven updates', function()
    it('refreshes signs when threads are updated', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      local initial_threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(initial_threads)

      manager.attach(bufnr, 'test.lua')

      vim.wait(100, function()
        return false
      end)

      local signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.are.equal(1, #signs[1].signs)

      local updated_threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 5,
          isResolved = false,
          comments = {},
        },
        {
          id = 2,
          path = 'test.lua',
          side = 'RIGHT',
          line = 10,
          isResolved = true,
          comments = {},
        },
      }
      data.set_threads(updated_threads)

      vim.wait(100, function()
        return false
      end)

      signs = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.are.equal(2, #signs[1].signs)

      manager.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('get_thread_at_cursor', function()
    it('returns thread at cursor position', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'line 1',
        'line 2',
        'line 3',
        'line 4',
        'line 5',
      })

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 3,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr, 'test.lua')

      local win = vim.api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = 40,
        height = 10,
        row = 5,
        col = 5,
      })

      vim.api.nvim_win_set_cursor(win, { 3, 0 })

      vim.wait(100, function()
        return false
      end)

      local thread = manager.get_thread_at_cursor(bufnr)
      assert.is_not_nil(thread)
      assert.are.equal(1, thread.id)

      vim.api.nvim_win_close(win, true)
      manager.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('returns nil when no thread at cursor', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        'line 1',
        'line 2',
        'line 3',
      })

      local threads = {
        {
          id = 1,
          path = 'test.lua',
          side = 'RIGHT',
          line = 1,
          isResolved = false,
          comments = {},
        },
      }
      data.set_threads(threads)

      manager.attach(bufnr, 'test.lua')

      local win = vim.api.nvim_open_win(bufnr, true, {
        relative = 'editor',
        width = 40,
        height = 10,
        row = 5,
        col = 5,
      })

      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      vim.wait(100, function()
        return false
      end)

      local thread = manager.get_thread_at_cursor(bufnr)
      assert.is_nil(thread)

      vim.api.nvim_win_close(win, true)
      manager.detach(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('returns nil for unattached buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local thread = manager.get_thread_at_cursor(bufnr)
      assert.is_nil(thread)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)

  describe('show_popup', function()
    it('does nothing for unattached buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      manager.show_popup(bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)

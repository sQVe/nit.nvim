local assert = require('luassert')
local thread_menu = require('nit.display.thread_menu')

describe('thread_menu', function()
  describe('is_open', function()
    it('returns false when not open', function()
      assert.is_false(thread_menu.is_open())
    end)
  end)

  describe('close', function()
    it('does not error when already closed', function()
      assert.has_no.errors(function()
        thread_menu.close()
      end)
    end)
  end)

  describe('open', function()
    local thread

    before_each(function()
      package.loaded['nit.display.thread_menu'] = nil
      thread_menu = require('nit.display.thread_menu')
      thread = {
        id = 'thread-1',
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'Hello', createdAt = '2026-01-01T12:00:00Z' },
        },
      }
    end)

    after_each(function()
      thread_menu.close()
      package.loaded['nit.display.thread_menu'] = nil
    end)

    it('menu is open after open() call', function()
      thread_menu.open(thread, { on_toggle_resolved = function() end })

      vim.wait(50, function()
        return thread_menu.is_open()
      end)

      assert.is_true(thread_menu.is_open())
    end)

    it('<CR> on resolve line invokes on_toggle_resolved and closes menu', function()
      local called = false
      thread_menu.open(thread, {
        on_toggle_resolved = function()
          called = true
        end,
      })

      vim.wait(50, function()
        return thread_menu.is_open()
      end)
      assert.is_true(thread_menu.is_open())

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)

      vim.wait(100, function()
        return called
      end)

      assert.is_true(called, 'on_toggle_resolved should have been called')
      assert.is_false(thread_menu.is_open(), 'menu should close after CR')
    end)

    it('menu closes after <CR>', function()
      thread_menu.open(thread, { on_toggle_resolved = function() end })

      vim.wait(50, function()
        return thread_menu.is_open()
      end)

      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<CR>', true, false, true), 'x', false)

      vim.wait(100, function()
        return not thread_menu.is_open()
      end)

      assert.is_false(thread_menu.is_open())
    end)
  end)
end)

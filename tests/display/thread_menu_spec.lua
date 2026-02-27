local assert = require('luassert')
local thread_menu = require('nit.display.thread_menu')

describe('nit.display.thread_menu', function()
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

  describe('build_menu_items', function()
    it('always includes resolve item', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
      })
      assert.are.equal(1, #items)
      assert.are.equal('r', items[1].key)
      assert.are.equal('r  Resolve thread', items[1].label)
    end)

    it('shows unresolve when thread is resolved', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = true },
        on_toggle_resolved = function() end,
      })
      assert.are.equal('r  Unresolve thread', items[1].label)
    end)

    it('includes quote reply when comment and callback provided', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'alice' }, body = 'hello' },
        on_quote_reply = function() end,
      })
      assert.are.equal(2, #items)
      assert.are.equal('q', items[2].key)
      assert.are.equal('q  Quote reply', items[2].label)
    end)

    it('excludes quote reply when no comment', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
      })
      assert.are.equal(1, #items)
    end)

    it('excludes quote reply when in_reply_input is true', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'alice' }, body = 'hello' },
        on_quote_reply = function() end,
        in_reply_input = true,
      })
      for _, item in ipairs(items) do
        assert.are_not.equal('q', item.key)
      end
    end)

    it('includes edit when viewer owns non-optimistic comment', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'me' }, body = 'text', _optimistic_id = nil },
        viewer_login = 'me',
        on_quote_reply = function() end,
        on_edit_comment = function() end,
      })
      assert.are.equal('e', items[3].key)
    end)

    it('excludes edit when viewer does not own comment', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'other' }, body = 'text' },
        viewer_login = 'me',
        on_edit_comment = function() end,
        on_quote_reply = function() end,
      })
      for _, item in ipairs(items) do
        assert.are_not.equal('e', item.key)
      end
    end)

    it('excludes edit when comment is optimistic', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'me' }, body = 'text', _optimistic_id = 'tmp-1' },
        viewer_login = 'me',
        on_edit_comment = function() end,
        on_quote_reply = function() end,
      })
      for _, item in ipairs(items) do
        assert.are_not.equal('e', item.key)
      end
    end)

    it('excludes edit when viewer_login is nil', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'me' }, body = 'text' },
        viewer_login = nil,
        on_edit_comment = function() end,
        on_quote_reply = function() end,
      })
      for _, item in ipairs(items) do
        assert.are_not.equal('e', item.key)
      end
    end)

    it('includes apply suggestion when body has suggestion block', function()
      local body = 'Look at this:\n```suggestion\nfixed code\n```'
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'alice' }, body = body },
        on_quote_reply = function() end,
        on_apply_suggestion = function() end,
      })
      local found = false
      for _, item in ipairs(items) do
        if item.key == 'a' then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('excludes apply suggestion when body has no suggestion block', function()
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'alice' }, body = 'plain text' },
        on_quote_reply = function() end,
        on_apply_suggestion = function() end,
      })
      for _, item in ipairs(items) do
        assert.are_not.equal('a', item.key)
      end
    end)

    it('items appear in order: resolve, quote, edit, apply', function()
      local body = '```suggestion\nfix\n```'
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = { author = { login = 'me' }, body = body },
        viewer_login = 'me',
        on_quote_reply = function() end,
        on_edit_comment = function() end,
        on_apply_suggestion = function() end,
      })
      assert.are.equal(4, #items)
      assert.are.equal('r', items[1].key)
      assert.are.equal('q', items[2].key)
      assert.are.equal('e', items[3].key)
      assert.are.equal('a', items[4].key)
    end)

    it('resolve action calls on_toggle_resolved', function()
      local called = false
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function()
          called = true
        end,
      })
      items[1].action()
      assert.is_true(called)
    end)

    it('quote reply action calls on_quote_reply with comment', function()
      local received = nil
      local comment = { author = { login = 'a' }, body = 'hi' }
      local items = thread_menu.build_menu_items({
        thread = { isResolved = false },
        on_toggle_resolved = function() end,
        comment = comment,
        on_quote_reply = function(c)
          received = c
        end,
      })
      items[2].action()
      assert.are.equal(comment, received)
    end)
  end)
end)

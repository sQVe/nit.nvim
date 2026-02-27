local assert = require('luassert')
local reaction_picker = require('nit.display.reaction_picker')

describe('nit.display.reaction_picker', function()
  after_each(function()
    reaction_picker.close()
    package.loaded['nit.display.reaction_picker'] = nil
    reaction_picker = require('nit.display.reaction_picker')
  end)

  describe('is_open', function()
    it('returns false when not open', function()
      assert.is_false(reaction_picker.is_open())
    end)
  end)

  describe('close', function()
    it('does not error when already closed', function()
      assert.has_no.errors(function()
        reaction_picker.close()
      end)
    end)
  end)

  describe('open', function()
    local comment_with_reactions
    local comment_no_reactions

    before_each(function()
      package.loaded['nit.display.reaction_picker'] = nil
      reaction_picker = require('nit.display.reaction_picker')

      comment_with_reactions = {
        reactions = {
          { content = 'THUMBS_UP', count = 2, viewer_has_reacted = true },
          { content = 'HEART', count = 1, viewer_has_reacted = false },
        },
      }

      comment_no_reactions = {
        reactions = {},
      }
    end)

    it('popup is open after open() call', function()
      reaction_picker.open({ comment = comment_no_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      assert.is_true(reaction_picker.is_open())
    end)

    it('shows count and checkmark for viewer reaction', function()
      reaction_picker.open({ comment = comment_with_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      local lines = vim.api.nvim_buf_get_lines(
        vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()),
        0,
        -1,
        false
      )
      local found = false
      for _, line in ipairs(lines) do
        if line:find('👍') and line:find('2') and line:find('✓') then
          found = true
          break
        end
      end
      assert.is_true(found, 'THUMBS_UP line should show count 2 and ✓')
    end)

    it('shows count without checkmark for non-viewer reaction', function()
      reaction_picker.open({ comment = comment_with_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      local lines = vim.api.nvim_buf_get_lines(
        vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()),
        0,
        -1,
        false
      )
      local found = false
      for _, line in ipairs(lines) do
        if line:find('❤️') and line:find('1') and not line:find('✓') then
          found = true
          break
        end
      end
      assert.is_true(found, 'HEART line should show count 1 without ✓')
    end)

    it('shows emoji without count or checkmark when no reactions', function()
      reaction_picker.open({ comment = comment_no_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      local lines = vim.api.nvim_buf_get_lines(
        vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()),
        0,
        -1,
        false
      )
      assert.are.equal(8, #lines)
      local thumbs_line = lines[1]
      assert.is_truthy(thumbs_line:find('👍'), 'first line should contain 👍')
      assert.is_nil(thumbs_line:find('✓'), 'should not contain ✓')
    end)

    it('number key calls on_toggle with correct content', function()
      local received = nil
      reaction_picker.open({
        comment = comment_no_reactions,
        on_toggle = function(content)
          received = content
        end,
      })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      vim.api.nvim_feedkeys('1', 'x', false)

      vim.wait(100, function()
        return received ~= nil
      end)

      assert.are.equal('THUMBS_UP', received)
    end)

    it('number key closes popup', function()
      reaction_picker.open({ comment = comment_no_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      vim.api.nvim_feedkeys('1', 'x', false)

      vim.wait(100, function()
        return not reaction_picker.is_open()
      end)

      assert.is_false(reaction_picker.is_open())
    end)

    it('q closes popup without calling on_toggle', function()
      local called = false
      reaction_picker.open({
        comment = comment_no_reactions,
        on_toggle = function()
          called = true
        end,
      })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      vim.api.nvim_feedkeys('q', 'x', false)

      vim.wait(100, function()
        return not reaction_picker.is_open()
      end)

      assert.is_false(reaction_picker.is_open())
      assert.is_false(called)
    end)

    it('opening second popup closes first', function()
      reaction_picker.open({ comment = comment_no_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      reaction_picker.open({ comment = comment_no_reactions, on_toggle = function() end })

      vim.wait(50, function()
        return reaction_picker.is_open()
      end)

      assert.is_true(reaction_picker.is_open())
    end)
  end)
end)

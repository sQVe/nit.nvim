local assert = require('luassert')
local help_popup = require('nit.display.help_popup')

describe('help_popup', function()
  describe('format_hint_lines', function()
    it('formats a single hint', function()
      local hints = { { key = 'q', label = 'Close' } }

      local lines = help_popup.format_hint_lines(hints)

      assert.is_table(lines)
      assert.equals(1, #lines)
      assert.matches('q', lines[1], 1, true)
      assert.matches('Close', lines[1], 1, true)
    end)

    it('returns empty table for empty hints', function()
      local lines = help_popup.format_hint_lines({})

      assert.is_table(lines)
      assert.equals(0, #lines)
    end)

    it('right-aligns keys by padding shorter keys', function()
      local hints = {
        { key = 'q', label = 'Close' },
        { key = 'Esc', label = 'Close' },
        { key = '?', label = 'Help' },
      }

      local lines = help_popup.format_hint_lines(hints)

      assert.equals(3, #lines)
      -- All lines should start with the same number of spaces (aligned keys)
      -- Find where 'q' appears vs 'Esc' — q should be right-padded to match Esc width
      local q_line = lines[1]
      local esc_line = lines[2]
      -- The label 'Close' should start at the same column in both lines
      local q_close_pos = q_line:find('Close')
      local esc_close_pos = esc_line:find('Close')
      assert.equals(q_close_pos, esc_close_pos)
    end)

    it('includes key and label text in each line', function()
      local hints = {
        { key = 'r', label = 'Reply' },
        { key = 't', label = 'Resolve' },
      }

      local lines = help_popup.format_hint_lines(hints)

      assert.matches('Reply', lines[1], 1, true)
      assert.matches('Resolve', lines[2], 1, true)
    end)
  end)

  describe('is_open', function()
    it('returns false when no popup is active', function()
      assert.is_false(help_popup.is_open())
    end)
  end)
end)

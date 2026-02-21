local nit_highlights = require('nit.ui.highlights')

describe('nit.ui.highlights', function()
  describe('setup()', function()
    before_each(function()
      nit_highlights.setup()
    end)

    it('defines NitThreadCommentAlt with bg or link to CursorLine', function()
      local raw = vim.api.nvim_get_hl(0, { name = 'NitThreadCommentAlt', link = true })
      local resolved = vim.api.nvim_get_hl(0, { name = 'NitThreadCommentAlt', link = false })

      local has_bg = resolved.bg ~= nil
      local is_linked = raw.link == 'CursorLine'

      assert.is_true(has_bg or is_linked, 'NitThreadCommentAlt must have bg or link to CursorLine')
    end)
  end)
end)

local assert = require('luassert')
local reply_input = require('nit.display.reply_input')

describe('nit.display.reply_input', function()
  describe('open', function()
    local panel_winid
    local panel_bufnr

    before_each(function()
      package.loaded['nit.display.reply_input'] = nil
      reply_input = require('nit.display.reply_input')
      panel_bufnr = vim.api.nvim_create_buf(false, true)
      local ref_win = vim.iter(vim.api.nvim_list_wins()):find(function(w)
        return vim.api.nvim_win_get_config(w).relative == ''
      end)
      panel_winid = vim.api.nvim_open_win(panel_bufnr, false, { split = 'right', win = ref_win })
    end)

    after_each(function()
      reply_input.close()
      package.loaded['nit.display.reply_input'] = nil
      if vim.api.nvim_win_is_valid(panel_winid) then
        vim.api.nvim_win_close(panel_winid, true)
      end
      if vim.api.nvim_buf_is_valid(panel_bufnr) then
        vim.api.nvim_buf_delete(panel_bufnr, { force = true })
      end
    end)

    it('returns true and marks window as open', function()
      assert.is_true(reply_input.open(panel_winid))
      assert.is_true(reply_input.is_open())
    end)

    it('is idempotent when already open', function()
      reply_input.open(panel_winid)
      local winid_first = reply_input.get_winid()

      reply_input.open(panel_winid)

      assert.are.equal(winid_first, reply_input.get_winid())
    end)

    it('sets nit filetype to prevent plugin interference', function()
      reply_input.open(panel_winid)

      assert.are.equal('nit', vim.bo[reply_input.get_bufnr()].filetype)
    end)

    it('clears formatoptions to prevent auto line breaks', function()
      reply_input.open(panel_winid)

      assert.are.equal('', vim.bo[reply_input.get_bufnr()].formatoptions)
    end)

    it('enables wrap, linebreak, and breakindent for text composition', function()
      reply_input.open(panel_winid)
      local winid = reply_input.get_winid()

      assert.is_true(vim.wo[winid].wrap)
      assert.is_true(vim.wo[winid].linebreak)
      assert.is_true(vim.wo[winid].breakindent)
    end)

    it('sets showbreak to a space to override global showbreak', function()
      local orig = vim.o.showbreak
      vim.o.showbreak = '↵ '

      reply_input.open(panel_winid)

      assert.are.equal(' ', vim.wo[reply_input.get_winid()].showbreak)
      vim.o.showbreak = orig
    end)
  end)

  describe('is_open', function()
    it('returns false when not open', function()
      assert.is_false(reply_input.is_open())
    end)
  end)

  describe('get_bufnr', function()
    it('returns nil when not open', function()
      assert.is_nil(reply_input.get_bufnr())
    end)
  end)

  describe('get_winid', function()
    it('returns nil when not open', function()
      assert.is_nil(reply_input.get_winid())
    end)
  end)

  describe('get_text', function()
    it('returns empty string when not open', function()
      assert.are.equal('', reply_input.get_text())
    end)
  end)

  describe('close', function()
    it('does not error when already closed', function()
      assert.has_no.errors(function()
        reply_input.close()
      end)
    end)
  end)

  describe('clear', function()
    it('does not error when not open', function()
      assert.has_no.errors(function()
        reply_input.clear()
      end)
    end)
  end)

  describe('set_text', function()
    it('does not error when not open', function()
      assert.has_no.errors(function()
        reply_input.set_text('some text')
      end)
    end)
  end)

  describe('map', function()
    it('does not error when not open', function()
      assert.has_no.errors(function()
        reply_input.map('n', '<C-s>', function() end, { noremap = true })
      end)
    end)
  end)
end)

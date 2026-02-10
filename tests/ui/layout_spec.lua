local has_nui, _ = pcall(require, 'nui.split')

local layout
if has_nui then
  layout = require('nit.ui.layout')
end

describe('layout', function()
  if not has_nui then
    it('skipped: nui.nvim not available', function() end)
    return
  end
  after_each(function()
    if layout.is_open() then
      layout.close()
    end
  end)

  describe('open', function()
    it('creates and mounts sidebar split', function()
      assert.is_false(layout.is_open())

      layout.open()

      assert.is_true(layout.is_open())
      assert.is_not_nil(layout.get_sidebar_bufnr())
      assert.is_not_nil(layout.get_sidebar_winid())

      local bufnr = layout.get_sidebar_bufnr()
      assert.are.equal('nofile', vim.bo[bufnr].buftype)
      assert.is_false(vim.bo[bufnr].swapfile)
      assert.is_false(vim.bo[bufnr].modifiable)

      local winid = layout.get_sidebar_winid()
      assert.is_false(vim.wo[winid].number)
      assert.is_false(vim.wo[winid].relativenumber)
      assert.are.equal('no', vim.wo[winid].signcolumn)
      assert.is_true(vim.wo[winid].winfixwidth)
      assert.is_true(vim.wo[winid].cursorline)
    end)

    it('is no-op when already open', function()
      layout.open()
      local first_bufnr = layout.get_sidebar_bufnr()

      layout.open()
      local second_bufnr = layout.get_sidebar_bufnr()

      assert.are.equal(first_bufnr, second_bufnr)
    end)

    it('accepts position option', function()
      layout.open({ position = 'right' })

      assert.is_true(layout.is_open())
    end)
  end)

  describe('close', function()
    it('unmounts sidebar split', function()
      layout.open()
      assert.is_true(layout.is_open())

      layout.close()

      assert.is_false(layout.is_open())
      assert.is_nil(layout.get_sidebar_bufnr())
      assert.is_nil(layout.get_sidebar_winid())
    end)

    it('is no-op when already closed', function()
      assert.is_false(layout.is_open())

      layout.close()

      assert.is_false(layout.is_open())
    end)
  end)

  describe('toggle', function()
    it('opens when closed', function()
      assert.is_false(layout.is_open())

      layout.toggle()

      assert.is_true(layout.is_open())
    end)

    it('closes when open', function()
      layout.open()
      assert.is_true(layout.is_open())

      layout.toggle()

      assert.is_false(layout.is_open())
    end)

    it('accepts position option on open', function()
      layout.toggle({ position = 'right' })

      assert.is_true(layout.is_open())
    end)
  end)

  describe('is_open', function()
    it('returns false when closed', function()
      assert.is_false(layout.is_open())
    end)

    it('returns true when open', function()
      layout.open()

      assert.is_true(layout.is_open())
    end)
  end)

  describe('get_sidebar_bufnr', function()
    it('returns nil when closed', function()
      assert.is_nil(layout.get_sidebar_bufnr())
    end)

    it('returns valid buffer number when open', function()
      layout.open()
      local bufnr = layout.get_sidebar_bufnr()

      assert.is_not_nil(bufnr)
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    end)
  end)

  describe('get_sidebar_winid', function()
    it('returns nil when closed', function()
      assert.is_nil(layout.get_sidebar_winid())
    end)

    it('returns valid window ID when open', function()
      layout.open()
      local winid = layout.get_sidebar_winid()

      assert.is_not_nil(winid)
      assert.is_true(vim.api.nvim_win_is_valid(winid))
    end)
  end)
end)

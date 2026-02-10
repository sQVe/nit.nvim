local signs = require('nit.display.signs')

describe('signs', function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn['repeat']({ 'line' }, 10))
    signs.setup()
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('setup()', function()
    it('defines NitComment sign', function()
      local defined = vim.fn.sign_getdefined('NitComment')
      assert.is_table(defined)
      assert.is_true(#defined > 0)
      assert.is_string(defined[1].text)
    end)

    it('defines NitCommentResolved sign', function()
      local defined = vim.fn.sign_getdefined('NitCommentResolved')
      assert.is_table(defined)
      assert.is_true(#defined > 0)
      assert.is_string(defined[1].text)
    end)
  end)

  describe('place()', function()
    it('places sign at correct line for single RIGHT-side thread', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      assert.is_table(placed)
      assert.is_true(#placed > 0)
      local signs_list = placed[1].signs
      assert.equals(1, #signs_list)
      assert.equals(5, signs_list[1].lnum)
      assert.equals('NitComment', signs_list[1].name)
    end)

    it('uses NitCommentResolved for resolved threads', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = true, comments = {} },
      }
      signs.place(bufnr, threads)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals('NitCommentResolved', signs_list[1].name)
    end)

    it('skips LEFT-side threads', function()
      local threads = {
        { id = '1', line = 5, side = 'LEFT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals(0, #signs_list)
    end)

    it('skips threads with nil line', function()
      local threads = {
        { id = '1', line = nil, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals(0, #signs_list)
    end)

    it('places multiple signs for multiple threads', function()
      local threads = {
        { id = '1', line = 3, side = 'RIGHT', isResolved = false, comments = {} },
        { id = '2', line = 7, side = 'RIGHT', isResolved = true, comments = {} },
      }
      signs.place(bufnr, threads)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals(2, #signs_list)
    end)
  end)

  describe('clear()', function()
    it('removes all signs from buffer', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)
      signs.clear(bufnr)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals(0, #signs_list)
    end)

    it('is idempotent on buffer with no signs', function()
      signs.clear(bufnr)

      local placed = vim.fn.sign_getplaced(bufnr, { group = 'nit_comments' })
      local signs_list = placed[1].signs
      assert.equals(0, #signs_list)
    end)
  end)
end)

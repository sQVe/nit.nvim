local signs = require('nit.display.signs')

describe('signs', function()
  local bufnr
  local sign_ns = vim.api.nvim_create_namespace('nit_comments')

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn['repeat']({ 'line' }, 10))
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('place()', function()
    it('places sign at correct line for single RIGHT-side thread', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal(4, marks[1][2])
      assert.are.equal('NitCommentSign', marks[1][4].sign_hl_group)
    end)

    it('uses NitCommentResolvedSign for resolved threads', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = true, comments = {} },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NitCommentResolvedSign', marks[1][4].sign_hl_group)
    end)

    it('uses NitCommentOutdatedSign for outdated threads', function()
      local threads = {
        {
          id = '1',
          line = 5,
          side = 'RIGHT',
          isOutdated = true,
          isResolved = false,
          comments = {},
        },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(1, #marks)
      assert.are.equal('NitCommentOutdatedSign', marks[1][4].sign_hl_group)
    end)

    it('skips LEFT-side threads', function()
      local threads = {
        { id = '1', line = 5, side = 'LEFT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(0, #marks)
    end)

    it('skips threads with nil line', function()
      local threads = {
        { id = '1', line = nil, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(0, #marks)
    end)

    it('places multiple signs for multiple threads', function()
      local threads = {
        { id = '1', line = 3, side = 'RIGHT', isResolved = false, comments = {} },
        { id = '2', line = 7, side = 'RIGHT', isResolved = true, comments = {} },
      }
      signs.place(bufnr, threads)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(2, #marks)
    end)
  end)

  describe('clear()', function()
    it('removes all signs from buffer', function()
      local threads = {
        { id = '1', line = 5, side = 'RIGHT', isResolved = false, comments = {} },
      }
      signs.place(bufnr, threads)
      signs.clear(bufnr)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(0, #marks)
    end)

    it('is idempotent on buffer with no signs', function()
      signs.clear(bufnr)

      local marks = vim.api.nvim_buf_get_extmarks(bufnr, sign_ns, 0, -1, { details = true })
      assert.are.equal(0, #marks)
    end)
  end)
end)

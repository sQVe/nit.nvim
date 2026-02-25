local highlights = require('nit.display.highlights')

describe('highlights', function()
  local bufnr
  local ns_id

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn['repeat']({ 'test line' }, 10))
    ns_id = highlights.get_namespace()
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  describe('get_namespace()', function()
    it('returns a namespace id', function()
      assert.is_number(ns_id)
      assert.is_true(ns_id >= 0)
    end)
  end)

  describe('set()', function()
    it('places extmark for single-line RIGHT-side thread', function()
      local thread = { line = 5, side = 'RIGHT', isResolved = false }
      highlights.set(bufnr, thread)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
      assert.are.equal(1, #extmarks)
      local mark = extmarks[1]
      assert.are.equal(4, mark[2]) -- 0-indexed row (line 5 = row 4)
      assert.is_table(mark[4])
      assert.are.equal('NitCommentHighlight', mark[4].hl_group)
      assert.are.equal(5, mark[4].end_row) -- exclusive end
      assert.are.equal(0, mark[4].end_col)
    end)

    it('places extmark for multi-line thread using start_line', function()
      local thread = { start_line = 3, line = 5, side = 'RIGHT', isResolved = false }
      highlights.set(bufnr, thread)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
      assert.are.equal(1, #extmarks)
      local mark = extmarks[1]
      assert.are.equal(2, mark[2]) -- start_line 3 = row 2
      assert.are.equal(5, mark[4].end_row) -- line 5 = exclusive row 5 (covers lines 3-5)
      assert.are.equal(0, mark[4].end_col)
    end)

    it('handles single-line thread when start_line is nil', function()
      local thread = { start_line = nil, line = 7, side = 'RIGHT', isResolved = false }
      highlights.set(bufnr, thread)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, { details = true })
      assert.are.equal(1, #extmarks)
      local mark = extmarks[1]
      assert.are.equal(6, mark[2]) -- line 7 = row 6
      assert.are.equal(7, mark[4].end_row) -- exclusive end at row 7
    end)

    it('skips LEFT-side threads', function()
      local thread = { line = 5, side = 'LEFT', isResolved = false }
      highlights.set(bufnr, thread)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #extmarks)
    end)

    it('skips threads with nil line', function()
      local thread = { line = nil, side = 'RIGHT', isResolved = false }
      highlights.set(bufnr, thread)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #extmarks)
    end)
  end)

  describe('clear()', function()
    it('removes all extmarks from buffer', function()
      local thread = { line = 5, side = 'RIGHT', isResolved = false }
      highlights.set(bufnr, thread)
      highlights.clear(bufnr)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #extmarks)
    end)

    it('is idempotent on buffer with no extmarks', function()
      highlights.clear(bufnr)

      local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #extmarks)
    end)
  end)
end)

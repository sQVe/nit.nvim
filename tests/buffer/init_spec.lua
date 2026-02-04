describe('nit.buffer', function()
  local buffer = require('nit.buffer.init')
  local state = require('nit.state')

  after_each(function()
    state.reset()
  end)

  describe('render', function()
    it('renders PR content to buffer', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local pr = {
        number = 123,
        title = 'Test PR',
        state = 'open',
        isDraft = false,
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T12:00:00Z',
        body = 'Test description',
      }

      buffer.render(bufnr, { pr = pr, comments = {} })

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.is_true(#lines > 0)
      assert.equals('# Test PR', lines[1])
    end)

    it('sets filetype to nit', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local pr = {
        number = 123,
        title = 'Test PR',
        state = 'open',
        isDraft = false,
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T12:00:00Z',
        body = 'Test description',
      }

      buffer.render(bufnr, { pr = pr, comments = {} })

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      assert.equals('nit', ft)
    end)

    it('shows error when no PR', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      buffer.render(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.is_true(vim.tbl_contains(lines, '# Error'))
    end)

    it('sets buffer as not modifiable', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      local pr = {
        number = 123,
        title = 'Test PR',
        state = 'open',
        isDraft = false,
        author = { login = 'testuser' },
        createdAt = '2026-01-01T00:00:00Z',
        updatedAt = '2026-01-01T12:00:00Z',
        body = 'Test description',
      }

      buffer.render(bufnr, { pr = pr, comments = {} })

      local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = bufnr })
      assert.is_false(modifiable)
    end)
  end)

  describe('render_loading', function()
    it('shows loading message', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      buffer.render_loading(bufnr)

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.is_true(vim.tbl_contains(lines, 'Loading PR...'))
    end)

    it('sets filetype to nit', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      buffer.render_loading(bufnr)

      local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
      assert.equals('nit', ft)
    end)
  end)

  describe('render_error', function()
    it('shows error message with retry hint', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      buffer.render_error(bufnr, 'Test error message')

      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      assert.is_true(vim.tbl_contains(lines, '# Error'))
      assert.is_true(vim.tbl_contains(lines, 'Test error message'))
      assert.is_true(vim.tbl_contains(lines, 'Use :Nit refresh to retry'))
    end)

    it('sets buffer as not modifiable', function()
      local bufnr = vim.api.nvim_create_buf(false, true)

      buffer.render_error(bufnr, 'Test error')

      local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = bufnr })
      assert.is_false(modifiable)
    end)
  end)
end)

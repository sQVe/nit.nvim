local sections = require('nit.buffer.sections')
local state = require('nit.state')

local M = {}

local initialized = false

---Initialize buffer filetype and treesitter support
local function init()
  if initialized then
    return
  end
  initialized = true

  vim.filetype.add({ extension = { nit = 'nit' } })
  vim.treesitter.language.register('markdown', 'nit')

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'nit',
    callback = function(args)
      if vim.treesitter.language.add('markdown') then
        vim.treesitter.start(args.buf, 'markdown')
      end
    end,
  })
end

---Render PR content to buffer
---@param bufnr integer Buffer number
---@param opts? Nit.Buffer.RenderOpts Render options
function M.render(bufnr, opts)
  init()
  opts = opts or {}
  local pr = opts.pr or state.get_pr()
  local comments = opts.comments or state.get_comments()

  if not pr then
    M.render_error(bufnr, 'No PR loaded')
    return
  end

  local lines = {}

  vim.list_extend(lines, sections.metadata(pr))
  vim.list_extend(lines, sections.separator())
  vim.list_extend(lines, sections.description(pr))
  vim.list_extend(lines, sections.separator())
  vim.list_extend(lines, sections.comments(comments))

  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
  vim.api.nvim_set_option_value('swapfile', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'nit', { buf = bufnr })
end

---Render loading state to buffer
---@param bufnr integer Buffer number
function M.render_loading(bufnr)
  init()
  local lines = {
    'Loading PR...',
    '',
    'Fetching data from GitHub...',
  }

  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'nit', { buf = bufnr })
end

---Render error state to buffer
---@param bufnr integer Buffer number
---@param message string Error message
function M.render_error(bufnr, message)
  init()
  local lines = {
    '# Error',
    '',
    message,
    '',
    'Use :Nit refresh to retry',
  }

  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'nit', { buf = bufnr })
end

return M

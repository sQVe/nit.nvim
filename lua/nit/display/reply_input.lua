---Reply input window for thread panel
---@class Nit.Display.ReplyInput
local M = {}

---@type integer?
local input_bufnr = nil

---@type integer?
local input_winid = nil

---Open the input window below the given panel window
---@param panel_winid integer
---@return boolean success
function M.open(panel_winid)
  if M.is_open() then
    return true
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })

  local winid = vim.api.nvim_open_win(bufnr, false, {
    split = 'below',
    win = panel_winid,
    height = 5,
  })

  vim.wo[winid].winfixheight = true
  vim.wo[winid].number = false
  vim.wo[winid].relativenumber = false
  vim.wo[winid].signcolumn = 'no'
  vim.wo[winid].fillchars = 'eob: '
  vim.wo[winid].winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder'
  vim.wo[winid].winbar = '%#NitThreadHintKey# C-s%#NitThreadHintLabel# Submit%*'

  input_bufnr = bufnr
  input_winid = winid
  return true
end

---Close the input window and wipe the buffer
function M.close()
  local winid = input_winid
  local bufnr = input_bufnr
  input_winid = nil
  input_bufnr = nil
  if winid ~= nil and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---Check if input window is open and valid
---@return boolean
function M.is_open()
  return input_winid ~= nil and vim.api.nvim_win_is_valid(input_winid)
end

---Get trimmed text from the input buffer
---@return string
function M.get_text()
  if not M.is_open() or input_bufnr == nil then
    return ''
  end
  local lines = vim.api.nvim_buf_get_lines(input_bufnr, 0, -1, false)
  return vim.trim(table.concat(lines, '\n'))
end

---Set text in the input buffer
---@param text string
function M.set_text(text)
  if not M.is_open() or input_bufnr == nil then
    return
  end
  local lines = vim.split(text, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, lines)
end

---Clear the input buffer
function M.clear()
  if not M.is_open() or input_bufnr == nil then
    return
  end
  vim.api.nvim_buf_set_lines(input_bufnr, 0, -1, false, {})
end

---Get the input buffer number
---@return integer?
function M.get_bufnr()
  if not M.is_open() then
    return nil
  end
  return input_bufnr
end

---Get the input window ID
---@return integer?
function M.get_winid()
  if not M.is_open() then
    return nil
  end
  return input_winid
end

---Map a key in the input buffer
---@param mode string|string[]
---@param lhs string
---@param rhs function|string
---@param opts table?
function M.map(mode, lhs, rhs, opts)
  if input_bufnr == nil then
    return
  end
  opts = opts or {}
  opts.buffer = input_bufnr
  vim.keymap.set(mode, lhs, rhs, opts)
end

return M

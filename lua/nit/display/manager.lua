---Display manager coordinates signs, highlights, and popup lifecycle
---@class Nit.Display.Manager
local M = {}

local data = require('nit.state.data')
local observers = require('nit.state.observers')
local signs = require('nit.display.signs')
local highlights = require('nit.display.highlights')
local thread_panel = require('nit.display.thread_panel')

---@class Nit.Display.BufferState
---@field filepath string File path this buffer is attached to
---@field unsubscribe function Unsubscribe from state observer
---@field autocmd_ids integer[] Autocmd IDs for cleanup
---@field commented_lines table<integer, Nit.Api.Thread> Line number to thread lookup

---@type table<integer, Nit.Display.BufferState>
local attached_buffers = {}

local augroup = vim.api.nvim_create_augroup('NitCommentDisplay', { clear = true })

---Filter threads to displayable ones (RIGHT side, not outdated, with line numbers)
---@param threads Nit.Api.Thread[]
---@return Nit.Api.Thread[]
local function filter_displayable(threads)
  local result = {}
  for _, thread in ipairs(threads) do
    if thread.side == 'RIGHT' and thread.line ~= nil and not thread.isOutdated then
      table.insert(result, thread)
    end
  end
  return result
end

---Build line number to thread lookup table
---@param threads Nit.Api.Thread[]
---@return table<integer, Nit.Api.Thread>
local function build_line_lookup(threads)
  local lookup = {}
  for _, thread in ipairs(threads) do
    if thread.line ~= nil and not lookup[thread.line] then
      lookup[thread.line] = thread
    end
  end
  return lookup
end

---Update display for a buffer (called on attach and state changes)
---@param bufnr integer
---@param filepath string
---@param commented_lines table<integer, Nit.Api.Thread>
local function update_display(bufnr, filepath, commented_lines)
  local threads = data.get_threads_for_file(filepath)
  local displayable = filter_displayable(threads)

  signs.clear(bufnr)
  signs.place(bufnr, displayable)

  for k in pairs(commented_lines) do
    commented_lines[k] = nil
  end
  for line, thread in pairs(build_line_lookup(displayable)) do
    commented_lines[line] = thread
  end

  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if ok then
    local current_line = cursor[1]
    highlights.clear(bufnr)
    if commented_lines[current_line] then
      highlights.set(bufnr, commented_lines[current_line])
    end
  end
end

---Setup sign definitions and highlights (called once during plugin init)
function M.setup()
  require('nit.ui.highlights').setup()
  signs.setup()
end

---Attach display manager to a buffer
---@param bufnr integer Buffer number
---@param filepath string File path for this buffer
function M.attach(bufnr, filepath)
  if attached_buffers[bufnr] then
    return
  end

  local commented_lines = {}
  local state = {
    filepath = filepath,
    autocmd_ids = {},
    commented_lines = commented_lines,
    unsubscribe = function() end,
  }

  update_display(bufnr, filepath, commented_lines)

  local cursor_autocmd = vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
      if not ok then
        return
      end
      local current_line = cursor[1]
      highlights.clear(bufnr)
      local thread = commented_lines[current_line]
      if thread then
        highlights.set(bufnr, thread)
        if thread_panel.is_open() then
          thread_panel.show(thread)
        end
      end
    end,
  })
  table.insert(state.autocmd_ids, cursor_autocmd)

  state.unsubscribe = observers.subscribe('comments', function()
    update_display(bufnr, filepath, commented_lines)
  end)

  local delete_autocmd = vim.api.nvim_create_autocmd('BufDelete', {
    group = augroup,
    buffer = bufnr,
    callback = function()
      M.detach(bufnr)
    end,
  })
  table.insert(state.autocmd_ids, delete_autocmd)

  attached_buffers[bufnr] = state
end

---Detach display manager from a buffer
---@param bufnr integer Buffer number
function M.detach(bufnr)
  local state = attached_buffers[bufnr]
  if not state then
    return
  end

  state.unsubscribe()

  for _, id in ipairs(state.autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, id)
  end

  signs.clear(bufnr)
  highlights.clear(bufnr)

  attached_buffers[bufnr] = nil
end

---Detach from all buffers
function M.detach_all()
  local buffers = vim.tbl_keys(attached_buffers)
  for _, bufnr in ipairs(buffers) do
    M.detach(bufnr)
  end
end

---Show thread panel for thread at cursor
---@param bufnr integer Buffer number (0 for current buffer)
function M.show_thread_panel(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local state = attached_buffers[bufnr]
  if not state then
    return
  end

  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if not ok then
    return
  end

  local current_line = cursor[1]
  local thread = state.commented_lines[current_line]
  if thread then
    thread_panel.show(thread)
  end
end

---Show comment popup for thread at cursor (backward compatibility wrapper)
---@param bufnr integer Buffer number
function M.show_popup(bufnr)
  M.show_thread_panel(bufnr)
end

---Close the thread panel
function M.close_thread_panel()
  thread_panel.close()
end

---Get thread at cursor position
---@param bufnr integer Buffer number (0 for current buffer)
---@return Nit.Api.Thread?
function M.get_thread_at_cursor(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local state = attached_buffers[bufnr]
  if not state then
    return nil
  end

  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if not ok then
    return nil
  end

  local current_line = cursor[1]
  return state.commented_lines[current_line]
end

---Get commented lines for a buffer
---@param bufnr integer Buffer number (0 for current buffer)
---@return table<integer, Nit.Api.Thread>?
function M.get_commented_lines(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local state = attached_buffers[bufnr]
  if not state then
    return nil
  end
  return state.commented_lines
end

return M

---@class Nit.Ui.Layout
local M = {}

local Split = require('nui.split')
local highlights = require('nit.ui.highlights')

local SIDEBAR_WIDTH = 40

local sidebar_split = nil
local sidebar_position = 'left'
local highlights_initialized = false

---@type fun()?
local on_close_callback = nil

---@alias Nit.Ui.LayoutPosition 'left'|'right'

---@class Nit.Ui.Layout.OpenOpts
---@field position? Nit.Ui.LayoutPosition Sidebar position (default: 'left')
---@field on_close? fun() Callback when sidebar is closed externally

---Open the layout sidebar
---@param opts? Nit.Ui.Layout.OpenOpts
function M.open(opts)
  if sidebar_split then
    return
  end

  opts = opts or {}
  local position = opts.position or 'left'
  sidebar_position = position
  on_close_callback = opts.on_close

  if not highlights_initialized then
    highlights.setup()
    highlights_initialized = true
  end

  sidebar_split = Split({
    relative = 'editor',
    position = position,
    size = SIDEBAR_WIDTH,
    buf_options = {
      buftype = 'nofile',
      bufhidden = 'hide',
      swapfile = false,
      modifiable = false,
    },
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = 'no',
      winfixwidth = true,
      cursorline = true,
      wrap = false,
    },
  })

  sidebar_split:mount()

  vim.api.nvim_create_autocmd('WinClosed', {
    buffer = sidebar_split.bufnr,
    once = true,
    callback = function()
      sidebar_split = nil
      if on_close_callback then
        on_close_callback()
        on_close_callback = nil
      end
    end,
  })
end

---Close the layout sidebar
function M.close()
  if not sidebar_split then
    return
  end

  on_close_callback = nil
  sidebar_split:unmount()
  sidebar_split = nil
end

---Toggle the layout sidebar
---@param opts? Nit.Ui.Layout.OpenOpts
function M.toggle(opts)
  if sidebar_split then
    M.close()
  else
    M.open(opts)
  end
end

---Check if the layout is currently open
---@return boolean
function M.is_open()
  return sidebar_split ~= nil
end

---Get the sidebar buffer number
---@return number? bufnr Buffer number, or nil if not open
function M.get_sidebar_bufnr()
  if not sidebar_split then
    return nil
  end
  return sidebar_split.bufnr
end

---Get the sidebar width
---@return integer
function M.get_width()
  return SIDEBAR_WIDTH
end

---Get the sidebar window ID
---@return number? winid Window ID, or nil if not open
function M.get_sidebar_winid()
  if not sidebar_split then
    return nil
  end
  return sidebar_split.winid
end

---Find the main editing window (not the sidebar) and execute a callback in it.
---Restores focus to the sidebar after the callback completes unless opts.stay is true.
---@param callback fun(winid: number)
---@param opts? { stay?: boolean }
function M.open_in_main_window(callback, opts)
  opts = opts or {}
  local sidebar_winid = M.get_sidebar_winid()

  local main_winid = vim.fn.win_getid(vim.fn.winnr('#'))
  if not main_winid or main_winid == 0 or main_winid == sidebar_winid then
    local direction = sidebar_position == 'right' and 'h' or 'l'
    vim.cmd('wincmd ' .. direction)
    main_winid = vim.api.nvim_get_current_win()
  end

  if main_winid == sidebar_winid or not vim.api.nvim_win_is_valid(main_winid) then
    vim.cmd('vsplit')
    main_winid = vim.api.nvim_get_current_win()
  end

  callback(main_winid)

  if not opts.stay and sidebar_winid and vim.api.nvim_win_is_valid(sidebar_winid) then
    vim.api.nvim_set_current_win(sidebar_winid)
  end
end

return M

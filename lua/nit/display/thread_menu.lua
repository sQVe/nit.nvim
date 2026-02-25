---Thread action menu
---@class Nit.Display.ThreadMenu
local M = {}

local Popup = require('nui.popup')

---@type any?
local active_popup = nil

---Open the action menu for a thread
---@param thread Nit.Api.Thread
---@param callbacks { on_toggle_resolved: fun() }
function M.open(thread, callbacks)
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end

  local resolve_label = thread.isResolved and 'r  Unresolve thread' or 'r  Resolve thread'
  local lines = { resolve_label }

  local actions = {
    function()
      M.close()
      callbacks.on_toggle_resolved()
    end,
  }

  local popup = Popup({
    position = '50%',
    size = { width = 30, height = #lines },
    relative = 'editor',
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = { top = ' Actions ', top_align = 'center' },
    },
    buf_options = {
      modifiable = true,
    },
  })

  popup:mount()

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = popup.bufnr })

  popup:map('n', 'r', actions[1], { noremap = true })

  popup:map('n', '<CR>', function()
    local line_index = vim.api.nvim_win_get_cursor(popup.winid)[1]
    local action = actions[line_index]
    if action then
      action()
    end
  end, { noremap = true })

  popup:map('n', 'q', function()
    M.close()
  end, { noremap = true })

  popup:map('n', '<Esc>', function()
    M.close()
  end, { noremap = true })

  active_popup = popup
end

---Close the action menu
function M.close()
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end
end

---Check if menu is open
---@return boolean
function M.is_open()
  return active_popup ~= nil
end

return M

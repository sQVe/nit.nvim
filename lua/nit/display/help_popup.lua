---Help popup for keybinding hints
---@class Nit.Display.HelpPopup
local M = {}

local Popup = require('nui.popup')

---@type any?
local active_popup = nil

---Format hints into aligned display lines
---@param hints {key: string, label: string}[]
---@return string[]
function M.format_hint_lines(hints)
  if #hints == 0 then
    return {}
  end

  local max_key_len = 0
  for _, hint in ipairs(hints) do
    max_key_len = math.max(max_key_len, #hint.key)
  end

  local lines = {}
  for _, hint in ipairs(hints) do
    local padding = string.rep(' ', max_key_len - #hint.key)
    table.insert(lines, '  ' .. padding .. hint.key .. '    ' .. hint.label)
  end

  return lines
end

---Show keybinding help popup
---@param hints {key: string, label: string}[]
function M.show(hints)
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end

  local lines = M.format_hint_lines(hints)
  local width = 40
  local height = math.max(1, #lines)

  local popup = Popup({
    position = '50%',
    size = { width = width, height = height },
    relative = 'editor',
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = { top = ' Keybindings ', top_align = 'center' },
    },
    buf_options = {
      modifiable = true,
    },
  })

  popup:mount()

  pcall(vim.api.nvim_buf_set_lines, popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  popup:map('n', 'q', function()
    M.close()
  end, { noremap = true })

  popup:map('n', '<Esc>', function()
    M.close()
  end, { noremap = true })

  popup:map('n', '?', function()
    M.close()
  end, { noremap = true })

  active_popup = popup
end

---Close the help popup
function M.close()
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end
end

---Check if help popup is open
---@return boolean
function M.is_open()
  return active_popup ~= nil
end

---Toggle the help popup open/closed
---@param hints {key: string, label: string}[]
function M.toggle(hints)
  if M.is_open() then
    M.close()
  else
    M.show(hints)
  end
end

return M

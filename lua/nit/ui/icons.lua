---Icon management with nvim-web-devicons fallback
---@class Nit.Ui.Icons
local M = {}

local has_devicons = nil

---Check if nvim-web-devicons is available
---@return boolean
local function check_devicons()
  if has_devicons ~= nil then
    return has_devicons
  end
  local ok, _ = pcall(require, 'nvim-web-devicons')
  has_devicons = ok
  return has_devicons
end

---Get file icon and highlight group
---@param filename string
---@return string icon Icon character
---@return string highlight Highlight group name
function M.get_icon(filename)
  if check_devicons() then
    local devicons = require('nvim-web-devicons')
    local ext = vim.fn.fnamemodify(filename, ':e')
    local icon, hl = devicons.get_icon(filename, ext, { default = true })
    return icon or '', hl or 'NitIcon'
  end
  return '', 'NitIcon'
end

M.overview = '󰓂'
M.files = ''
M.comment = ''
M.resolved = ''
M.folder_open = ''
M.folder_closed = ''

return M

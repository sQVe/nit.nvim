---@class Nit.Ui.Highlights
local M = {}

---Setup highlight groups used by the display system.
---All highlights use `default = true` so user customizations take precedence.
function M.setup()
  vim.api.nvim_set_hl(0, 'NitCommentSign', { link = 'DiagnosticSignInfo', default = true })
  vim.api.nvim_set_hl(0, 'NitCommentResolvedSign', { link = 'DiagnosticSignHint', default = true })
  local cursor_line_hl = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false })
  if cursor_line_hl.bg then
    vim.api.nvim_set_hl(0, 'NitCommentHighlight', { bg = cursor_line_hl.bg, default = true })
  else
    vim.api.nvim_set_hl(0, 'NitCommentHighlight', { link = 'CursorLine', default = true })
  end
end

return M

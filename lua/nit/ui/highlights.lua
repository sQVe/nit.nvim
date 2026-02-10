---@class Nit.Ui.Highlights
local M = {}

---Setup highlight groups for the nit.nvim UI
---All highlights use `default = true` so user customizations take precedence
function M.setup()
  vim.api.nvim_set_hl(0, 'NitFileAdded', { link = 'diffAdded', default = true })
  vim.api.nvim_set_hl(0, 'NitFileModified', { link = 'diffChanged', default = true })
  vim.api.nvim_set_hl(0, 'NitFileRemoved', { link = 'diffRemoved', default = true })
  vim.api.nvim_set_hl(0, 'NitFileRenamed', { link = 'diffChanged', default = true })
  vim.api.nvim_set_hl(0, 'NitCommentAuthor', { link = 'Special', default = true })
  vim.api.nvim_set_hl(0, 'NitCommentResolved', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'NitOverview', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'NitSectionHeader', { link = 'Label', default = true })
  vim.api.nvim_set_hl(0, 'NitFileStats', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'NitDirectoryHeader', { link = 'Directory', default = true })
  local comment_hl = vim.api.nvim_get_hl(0, { name = 'Comment', link = false })
  vim.api.nvim_set_hl(
    0,
    'NitDirectoryCollapsed',
    { fg = comment_hl.fg, italic = false, default = true }
  )
  vim.api.nvim_set_hl(0, 'NitIcon', { link = 'Normal', default = true })
  vim.api.nvim_set_hl(0, 'NitIndentMarker', { link = 'Comment', default = true })
end

return M

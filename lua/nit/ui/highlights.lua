---@class Nit.Ui.Highlights
local M = {}

---@param fg integer
---@param bg integer
---@param alpha number 0.0 = all bg, 1.0 = all fg
---@return integer
local function blend(fg, bg, alpha)
  local fg_r = math.floor(fg / 65536) % 256
  local fg_g = math.floor(fg / 256) % 256
  local fg_b = fg % 256
  local bg_r = math.floor(bg / 65536) % 256
  local bg_g = math.floor(bg / 256) % 256
  local bg_b = bg % 256
  local r = math.floor(fg_r * alpha + bg_r * (1 - alpha))
  local g = math.floor(fg_g * alpha + bg_g * (1 - alpha))
  local b = math.floor(fg_b * alpha + bg_b * (1 - alpha))
  return r * 65536 + g * 256 + b
end

---@return integer?
local function get_accent_color()
  for _, name in ipairs({ 'DiagnosticInfo', 'DiagnosticHint', 'Comment' }) do
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    if hl.fg then
      return hl.fg
    end
  end
  return nil
end

---Setup highlight groups used by the display system.
---All highlights use `default = true` so user customizations take precedence.
function M.setup()
  vim.api.nvim_set_hl(0, 'NitCommentSign', { link = 'DiagnosticSignInfo', default = true })
  vim.api.nvim_set_hl(0, 'NitCommentResolvedSign', { link = 'DiagnosticSignHint', default = true })
  vim.api.nvim_set_hl(0, 'NitCommentOutdatedSign', { link = 'DiagnosticSignWarn', default = true })

  vim.api.nvim_set_hl(0, 'NitThreadTitle', { link = 'Title', default = true })
  vim.api.nvim_set_hl(0, 'NitThreadTitleResolved', { link = 'DiagnosticOk', default = true })
  vim.api.nvim_set_hl(0, 'NitThreadAuthor', { link = 'Special', default = true })
  vim.api.nvim_set_hl(0, 'NitThreadHintKey', { link = 'Special', default = true })
  vim.api.nvim_set_hl(0, 'NitThreadHintLabel', { link = 'Comment', default = true })

  local cursor_line_hl = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false })
  local base_bg = cursor_line_hl.bg
  local accent = get_accent_color()

  if base_bg and accent then
    vim.api.nvim_set_hl(
      0,
      'NitCommentHighlight',
      { bg = blend(accent, base_bg, 0.2), default = true }
    )
  else
    vim.api.nvim_set_hl(0, 'NitCommentHighlight', { link = 'CursorLine', default = true })
  end

  local float_hl = vim.api.nvim_get_hl(0, { name = 'NormalFloat', link = false })
  local float_bg = float_hl.bg

  if float_bg and accent then
    vim.api.nvim_set_hl(
      0,
      'NitThreadCommentAlt',
      { bg = blend(accent, float_bg, 0.1), default = true }
    )
  else
    vim.api.nvim_set_hl(0, 'NitThreadCommentAlt', { link = 'CursorLine', default = true })
  end
end

return M

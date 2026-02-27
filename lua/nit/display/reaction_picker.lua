---Reaction picker popup
---@class Nit.Display.ReactionPicker
local M = {}

local Popup = require('nui.popup')

---@type any?
local active_popup = nil

---@type { content: Nit.Api.ReactionContent, emoji: string }[]
local REACTIONS = {
  { content = 'THUMBS_UP', emoji = '👍' },
  { content = 'THUMBS_DOWN', emoji = '👎' },
  { content = 'LAUGH', emoji = '😄' },
  { content = 'HOORAY', emoji = '🎉' },
  { content = 'CONFUSED', emoji = '😕' },
  { content = 'HEART', emoji = '❤️' },
  { content = 'ROCKET', emoji = '🚀' },
  { content = 'EYES', emoji = '👀' },
}

---Open the reaction picker for a comment
---@param opts { comment: Nit.Api.Comment, on_toggle: fun(content: Nit.Api.ReactionContent) }
function M.open(opts)
  M.close()

  local comment = opts.comment
  local on_toggle = opts.on_toggle

  local lines = {}
  for i, r in ipairs(REACTIONS) do
    local count = 0
    local viewer_has_reacted = false
    for _, rg in ipairs(comment.reactions or {}) do
      if rg.content == r.content then
        count = rg.count or 0
        viewer_has_reacted = rg.viewer_has_reacted == true
        break
      end
    end

    local line = tostring(i) .. '  ' .. r.emoji
    if count > 0 then
      line = line .. '  ' .. tostring(count)
    end
    if viewer_has_reacted then
      line = line .. '  ✓'
    end
    lines[i] = line
  end

  local popup = Popup({
    position = '50%',
    size = { width = 24, height = 8 },
    relative = 'editor',
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = { top = ' React ', top_align = 'center' },
    },
    buf_options = {
      modifiable = true,
    },
  })

  popup:mount()

  pcall(vim.api.nvim_buf_set_lines, popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  for i, r in ipairs(REACTIONS) do
    local content = r.content
    popup:map('n', tostring(i), function()
      M.close()
      on_toggle(content)
    end, { noremap = true })
  end

  popup:map('n', '<CR>', function()
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, popup.winid)
    if not ok then
      return
    end
    local row = cursor[1]
    local r = REACTIONS[row]
    if r ~= nil then
      local content = r.content
      M.close()
      on_toggle(content)
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

---Close the reaction picker
function M.close()
  if active_popup ~= nil then
    active_popup:unmount()
    active_popup = nil
  end
end

---Check if picker is open
---@return boolean
function M.is_open()
  return active_popup ~= nil
    and active_popup.winid ~= nil
    and vim.api.nvim_win_is_valid(active_popup.winid)
end

return M

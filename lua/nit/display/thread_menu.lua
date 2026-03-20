---Thread action menu
---@class Nit.Display.ThreadMenu
local M = {}

local Popup = require('nui.popup')

---@type any?
local active_popup = nil

local MENU_CONTENT_WIDTH = 28

---Format a menu item label with the hotkey right-aligned
---@param text string The descriptive label text
---@param key string The single hotkey character
---@return string
local function right_align_label(text, key)
  local padding = MENU_CONTENT_WIDTH - #text - #key
  if padding < 1 then
    padding = 1
  end
  return text .. string.rep(' ', padding) .. key
end

---@class Nit.Display.MenuItem
---@field key string
---@field label string
---@field action fun()

---@class Nit.Display.ThreadMenuOpts
---@field thread Nit.Api.Thread
---@field on_toggle_resolved fun()
---@field comment table?
---@field viewer_login string?
---@field on_quote_reply (fun(comment: table))?
---@field on_edit_comment (fun())?
---@field on_apply_suggestion (fun())?
---@field on_react (fun())?
---@field in_reply_input boolean?

---Build context-sensitive menu items
---@param opts Nit.Display.ThreadMenuOpts
---@return Nit.Display.MenuItem[]
function M.build_menu_items(opts)
  local items = {}

  local resolve_text = opts.thread.isResolved and 'Unresolve thread' or 'Resolve thread'
  items[#items + 1] = {
    key = 'r',
    label = right_align_label(resolve_text, 'r'),
    action = opts.on_toggle_resolved,
  }

  if opts.comment ~= nil and opts.on_quote_reply ~= nil and not opts.in_reply_input then
    ---@type table
    local comment = opts.comment
    items[#items + 1] = {
      key = 'q',
      label = right_align_label('Quote reply', 'q'),
      action = function()
        opts.on_quote_reply(comment)
      end,
    }
  end

  if
    opts.comment ~= nil
    and opts.on_edit_comment ~= nil
    and opts.viewer_login ~= nil
    and opts.viewer_login == opts.comment.author.login
    and opts.comment._optimistic_id == nil
  then
    items[#items + 1] = {
      key = 'e',
      label = right_align_label('Edit comment', 'e'),
      action = opts.on_edit_comment,
    }
  end

  if
    opts.comment ~= nil
    and opts.on_apply_suggestion ~= nil
    and opts.comment._optimistic_id == nil
    and opts.comment.body:find('```suggestion', 1, true) ~= nil
  then
    items[#items + 1] = {
      key = 'a',
      label = right_align_label('Apply suggestion', 'a'),
      action = opts.on_apply_suggestion,
    }
  end

  if opts.comment ~= nil and opts.on_react ~= nil and opts.comment._optimistic_id == nil then
    items[#items + 1] = {
      key = 'z',
      label = right_align_label('React', 'z'),
      action = opts.on_react,
    }
  end

  return items
end

---Open the action menu for a thread
---@param opts Nit.Display.ThreadMenuOpts
function M.open(opts)
  if active_popup ~= nil then
    active_popup:unmount()
    active_popup = nil
  end

  local items = M.build_menu_items(opts)

  local lines = {}
  local actions = {}
  for i, item in ipairs(items) do
    lines[i] = item.label
    actions[i] = function()
      M.close()
      item.action()
    end
  end

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

  pcall(vim.api.nvim_buf_set_lines, popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  for i, item in ipairs(items) do
    popup:map('n', item.key, actions[i], { noremap = true })
  end

  popup:map('n', '<CR>', function()
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, popup.winid)
    if not ok then
      return
    end
    local action = actions[cursor[1]]
    if action ~= nil then
      action()
    end
  end, { noremap = true })

  local item_keys = {}
  for _, item in ipairs(items) do
    item_keys[item.key] = true
  end

  if not item_keys['q'] then
    popup:map('n', 'q', function()
      M.close()
    end, { noremap = true })
  end

  popup:map('n', '<Esc>', function()
    M.close()
  end, { noremap = true })

  active_popup = popup
end

---Close the action menu
function M.close()
  if active_popup ~= nil then
    active_popup:unmount()
    active_popup = nil
  end
end

---Check if menu is open
---@return boolean
function M.is_open()
  return active_popup ~= nil
    and active_popup.winid ~= nil
    and vim.api.nvim_win_is_valid(active_popup.winid)
end

return M

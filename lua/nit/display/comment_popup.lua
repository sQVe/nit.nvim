---Comment popup display
---@class Nit.Display.CommentPopup
local M = {}

local Popup = require('nui.popup')

---@param iso_timestamp string
---@return string
local function format_relative_time(iso_timestamp)
  local year, month, day, hour, min, sec =
    iso_timestamp:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if not year then
    return iso_timestamp
  end

  local parsed_as_local = os.time({
    year = assert(tonumber(year)),
    month = assert(tonumber(month)),
    day = assert(tonumber(day)),
    hour = assert(tonumber(hour)),
    min = assert(tonumber(min)),
    sec = assert(tonumber(sec)),
  })

  local utc_table = os.date('!*t', parsed_as_local)
  assert(type(utc_table) == 'table', 'os.date failed to return table')
  local utc_offset = parsed_as_local - os.time(utc_table)
  local parsed_utc = parsed_as_local + utc_offset

  local diff = os.difftime(os.time(), parsed_utc)

  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    local mins = math.floor(diff / 60)
    return mins .. (mins == 1 and ' minute ago' or ' minutes ago')
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. (hours == 1 and ' hour ago' or ' hours ago')
  elseif diff < 604800 then
    local days = math.floor(diff / 86400)
    return days .. (days == 1 and ' day ago' or ' days ago')
  else
    return string.format('%02d/%02d/%04d', tonumber(month), tonumber(day), tonumber(year))
  end
end

---@type any?
local active_popup = nil

---Format thread comments into display lines
---@param thread Nit.Api.Thread
---@return string[]
function M.format_thread(thread)
  local lines = {}

  for i, comment in ipairs(thread.comments) do
    if i > 1 then
      table.insert(lines, '---')
      table.insert(lines, '')
    end

    local author_line =
      comment.author.login .. ' · ' .. format_relative_time(comment.createdAt)
    table.insert(lines, author_line)
    table.insert(lines, '')

    local body_lines = vim.split(comment.body, '\n', { plain = true })
    for _, body_line in ipairs(body_lines) do
      table.insert(lines, body_line)
    end
  end

  return lines
end

---Format popup title based on thread state
---@param thread Nit.Api.Thread
---@return string
function M.format_title(thread)
  local comment_count = #thread.comments

  if thread.isResolved then
    return ' ✓ Resolved Thread '
  end

  if comment_count > 1 then
    return ' Comment Thread (' .. comment_count .. ' replies) '
  end

  return ' Comment Thread '
end

---Show comment thread in popup
---@param thread Nit.Api.Thread
---@return any Popup instance
function M.show(thread)
  if active_popup then
    active_popup:unmount()
  end

  local content = M.format_thread(thread)
  local title = M.format_title(thread)

  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#content + 2, math.floor(vim.o.lines * 0.6))

  local popup = Popup({
    position = { row = 1, col = 0 },
    size = {
      width = width,
      height = height,
    },
    relative = 'cursor',
    enter = true,
    focusable = true,
    border = {
      style = 'rounded',
      text = {
        top = title,
        top_align = 'center',
      },
    },
    buf_options = {
      filetype = 'markdown',
    },
  })

  popup:mount()

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, content)
  vim.api.nvim_set_option_value('modifiable', false, { buf = popup.bufnr })
  vim.api.nvim_set_option_value('readonly', true, { buf = popup.bufnr })

  popup:map('n', 'q', function()
    popup:unmount()
  end, { noremap = true })

  popup:map('n', '<Esc>', function()
    popup:unmount()
  end, { noremap = true })

  active_popup = popup

  return popup
end

---Close active popup
function M.close()
  if active_popup then
    active_popup:unmount()
    active_popup = nil
  end
end

---Check if popup is open
---@return boolean
function M.is_open()
  return active_popup ~= nil
end

return M

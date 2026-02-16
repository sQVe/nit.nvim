---Thread panel display
---@class Nit.Display.ThreadPanel
local M = {}

---@type table<integer, {key: string, label: string}>
local hint_registry = {}

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

---Format thread comments into display lines
---@param thread Nit.Api.Thread
---@param width? integer Width for horizontal rule (default 40)
---@return string[]
function M.format_thread(thread, width)
  width = width or 40
  local lines = {}

  for i, comment in ipairs(thread.comments) do
    if i > 1 then
      table.insert(lines, string.rep('─', width))
      table.insert(lines, '')
    end

    local author_line = '@'
      .. comment.author.login
      .. ' · '
      .. format_relative_time(comment.createdAt)
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
  local reply_count = #thread.comments - 1

  if thread.isResolved then
    if reply_count == 0 then
      return ' Thread · Resolved '
    elseif reply_count == 1 then
      return ' Thread · Resolved (1 reply) '
    else
      return ' Thread · Resolved (' .. reply_count .. ' replies) '
    end
  else
    if reply_count == 0 then
      return ' Thread '
    elseif reply_count == 1 then
      return ' Thread (1 reply) '
    else
      return ' Thread (' .. reply_count .. ' replies) '
    end
  end
end

---Format keybinding hints from registry
---@return string
function M.format_hints()
  if #hint_registry == 0 then
    return ''
  end

  local parts = {}
  for _, hint in ipairs(hint_registry) do
    table.insert(parts, ' ' .. hint.key .. ' ' .. hint.label)
  end

  return table.concat(parts, '  ')
end

---Register keybinding hints
---@param hints {key: string, label: string}[]
function M.register_hints(hints)
  for _, hint in ipairs(hints) do
    table.insert(hint_registry, hint)
  end
end

---Clear keybinding hint registry
function M.clear_hints()
  hint_registry = {}
end

---Get title highlight group for thread
---@param thread Nit.Api.Thread
---@return string
function M.get_title_highlight(thread)
  if thread.isResolved then
    return 'NitThreadTitleResolved'
  else
    return 'NitThreadTitle'
  end
end

M.register_hints({
  { key = 'q', label = 'Close' },
  { key = 'Esc', label = 'Close' },
})

return M

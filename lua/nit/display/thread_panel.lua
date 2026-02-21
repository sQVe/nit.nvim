---Thread panel display
---@class Nit.Display.ThreadPanel
local M = {}

local Split = require('nui.split')
local help_popup = require('nit.display.help_popup')
local reply_input = require('nit.display.reply_input')
local thread_menu = require('nit.display.thread_menu')
local data = require('nit.state.data')
local observers = require('nit.state.observers')
local orchestration = require('nit.orchestration')

---@type {key: string, label: string}[]
local hint_registry = {
  { key = 'C-s', label = 'Submit reply' },
  { key = 'C-a', label = 'Actions' },
  { key = 'q', label = 'Close' },
  { key = 'Esc', label = 'Close' },
  { key = '?', label = 'Help' },
}

---@type any?
local active_panel = nil

---@type Nit.Api.Thread?
local current_thread = nil

---@type (fun())?
local unsubscribe_comments = nil

local PANEL_WIDTH = 60
local highlight_ns = vim.api.nvim_create_namespace('nit_thread_panel')

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
---@return string[], table<integer, true>
function M.format_thread(thread)
  local lines = {}
  local author_indices = {}

  for i, comment in ipairs(thread.comments) do
    if i > 1 then
      table.insert(lines, '')
    end

    local author_line = ' @'
      .. comment.author.login
      .. ' · '
      .. format_relative_time(comment.createdAt)
    table.insert(lines, author_line)
    author_indices[#lines] = true
    table.insert(lines, '')

    local body = comment.body:gsub('\r', '')
    local body_lines = vim.split(body, '\n', { plain = true })
    for _, body_line in ipairs(body_lines) do
      if body_line == '' then
        table.insert(lines, '')
      else
        table.insert(lines, ' ' .. body_line)
      end
    end
  end

  return lines, author_indices
end

---Format popup title based on thread state
---@param thread Nit.Api.Thread
---@return string
function M.format_title(thread)
  local reply_count = #thread.comments - 1

  if thread.isResolved then
    if reply_count == 0 then
      return ' Thread · Resolved'
    elseif reply_count == 1 then
      return ' Thread · Resolved (1 reply)'
    else
      return ' Thread · Resolved (' .. reply_count .. ' replies)'
    end
  else
    if reply_count == 0 then
      return ' Thread'
    elseif reply_count == 1 then
      return ' Thread (1 reply)'
    else
      return ' Thread (' .. reply_count .. ' replies)'
    end
  end
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

---Get current hint registry
---@return {key: string, label: string}[]
function M.get_hints()
  return hint_registry
end

---Build winbar string with title and ? help indicator
---@param thread Nit.Api.Thread
---@return string
function M.build_winbar(thread)
  local title_hl = M.get_title_highlight(thread)
  local title = '%#' .. title_hl .. '#' .. M.format_title(thread) .. '%*'
  local help_hint = '%#NitThreadHintKey# ?%#NitThreadHintLabel# Help%*'
  return title .. '%=' .. help_hint .. ' '
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

---Submit the reply from the input area
local function submit_reply()
  if not current_thread then
    return
  end
  local body = reply_input.get_text()
  if body == '' then
    return
  end
  reply_input.clear()
  orchestration.submit_reply({ thread_id = current_thread.id, body = body }, function(ok, returned_body)
    if not ok and returned_body then
      reply_input.set_text(returned_body)
    end
  end)
end

---Toggle resolved state of the current thread
local function toggle_resolved()
  if not current_thread then
    return
  end
  orchestration.toggle_resolved({ thread_id = current_thread.id }, function(_ok)
  end)
end

---Open the action menu
local function open_menu()
  if not current_thread then
    return
  end
  thread_menu.open(current_thread, { on_toggle_resolved = toggle_resolved })
end

---Re-render panel when comments state changes
local function on_comments_changed()
  if not current_thread then
    return
  end
  local updated = data.get_thread(current_thread.id)
  if updated then
    M.update(updated)
  end
end

---Show or update the thread panel
---@param thread Nit.Api.Thread
function M.show(thread)
  if active_panel then
    if active_panel.winid and vim.api.nvim_win_is_valid(active_panel.winid) then
      M.update(thread)
      return
    end
    active_panel:unmount()
    active_panel = nil
    current_thread = nil
  end

  local panel = Split({
    relative = 'editor',
    position = 'right',
    size = PANEL_WIDTH,
    enter = false,
    buf_options = {
      filetype = 'markdown',
      modifiable = false,
      buftype = 'nofile',
    },
    win_options = {
      wrap = true,
      linebreak = true,
      breakindent = false,
      showbreak = ' ',
      list = false,
      winfixwidth = true,
      cursorline = false,
      number = false,
      relativenumber = false,
      signcolumn = 'no',
      foldcolumn = '0',
      fillchars = 'eob: ',
      winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
    },
  })

  panel:mount()

  unsubscribe_comments = observers.subscribe('comments', on_comments_changed)

  panel:map('n', 'q', function()
    M.close()
  end, { noremap = true })

  panel:map('n', '<Esc>', function()
    M.close()
  end, { noremap = true })

  panel:map('n', '?', function()
    help_popup.toggle(hint_registry)
  end, { noremap = true })

  panel:map('n', '<C-s>', function()
    submit_reply()
  end, { noremap = true })

  panel:map('n', '<C-a>', function()
    open_menu()
  end, { noremap = true })

  active_panel = panel
  M.update(thread)

  if active_panel.winid and vim.api.nvim_win_is_valid(active_panel.winid) then
    reply_input.open(active_panel.winid)

    reply_input.map({ 'n', 'i' }, '<C-s>', function()
      vim.cmd('stopinsert')
      submit_reply()
    end, { noremap = true })

    reply_input.map('n', '<C-a>', function()
      open_menu()
    end, { noremap = true })

    reply_input.map('n', 'q', function()
      M.close()
    end, { noremap = true })

    reply_input.map('n', '<Esc>', function()
      M.close()
    end, { noremap = true })

    reply_input.map('n', '?', function()
      help_popup.toggle(hint_registry)
    end, { noremap = true })
  end
end

---Compute per-line highlight assignments for author header lines.
---Returns a table mapping 1-based line index to highlight options.
---@param lines string[]
---@param author_indices table<integer, true>
---@return table<integer, {hl_group: string, line_hl_group: string}>
function M.get_line_highlights(lines, author_indices)
  local result = {}
  local comment_index = 0

  for i = 1, #lines do
    if author_indices[i] then
      comment_index = comment_index + 1
      local is_even = comment_index % 2 == 0
      local line_hl = is_even and 'NitThreadCommentAlt' or 'NitThreadComment'
      result[i] = { hl_group = 'NitThreadAuthor', line_hl_group = line_hl }
    end
  end

  return result
end

---Update panel content and chrome for the given thread
---@param thread Nit.Api.Thread
function M.update(thread)
  if not active_panel or not vim.api.nvim_buf_is_valid(active_panel.bufnr) then
    return
  end

  local thread_changed = current_thread == nil or current_thread.id ~= thread.id
  current_thread = thread

  if thread_changed then
    reply_input.clear()
  end

  local lines, author_indices = M.format_thread(thread)

  vim.api.nvim_set_option_value('modifiable', true, { buf = active_panel.bufnr })
  vim.api.nvim_buf_set_lines(active_panel.bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = active_panel.bufnr })

  vim.api.nvim_buf_clear_namespace(active_panel.bufnr, highlight_ns, 0, -1)

  local line_highlights = M.get_line_highlights(lines, author_indices)

  for i = 1, #lines do
    local hl = line_highlights[i]
    if hl then
      local opts = {
        line_hl_group = hl.line_hl_group,
        hl_eol = true,
        priority = 200,
      }
      if hl.hl_group then
        opts.hl_group = hl.hl_group
        opts.end_col = #lines[i]
      end
      vim.api.nvim_buf_set_extmark(active_panel.bufnr, highlight_ns, i - 1, 0, opts)
    end
  end

  if active_panel.winid and vim.api.nvim_win_is_valid(active_panel.winid) then
    vim.wo[active_panel.winid].winbar = M.build_winbar(thread)
  end
end

---Close the panel
function M.close()
  if unsubscribe_comments then
    unsubscribe_comments()
    unsubscribe_comments = nil
  end

  thread_menu.close()
  reply_input.close()

  if active_panel then
    active_panel:unmount()
    active_panel = nil
    current_thread = nil
  end
end

---Check if panel is currently open
---@return boolean
function M.is_open()
  return active_panel ~= nil
    and active_panel.winid ~= nil
    and vim.api.nvim_win_is_valid(active_panel.winid)
end

---Get the currently displayed thread
---@return Nit.Api.Thread?
function M.get_current_thread()
  return current_thread
end

return M

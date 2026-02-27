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
  { key = 'CR', label = 'Submit reply' },
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
local selection_ns = vim.api.nvim_create_namespace('nit_thread_selection')
local closing = false
local augroup = vim.api.nvim_create_augroup('NitThreadPanel', { clear = true })

---@class Nit.Display.CommentRange
---@field comment_index integer
---@field start_line integer
---@field end_line integer

---@type integer?
local selected_comment_idx = nil
---@type Nit.Display.CommentRange[]
local current_ranges = {}

---Apply NitThreadSelected highlight to the selected comment's lines
local function redraw_selection()
  if not active_panel or not vim.api.nvim_buf_is_valid(active_panel.bufnr) then
    return
  end
  pcall(vim.api.nvim_buf_clear_namespace, active_panel.bufnr, selection_ns, 0, -1)
  if selected_comment_idx == nil then
    return
  end
  for _, range in ipairs(current_ranges) do
    if range.comment_index == selected_comment_idx then
      pcall(vim.api.nvim_buf_set_extmark, active_panel.bufnr, selection_ns, range.start_line - 1, 0, {
        line_hl_group = 'NitThreadSelected',
        hl_eol = true,
        priority = 300,
      })
      break
    end
  end
end

---Equalize non-panel windows while preserving panel width
local function equalize_windows()
  local panel_winid = active_panel ~= nil and active_panel.winid or nil
  local reply_winid = reply_input.get_winid()

  local other_wins = vim.tbl_filter(function(w)
    if w == panel_winid or w == reply_winid or not vim.api.nvim_win_is_valid(w) then
      return false
    end
    local ok, config = pcall(vim.api.nvim_win_get_config, w)
    return ok and config.relative == ''
  end, vim.api.nvim_list_wins())

  if #other_wins < 2 then
    return
  end

  local separators = #other_wins - 1 + (panel_winid ~= nil and 1 or 0)
  local panel_width = panel_winid ~= nil and PANEL_WIDTH or 0
  local available = vim.o.columns - panel_width - separators
  local each = math.floor(available / #other_wins)

  for _, w in ipairs(other_wins) do
    pcall(vim.api.nvim_win_set_width, w, each)
  end

  if panel_winid ~= nil and vim.api.nvim_win_is_valid(panel_winid) then
    pcall(vim.api.nvim_win_set_width, panel_winid, PANEL_WIDTH)
  end
end

---@param iso_timestamp string
---@return string
local function format_relative_time(iso_timestamp)
  local year, month, day, hour, min, sec =
    iso_timestamp:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if not year then
    return iso_timestamp
  end

  local y, mo, d, h, mi, s =
    tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(min), tonumber(sec)
  if not (y and mo and d and h and mi and s) then
    return iso_timestamp
  end

  local parsed_as_local = os.time({
    year = y,
    month = mo,
    day = d,
    hour = h,
    min = mi,
    sec = s,
  })

  local now = os.time()
  local utc_table = os.date('!*t', now)
  if type(utc_table) ~= 'table' then
    return iso_timestamp
  end
  local utc_offset = now - os.time(utc_table)
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
---@return string[], table<integer, true>, Nit.Display.CommentRange[]
function M.format_thread(thread)
  local lines = {}
  local author_indices = {}
  local ranges = {}
  local viewer_login = data.get_viewer_login()

  for i, comment in ipairs(thread.comments) do
    if i > 1 then
      table.insert(lines, '')
    end

    local start_line = #lines + 1

    local author_line = ' @'
      .. comment.author.login
      .. ' · '
      .. format_relative_time(comment.createdAt)

    if viewer_login ~= nil and comment.author.login == viewer_login then
      local trimmed = vim.trim(author_line)
      local padding = PANEL_WIDTH - vim.fn.strdisplaywidth(trimmed)
      if padding > 0 then
        author_line = string.rep(' ', padding) .. trimmed
      end
    end

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

    local end_line = #lines
    table.insert(ranges, { comment_index = i, start_line = start_line, end_line = end_line })
  end

  return lines, author_indices, ranges
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

---Format a comment as a block-quoted reply
---@param comment Nit.Api.Comment
---@return string
function M._format_quote(comment)
  local body = comment.body:gsub('\r', '')
  local body_lines = vim.split(body, '\n', { plain = true })
  local quoted_lines = { '> @' .. comment.author.login .. ':' }
  for _, line in ipairs(body_lines) do
    table.insert(quoted_lines, '> ' .. line)
  end
  table.insert(quoted_lines, '')
  return table.concat(quoted_lines, '\n') .. '\n'
end

---Apply a suggestion block from a comment to the target file buffer
---@param comment Nit.Api.Comment
---@param thread Nit.Api.Thread
function M._apply_suggestion(comment, thread)
  local content = comment.body:match('```suggestion\n(.-)%s*\n```')
  if content == nil then
    vim.notify('[nit] No suggestion block found in comment', vim.log.levels.WARN)
    return
  end

  local path = thread.path or ''
  local bufnr = vim.fn.bufnr(path)
  if bufnr == -1 then
    vim.notify('[nit] Open the file first to apply suggestion', vim.log.levels.WARN)
    return
  end

  local start_line = thread.start_line or thread.line
  local end_line = thread.line
  local replacement = vim.split(content, '\n', { plain = true })

  pcall(vim.api.nvim_buf_set_lines, bufnr, start_line - 1, end_line, false, replacement)
  vim.notify('[nit] Suggestion applied', vim.log.levels.INFO)
end

---Populate reply input with a quoted citation of the comment
---@param comment Nit.Api.Comment
local function quote_reply(comment)
  local text = M._format_quote(comment)
  reply_input.set_text(text)
  local winid = reply_input.get_winid()
  if winid ~= nil then
    vim.api.nvim_set_current_win(winid)
    vim.cmd('normal! G$')
  end
end

local submit_reply

---Bind reply_input C-s and CR to submit_reply (the default submit behavior)
local function bind_submit_reply()
  reply_input.map({ 'n', 'i' }, '<C-s>', function()
    vim.cmd('stopinsert')
    submit_reply()
  end, { noremap = true })
  reply_input.map('n', '<CR>', function()
    submit_reply()
  end, { noremap = true })
end

---Submit an edit for a specific comment
---@param comment Nit.Api.Comment
---@param comment_idx integer
local function submit_edit(comment, comment_idx)
  if not current_thread then
    return
  end
  local body = reply_input.get_text()
  if body == '' then
    return
  end
  reply_input.clear()
  bind_submit_reply()
  orchestration.update_comment({
    thread_id = current_thread.id,
    comment_id = comment.node_id or '',
    comment_idx = comment_idx,
    body = body,
  }, function() end)
end

---Open reply_input pre-filled with comment body for editing
---@param comment Nit.Api.Comment
---@param comment_idx integer
local function edit_comment(comment, comment_idx)
  if
    not active_panel
    or not active_panel.winid
    or not vim.api.nvim_win_is_valid(active_panel.winid)
  then
    return
  end
  if not reply_input.is_open() then
    reply_input.open(active_panel.winid)
  end
  reply_input.set_text(comment.body)
  local winid = reply_input.get_winid()
  if winid ~= nil then
    vim.api.nvim_set_current_win(winid)
    vim.cmd('normal! G$')
  end
  reply_input.map({ 'n', 'i' }, '<C-s>', function()
    vim.cmd('stopinsert')
    submit_edit(comment, comment_idx)
  end, { noremap = true })
  reply_input.map('n', '<CR>', function()
    submit_edit(comment, comment_idx)
  end, { noremap = true })
end

---Submit the reply from the input area
submit_reply = function()
  if not current_thread then
    return
  end
  local body = reply_input.get_text()
  if body == '' then
    return
  end
  reply_input.clear()
  orchestration.submit_reply(
    { thread_id = current_thread.id, body = body },
    function(ok, returned_body)
      if not ok and returned_body ~= nil then
        reply_input.set_text(returned_body)
      end
    end
  )
end

---Toggle resolved state of the current thread
local function toggle_resolved()
  if not current_thread then
    return
  end
  orchestration.toggle_resolved({ thread_id = current_thread.id }, function(_ok) end)
end

---Open the action menu
local function open_menu()
  if not current_thread then
    return
  end
  local comment = nil
  if selected_comment_idx ~= nil then
    comment = current_thread.comments[selected_comment_idx]
  end
  thread_menu.open(current_thread, {
    on_toggle_resolved = toggle_resolved,
    comment = comment,
    viewer_login = data.get_viewer_login(),
    on_quote_reply = function(c)
      quote_reply(c)
    end,
    on_edit_comment = function()
      if comment ~= nil and selected_comment_idx ~= nil then
        edit_comment(comment, selected_comment_idx)
      end
    end,
    on_apply_suggestion = function()
      if comment ~= nil then
        M._apply_suggestion(comment, current_thread)
      end
    end,
  })
end

---Re-render panel when comments state changes
local function on_comments_changed()
  if not current_thread then
    return
  end
  local updated = data.get_thread(current_thread.id)
  if updated ~= nil then
    local has_new_comments = #updated.comments > #current_thread.comments
    M.update(updated, has_new_comments)
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
    pcall(vim.api.nvim_clear_autocmds, { group = augroup })
    if unsubscribe_comments ~= nil then
      unsubscribe_comments()
      unsubscribe_comments = nil
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
  M.update(thread, false)

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = panel.bufnr,
    callback = function()
      local ok, cursor = pcall(vim.api.nvim_win_get_cursor, panel.winid)
      if ok then
        M._select_comment(M._find_comment_at_line(cursor[1], current_ranges))
      end
    end,
  })

  if active_panel.winid ~= nil and vim.api.nvim_win_is_valid(active_panel.winid) then
    reply_input.open(active_panel.winid)

    reply_input.map({ 'n', 'i' }, '<C-s>', function()
      vim.cmd('stopinsert')
      submit_reply()
    end, { noremap = true })

    reply_input.map('n', '<CR>', function()
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

    vim.api.nvim_create_autocmd('WinClosed', {
      group = augroup,
      pattern = tostring(active_panel.winid),
      callback = function()
        M.close()
      end,
    })
    local reply_winid = reply_input.get_winid()
    if reply_winid ~= nil then
      vim.api.nvim_create_autocmd('WinClosed', {
        group = augroup,
        pattern = tostring(reply_winid),
        callback = function()
          M.close()
        end,
      })
    end
  end

  equalize_windows()

  if active_panel.winid ~= nil and vim.api.nvim_win_is_valid(active_panel.winid) then
    pcall(vim.fn.win_execute, active_panel.winid, 'noautocmd normal! G')
  end
end

---Compute per-line highlight assignments for author header lines.
---Returns a table mapping 1-based line index to highlight options.
---@param lines string[]
---@param author_indices table<integer, true>
---@return table<integer, {hl_group: string, line_hl_group: string, text_col: integer}>
function M.get_line_highlights(lines, author_indices)
  local result = {}
  local comment_index = 0

  for i = 1, #lines do
    if author_indices[i] then
      comment_index = comment_index + 1
      local is_even = comment_index % 2 == 0
      local line_hl = is_even and 'NitThreadCommentAlt' or 'NitThreadComment'
      local text_col = #lines[i] - #vim.trim(lines[i])
      result[i] = { hl_group = 'NitThreadAuthor', line_hl_group = line_hl, text_col = text_col }
    end
  end

  return result
end

---Update panel content and chrome for the given thread
---@param thread Nit.Api.Thread
---@param scroll_to_bottom? boolean nil=scroll on thread change, true=always scroll, false=never scroll
function M.update(thread, scroll_to_bottom)
  if not active_panel or not vim.api.nvim_buf_is_valid(active_panel.bufnr) then
    return
  end

  local thread_changed = current_thread == nil or current_thread.id ~= thread.id
  current_thread = thread

  if thread_changed then
    reply_input.clear()
    selected_comment_idx = nil
    pcall(vim.api.nvim_buf_clear_namespace, active_panel.bufnr, selection_ns, 0, -1)
  end

  local lines, author_indices, ranges = M.format_thread(thread)
  current_ranges = ranges

  vim.bo[active_panel.bufnr].modifiable = true
  pcall(vim.api.nvim_buf_set_lines, active_panel.bufnr, 0, -1, false, lines)
  vim.bo[active_panel.bufnr].modifiable = false

  pcall(vim.api.nvim_buf_clear_namespace, active_panel.bufnr, highlight_ns, 0, -1)

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
      pcall(
        vim.api.nvim_buf_set_extmark,
        active_panel.bufnr,
        highlight_ns,
        i - 1,
        hl.text_col,
        opts
      )
    end
  end

  if active_panel.winid and vim.api.nvim_win_is_valid(active_panel.winid) then
    vim.wo[active_panel.winid].winbar = M.build_winbar(thread)
    if scroll_to_bottom ~= false and (thread_changed or scroll_to_bottom) then
      pcall(vim.fn.win_execute, active_panel.winid, 'noautocmd normal! G')
    end
  end
end

---Close the panel
function M.close()
  if closing then
    return
  end
  closing = true

  pcall(vim.api.nvim_clear_autocmds, { group = augroup })

  if unsubscribe_comments ~= nil then
    unsubscribe_comments()
    unsubscribe_comments = nil
  end

  thread_menu.close()
  reply_input.close()

  if active_panel then
    active_panel:unmount()
    active_panel = nil
    current_thread = nil
    selected_comment_idx = nil
  end

  pcall(function()
    vim.cmd('wincmd =')
  end)

  closing = false
end

---Check if panel is currently open
---@return boolean
function M.is_open()
  return active_panel ~= nil
    and active_panel.winid ~= nil
    and vim.api.nvim_win_is_valid(active_panel.winid)
end

---Get the panel window ID
---@return integer?
function M.get_winid()
  if not M.is_open() then
    return nil
  end
  return active_panel.winid
end

---Get the currently displayed thread
---@return Nit.Api.Thread?
function M.get_current_thread()
  return current_thread
end

---Find the comment index for a given buffer line number
---@param line integer 1-based line number
---@param ranges Nit.Display.CommentRange[]
---@return integer?
function M._find_comment_at_line(line, ranges)
  for _, range in ipairs(ranges) do
    if line >= range.start_line and line <= range.end_line then
      return range.comment_index
    end
  end
  return nil
end

---Get the currently selected comment index
---@return integer?
function M._get_selected_idx()
  return selected_comment_idx
end

---Select a comment by index, with bounds checking
---@param idx integer?
function M._select_comment(idx)
  if idx == nil then
    selected_comment_idx = nil
    redraw_selection()
    return
  end
  if idx < 1 or idx > #current_ranges then
    return
  end
  selected_comment_idx = idx
  redraw_selection()
end

return M

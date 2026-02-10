---Review panel orchestrator
---@class Nit.Ui.Sidebar
local M = {}

local actions = require('nit.ui.actions')
local layout = require('nit.ui.layout')
local tree = require('nit.ui.tree')
local data = require('nit.state.data')
local observers = require('nit.state.observers')

---@type function[]
local unsubscribers = {}

---@type number?
local sidebar_bufnr = nil

---@class Nit.Ui.Sidebar.Opts
---@field on_refresh? fun() Called when user requests data refresh (R key)
---@field on_close? fun() Called when sidebar closes

---@type Nit.Ui.Sidebar.Opts?
local opts = nil

local cleaning_up = false
local refresh_scheduled = false

local function schedule_refresh()
  if refresh_scheduled then
    return
  end
  refresh_scheduled = true
  vim.schedule(function()
    refresh_scheduled = false
    M.refresh()
  end)
end

---Setup keybindings for sidebar buffer
---@param bufnr number
local function setup_keybindings(bufnr)
  local function handle_enter()
    local node = tree.get_node_at_cursor()
    if not node then
      return
    end

    if node._type == 'separator' then
      return
    end

    if node._type == 'files_header' or node._type == 'directory' then
      if node:is_expanded() then
        node:collapse()
      else
        node:expand()
      end
      local tree_instance = tree.get_tree()
      if tree_instance then
        tree_instance:render()
      end
      return
    end

    if node._type == 'overview' then
      actions.open_pr_buffer()
    elseif node._type == 'file' then
      actions.open_file(node.path)
    elseif node._type == 'comment' then
      local parent_id = node:get_parent_id()
      if not parent_id then
        return
      end

      local tree_instance = tree.get_tree()
      if not tree_instance then
        return
      end

      local parent_node = tree_instance:get_node(parent_id)
      if parent_node and parent_node._type == 'file' then
        actions.go_to_comment(parent_node.path, node.line)
      end
    end
  end

  local function handle_expand()
    local node = tree.get_node_at_cursor()
    if not node then
      return
    end

    if node._type == 'separator' then
      return
    end

    if node:is_expanded() then
      local children = node:get_child_ids()
      if children and #children > 0 then
        local tree_instance = tree.get_tree()
        if tree_instance then
          local _, linenr = tree_instance:get_node(children[1])
          if linenr then
            vim.api.nvim_win_set_cursor(0, { linenr, 0 })
          end
        end
      end
    else
      node:expand()
      local tree_instance = tree.get_tree()
      if tree_instance then
        tree_instance:render()
      end
    end
  end

  local function handle_collapse()
    local node = tree.get_node_at_cursor()
    if not node then
      return
    end

    if node._type == 'separator' then
      return
    end

    if node:is_expanded() then
      node:collapse()
      local tree_instance = tree.get_tree()
      if tree_instance then
        tree_instance:render()
      end
    else
      local parent_id = node:get_parent_id()
      if parent_id then
        local tree_instance = tree.get_tree()
        if tree_instance then
          local _, linenr = tree_instance:get_node(parent_id)
          if linenr then
            vim.api.nvim_win_set_cursor(0, { linenr, 0 })
          end
        end
      end
    end
  end

  local function handle_menu()
    local menu = require('nit.ui.menu')
    local node = tree.get_node_at_cursor()
    if node then
      menu.show(node)
    end
  end

  local function handle_help()
    local help_text = [[
Nit Review Keybindings:

Navigation:
  <CR>, o      - Open file/PR buffer or toggle expand
  l, <Right>   - Expand node or move to first child
  h, <Left>    - Collapse node or move to parent
  j, k         - Move down/up

Actions:
  m            - Open context menu
  R            - Refresh tree data
  q            - Close review panel
  ?            - Show this help
]]
    vim.notify(help_text, vim.log.levels.INFO)
  end

  local keymaps = {
    { '<CR>', handle_enter, 'Open/toggle node' },
    { 'o', handle_enter, 'Open/toggle node' },
    { 'l', handle_expand, 'Expand node' },
    { '<Right>', handle_expand, 'Expand node' },
    { 'h', handle_collapse, 'Collapse node' },
    { '<Left>', handle_collapse, 'Collapse node' },
    { 'q', M.close, 'Close sidebar' },
    { 'm', handle_menu, 'Open context menu' },
    {
      'R',
      function()
        if opts and opts.on_refresh then
          opts.on_refresh()
        else
          M.refresh()
        end
      end,
      'Refresh tree',
    },
    { '?', handle_help, 'Show help' },
  }

  for _, map in ipairs(keymaps) do
    vim.keymap.set('n', map[1], map[2], { buffer = bufnr, silent = true, desc = map[3] })
  end
end

---Write placeholder lines to the sidebar buffer
---@param lines string[]
local function set_placeholder(lines)
  if not sidebar_bufnr or not vim.api.nvim_buf_is_valid(sidebar_bufnr) then
    return
  end
  vim.api.nvim_set_option_value('readonly', false, { buf = sidebar_bufnr })
  vim.api.nvim_set_option_value('modifiable', true, { buf = sidebar_bufnr })
  vim.api.nvim_buf_set_lines(sidebar_bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = sidebar_bufnr })
  vim.api.nvim_set_option_value('readonly', true, { buf = sidebar_bufnr })
end

---Refresh tree data from state
function M.refresh()
  local files = data.get_files()
  local threads = data.get_threads()

  if #files == 0 and #threads == 0 then
    if data.get_loading() then
      set_placeholder({ '', '  Loading PR data...', '' })
    else
      set_placeholder({ '', '  No PR loaded', '', '  PR data will appear once loaded' })
    end
    return
  end

  set_placeholder({ '' })
  tree.update(files, threads)
end

---Clean up sidebar resources (subscriptions, tree)
local function cleanup()
  if cleaning_up then
    return
  end
  cleaning_up = true

  for _, unsub in ipairs(unsubscribers) do
    unsub()
  end
  unsubscribers = {}
  refresh_scheduled = false

  if opts and opts.on_close then
    opts.on_close()
  end
  opts = nil

  tree.destroy()
  sidebar_bufnr = nil
  cleaning_up = false
end

---Open sidebar
---@param open_opts? Nit.Ui.Sidebar.Opts
function M.open(open_opts)
  if layout.is_open() then
    return
  end

  opts = open_opts or {}

  layout.open({
    on_close = function()
      cleanup()
    end,
  })
  sidebar_bufnr = layout.get_sidebar_bufnr()

  if not sidebar_bufnr then
    return
  end

  tree.create(sidebar_bufnr)
  M.refresh()
  setup_keybindings(sidebar_bufnr)

  local refresh_keys = { 'files', 'comments', 'loading' }
  for _, key in ipairs(refresh_keys) do
    table.insert(
      unsubscribers,
      observers.subscribe(key, function()
        schedule_refresh()
      end)
    )
  end
  table.insert(
    unsubscribers,
    observers.subscribe('error', function()
      local error_msg = data.get_error()
      if error_msg then
        vim.notify(error_msg, vim.log.levels.WARN)
      end
    end)
  )
end

---Close sidebar
function M.close()
  if not layout.is_open() then
    return
  end

  cleanup()
  layout.close()
end

---Toggle sidebar
---@param toggle_opts? Nit.Ui.Sidebar.Opts
function M.toggle(toggle_opts)
  if layout.is_open() then
    M.close()
  else
    M.open(toggle_opts)
  end
end

---Check if sidebar is open
---@return boolean
function M.is_open()
  return layout.is_open()
end

return M

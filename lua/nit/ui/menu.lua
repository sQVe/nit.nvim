---Context menu for tree nodes
---@class Nit.Ui.Menu
local M = {}

local Menu = require('nui.menu')
local actions = require('nit.ui.actions')

---Show context menu for node
---@param node any
function M.show(node)
  local items = {}

  if node._type == 'overview' then
    table.insert(
      items,
      Menu.item('Open PR buffer', {
        action = function()
          actions.open_pr_buffer()
        end,
      })
    )
    table.insert(
      items,
      Menu.item('Refresh', {
        action = function()
          require('nit.controller').refresh()
        end,
      })
    )
  elseif node._type == 'file' then
    table.insert(
      items,
      Menu.item('Open file', {
        action = function()
          actions.open_file(node.path)
        end,
      })
    )
    table.insert(
      items,
      Menu.item('Copy path', {
        action = function()
          vim.fn.setreg('+', node.path)
          vim.notify('Copied path: ' .. node.path, vim.log.levels.INFO)
        end,
      })
    )
  elseif node._type == 'comment' then
    table.insert(
      items,
      Menu.item('Go to comment', {
        action = function()
          local tree_mod = require('nit.ui.tree')
          local tree_instance = tree_mod.get_tree()
          if not tree_instance then
            return
          end

          local parent_id = node:get_parent_id()
          if not parent_id then
            return
          end

          local parent_node = tree_instance:get_node(parent_id)
          if not parent_node or parent_node._type ~= 'file' then
            return
          end

          actions.go_to_comment(parent_node.path, node.line)
        end,
      })
    )
  end

  if #items == 0 then
    return
  end

  local menu = Menu({
    position = {
      row = 1,
      col = 0,
    },
    relative = 'cursor',
    border = {
      style = 'rounded',
      text = {
        top = ' Actions ',
      },
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
    },
  }, {
    lines = items,
    on_close = function() end,
    on_submit = function(item)
      if item.action then
        item.action()
      end
    end,
  })

  menu:mount()

  vim.keymap.set('n', 'q', function()
    menu:unmount()
  end, { buffer = menu.bufnr })
  vim.keymap.set('n', '<Esc>', function()
    menu:unmount()
  end, { buffer = menu.bufnr })
end

return M

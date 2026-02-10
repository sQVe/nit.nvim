---Tree lifecycle management
---@class Nit.Ui.Tree
local M = {}

local NuiTree = require('nui.tree')
local layout = require('nit.ui.layout')
local render = require('nit.ui.tree.render')
local nodes = require('nit.ui.tree.nodes')

---@type any
local tree = nil

---Recursively expand all nodes with children
---@param tree_instance any
---@param parent_node any
local function expand_recursive(tree_instance, parent_node)
  if not parent_node:has_children() then
    return
  end
  parent_node:expand()
  for _, child_id in ipairs(parent_node:get_child_ids()) do
    local child = tree_instance:get_node(child_id)
    if child and child:has_children() then
      expand_recursive(tree_instance, child)
    end
  end
end

---Create tree attached to buffer
---@param bufnr number
function M.create(bufnr)
  if tree then
    return
  end

  tree = NuiTree({
    bufnr = bufnr,
    nodes = {},
    prepare_node = function(node)
      return render.prepare_node(node, layout.get_width())
    end,
  })
end

---Update tree with new data
---@param files Nit.Api.File[]
---@param threads Nit.Api.Thread[]
function M.update(files, threads)
  if not tree then
    return
  end

  local current_node = M.get_node_at_cursor()
  local saved_node_id = current_node and current_node:get_id() or nil

  local tree_data = nodes.build_tree_data(files, threads)

  tree:set_nodes(tree_data)

  for _, node in ipairs(tree:get_nodes()) do
    if node:has_children() then
      expand_recursive(tree, node)
    end
  end

  tree:render()

  if saved_node_id then
    local _, linenr = tree:get_node(saved_node_id)
    if linenr then
      vim.api.nvim_win_set_cursor(0, { linenr, 0 })
    end
  end
end

---Get node at cursor position
---@return any?
function M.get_node_at_cursor()
  if not tree then
    return nil
  end

  local ok, node = pcall(tree.get_node, tree)
  if not ok then
    return nil
  end

  return node
end

---Get tree instance
---@return any?
function M.get_tree()
  return tree
end

---Destroy tree instance
function M.destroy()
  if tree then
    tree = nil
  end
end

return M

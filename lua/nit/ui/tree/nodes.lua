---@class Nit.Ui.Tree.OverviewNode
---@field id string Node ID for nui.tree
---@field _type 'overview' Node type
---@field text string Display text

---@class Nit.Ui.Tree.FilesHeaderNode
---@field id string Node ID for nui.tree
---@field _type 'files_header' Node type
---@field count integer Number of files

---@class Nit.Ui.Tree.DirectoryNode
---@field id string Node ID for nui.tree
---@field _type 'directory' Node type
---@field directory string Directory path
---@field indent_state boolean[] Indent state for tree line rendering

---@class Nit.Ui.Tree.FileNode
---@field id string Node ID for nui.tree
---@field _type 'file' Node type
---@field path Nit.Api.FilePath Full file path
---@field display_path string Shortened display path
---@field status Nit.Api.FileStatus File status
---@field additions integer Number of additions
---@field deletions integer Number of deletions
---@field indent_state boolean[] Indent state for tree line rendering

---@class Nit.Ui.Tree.CommentNode
---@field id string Node ID for nui.tree
---@field _type 'comment' Node type
---@field thread_id Nit.Api.ThreadId Thread ID
---@field author string Author login
---@field is_resolved boolean Whether thread is resolved
---@field line? Nit.Api.LineNumber Line number if available
---@field indent_state boolean[] Indent state for tree line rendering

---@class Nit.Ui.Tree.SeparatorNode
---@field id string Node ID for nui.tree
---@field _type 'separator' Node type

---@alias Nit.Ui.Tree.Node Nit.Ui.Tree.OverviewNode|Nit.Ui.Tree.SeparatorNode|Nit.Ui.Tree.FilesHeaderNode|Nit.Ui.Tree.DirectoryNode|Nit.Ui.Tree.FileNode|Nit.Ui.Tree.CommentNode

---@class Nit.Ui.Tree.Nodes
local M = {}

local NuiTree = require('nui.tree')

---Copy indent_state and append a new level
---@param parent_state boolean[]
---@param is_last boolean
---@return boolean[]
local function extend_indent(parent_state, is_last)
  local new_state = {}
  for i, v in ipairs(parent_state) do
    new_state[i] = v
  end
  new_state[#new_state + 1] = is_last
  return new_state
end

---Split a file path into segments
---@param path Nit.Api.FilePath
---@return string[]
local function split_path(path)
  local parts = {}
  for part in path:gmatch('[^/]+') do
    parts[#parts + 1] = part
  end
  return parts
end

---Build a trie from file paths
---@param files Nit.Api.File[]
---@return table
local function build_trie(files)
  local root = { children = {}, files = {} }
  for _, file in ipairs(files) do
    local parts = split_path(file.filename)
    local node = root
    for i = 1, #parts - 1 do
      if not node.children[parts[i]] then
        node.children[parts[i]] = { children = {}, files = {} }
      end
      node = node.children[parts[i]]
    end
    node.files[#node.files + 1] = file
  end
  return root
end

---Create overview node
---@return any
function M.create_overview_node()
  return NuiTree.Node({
    id = 'overview',
    _type = 'overview',
    text = 'Pull request',
  })
end

---Create separator node
---@param id string
---@return any
function M.create_separator_node(id)
  return NuiTree.Node({
    id = id,
    _type = 'separator',
  })
end

---Create files header node
---@param count integer
---@param children? any[]
---@return any
function M.create_files_header_node(count, children)
  return NuiTree.Node({
    id = 'files_header',
    _type = 'files_header',
    count = count,
  }, children)
end

---Create directory node
---@param full_path Nit.Api.FilePath Full directory path for unique ID
---@param display_name string Display name (may be path-compressed)
---@param indent_state boolean[]
---@param children? any[]
---@return any
function M.create_directory_node(full_path, display_name, indent_state, children)
  return NuiTree.Node({
    id = 'dir:' .. full_path,
    _type = 'directory',
    directory = display_name,
    indent_state = indent_state,
  }, children)
end

---Create file node
---@param file Nit.Api.File
---@param display_path string
---@param indent_state boolean[]
---@param children? any[]
---@return any
function M.create_file_node(file, display_path, indent_state, children)
  return NuiTree.Node({
    id = 'file:' .. file.filename,
    _type = 'file',
    path = file.filename,
    display_path = display_path,
    status = file.status,
    additions = file.additions,
    deletions = file.deletions,
    indent_state = indent_state,
  }, children)
end

---Create comment node from thread
---@param thread Nit.Api.Thread
---@param indent_state boolean[]
---@return any
function M.create_comment_node(thread, indent_state)
  local first_comment = thread.comments[1]
  local author = (first_comment and first_comment.author and first_comment.author.login)
    or 'unknown'

  return NuiTree.Node({
    id = 'comment:' .. thread.id,
    _type = 'comment',
    thread_id = thread.id,
    author = author,
    is_resolved = thread.isResolved,
    line = thread.line,
    indent_state = indent_state,
  })
end

---Build comment children for a file node
---@param file_threads Nit.Api.Thread[]?
---@param parent_indent boolean[]
---@return any[]?
local function build_comment_children(file_threads, parent_indent)
  if not file_threads or #file_threads == 0 then
    return nil
  end

  local children = {}
  for i, thread in ipairs(file_threads) do
    local is_last = i == #file_threads
    children[#children + 1] = M.create_comment_node(thread, extend_indent(parent_indent, is_last))
  end
  return children
end

---Convert a trie into NuiTree nodes with path compression
---@param trie_node table
---@param parent_indent boolean[]
---@param threads_by_path table<Nit.Api.FilePath, Nit.Api.Thread[]>
---@param path_prefix Nit.Api.FilePath
---@return any[]
local function trie_to_nodes(trie_node, parent_indent, threads_by_path, path_prefix)
  local dir_names = {}
  for name in pairs(trie_node.children) do
    dir_names[#dir_names + 1] = name
  end
  table.sort(dir_names)

  table.sort(trie_node.files, function(a, b)
    return a.filename < b.filename
  end)

  local total = #dir_names + #trie_node.files
  local index = 0
  local result = {}

  for _, name in ipairs(dir_names) do
    index = index + 1
    local is_last = index == total
    local indent = extend_indent(parent_indent, is_last)

    local display_name = name
    local child = trie_node.children[name]
    local full_path = path_prefix == '' and name or (path_prefix .. '/' .. name)

    while true do
      local child_dirs = {}
      for child_name in pairs(child.children) do
        child_dirs[#child_dirs + 1] = child_name
      end
      if #child_dirs == 1 and #child.files == 0 then
        local only_name = child_dirs[1]
        display_name = display_name .. '/' .. only_name
        full_path = full_path .. '/' .. only_name
        child = child.children[only_name]
      else
        break
      end
    end

    local children = trie_to_nodes(child, indent, threads_by_path, full_path)
    result[#result + 1] = M.create_directory_node(full_path, display_name, indent, children)
  end

  for _, file in ipairs(trie_node.files) do
    index = index + 1
    local is_last = index == total
    local indent = extend_indent(parent_indent, is_last)
    local display_path = vim.fn.fnamemodify(file.filename, ':t')
    local comment_children = build_comment_children(threads_by_path[file.filename], indent)
    result[#result + 1] = M.create_file_node(file, display_path, indent, comment_children)
  end

  return result
end

---Build tree data structure from files and threads
---@param files Nit.Api.File[]
---@param threads Nit.Api.Thread[]
---@return any[]
function M.build_tree_data(files, threads)
  local tree_nodes = {}

  tree_nodes[#tree_nodes + 1] = M.create_overview_node()
  tree_nodes[#tree_nodes + 1] = M.create_separator_node('sep:files')

  ---@type table<Nit.Api.FilePath, Nit.Api.Thread[]>
  local threads_by_path = {}
  for _, thread in ipairs(threads) do
    if thread.path then
      if not threads_by_path[thread.path] then
        threads_by_path[thread.path] = {}
      end
      threads_by_path[thread.path][#threads_by_path[thread.path] + 1] = thread
    end
  end

  local file_children = trie_to_nodes(build_trie(files), {}, threads_by_path, '')

  tree_nodes[#tree_nodes + 1] = M.create_files_header_node(#files, file_children)

  return tree_nodes
end

return M

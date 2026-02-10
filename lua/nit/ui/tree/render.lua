---Tree node rendering with prepare_node callback
---@class Nit.Ui.Tree.Render
local M = {}

local NuiLine = require('nui.line')
local icons = require('nit.ui.icons')
local indent = require('nit.ui.tree.indent')

local BASE_INDENT = '  '

---Format file stats, omitting zero values
---@param additions integer
---@param deletions integer
---@return string
local function format_stats(additions, deletions)
  if additions > 0 and deletions > 0 then
    return string.format('+%d -%d', additions, deletions)
  elseif additions > 0 then
    return string.format('+%d', additions)
  elseif deletions > 0 then
    return string.format('-%d', deletions)
  end
  return ''
end

---Prepare a node for rendering in nui.Tree
---@param node any nui.tree node
---@param width integer sidebar width
---@return any NuiLine
function M.prepare_node(node, width)
  local line = NuiLine()

  if node._type == 'overview' then
    line:append(icons.overview .. ' ', 'NitIcon')
    line:append('Pull request', 'NitOverview')
    return line
  end

  if node._type == 'separator' then
    return line
  end

  if node._type == 'files_header' then
    line:append(icons.files .. ' ', 'NitIcon')
    line:append(string.format('Files (%d)', node.count), 'NitSectionHeader')
    return line
  end

  if node._type == 'directory' then
    local indent_str = indent.build(node.indent_state)
    local folder_icon = node:is_expanded() and icons.folder_open or icons.folder_closed
    line:append(BASE_INDENT)
    if #indent_str > 0 then
      line:append(indent_str, 'NitIndentMarker')
    end
    local dir_hl = node:is_expanded() and 'NitDirectoryHeader' or 'NitDirectoryCollapsed'
    line:append(folder_icon .. ' ', dir_hl)
    line:append(node.directory, dir_hl)
    return line
  end

  if node._type == 'file' then
    local indent_str = indent.build(node.indent_state)
    line:append(BASE_INDENT)
    if #indent_str > 0 then
      line:append(indent_str, 'NitIndentMarker')
    end

    local file_icon, icon_hl = icons.get_icon(node.path)
    local icon_part = file_icon .. ' '
    line:append(icon_part, icon_hl)

    local status_highlights = {
      added = 'NitFileAdded',
      modified = 'NitFileModified',
      removed = 'NitFileRemoved',
      renamed = 'NitFileRenamed',
    }
    local status_hl = status_highlights[node.status] or 'NitFileModified'
    line:append(node.display_path, status_hl)

    local stats = format_stats(node.additions, node.deletions)
    if stats ~= '' then
      local used_width = vim.fn.strdisplaywidth(BASE_INDENT)
        + vim.fn.strdisplaywidth(indent_str)
        + vim.fn.strdisplaywidth(icon_part)
      local filename_width = vim.fn.strdisplaywidth(node.display_path)
      local stats_width = vim.fn.strdisplaywidth(stats)
      local padding = width - 1 - used_width - filename_width - stats_width
      if padding < 1 then
        padding = 1
      end
      line:append(string.rep(' ', padding))
      line:append(stats, 'NitFileStats')
    end

    return line
  end

  if node._type == 'comment' then
    local indent_str = indent.build(node.indent_state)
    line:append(BASE_INDENT)
    if #indent_str > 0 then
      line:append(indent_str, 'NitIndentMarker')
    end

    if node.is_resolved then
      line:append(icons.resolved .. ' ', 'NitIcon')
      line:append(node.author, 'NitCommentResolved')
    else
      line:append(icons.comment .. ' ', 'NitIcon')
      line:append(node.author, 'NitCommentAuthor')
    end

    return line
  end

  return line
end

return M

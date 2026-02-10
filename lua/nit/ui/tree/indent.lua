---Tree indent marker rendering
---@class Nit.Ui.Tree.Indent
local M = {}

local MARKERS = {
  edge = '│',
  branch = '├',
  last = '└',
  space = ' ',
}

---Build indent string from indent_state
---@param indent_state boolean[] Array where each entry indicates if the node at that level is the last child
---@return string
function M.build(indent_state)
  if not indent_state or #indent_state == 0 then
    return ''
  end

  local parts = {}

  for i = 1, #indent_state - 1 do
    if indent_state[i] then
      parts[#parts + 1] = MARKERS.space .. ' '
    else
      parts[#parts + 1] = MARKERS.edge .. ' '
    end
  end

  if indent_state[#indent_state] then
    parts[#parts + 1] = MARKERS.last .. ' '
  else
    parts[#parts + 1] = MARKERS.branch .. ' '
  end

  return table.concat(parts)
end

return M

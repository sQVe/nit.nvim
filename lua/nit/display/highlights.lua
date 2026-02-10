---@class Nit.Display.Highlights
local M = {}

local ns_id = vim.api.nvim_create_namespace('nit_comment_highlight')

---Get the namespace ID for highlights
---@return integer Namespace ID
function M.get_namespace()
  return ns_id
end

---Set extmark-based highlight for a review thread
---@param bufnr integer Buffer number
---@param thread Nit.Api.Thread Review thread to highlight
function M.set(bufnr, thread)
  if thread.side ~= 'RIGHT' or thread.line == nil then
    return
  end

  local start_row = (thread.start_line or thread.line) - 1
  local end_row = thread.line

  vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_row, 0, {
    end_row = end_row,
    end_col = 0,
    hl_group = 'NitCommentHighlight',
    priority = 100,
  })
end

---Clear all highlights from buffer
---@param bufnr integer Buffer number
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

return M

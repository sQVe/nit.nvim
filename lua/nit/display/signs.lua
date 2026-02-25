---@class Nit.Display.Signs
local M = {}

local sign_ns = vim.api.nvim_create_namespace('nit_comments')

---Place signs for review threads in buffer
---@param bufnr integer Buffer number
---@param threads Nit.Api.Thread[] Review threads to place signs for
function M.place(bufnr, threads)
  for _, thread in ipairs(threads) do
    if thread.side == 'RIGHT' and thread.line ~= nil then
      local sign_text = '󰆂'
      local sign_hl = 'NitCommentSign'
      if thread.isOutdated then
        sign_text = '󱗢'
        sign_hl = 'NitCommentOutdatedSign'
      elseif thread.isResolved then
        sign_text = '󰆀'
        sign_hl = 'NitCommentResolvedSign'
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, sign_ns, thread.line - 1, 0, {
        sign_text = sign_text,
        sign_hl_group = sign_hl,
        priority = 10,
      })
    end
  end
end

---Clear all comment signs from buffer
---@param bufnr integer Buffer number
function M.clear(bufnr)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, sign_ns, 0, -1)
end

return M

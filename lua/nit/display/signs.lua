---@class Nit.Display.Signs
local M = {}

local SIGN_GROUP = 'nit_comments'

---Define signs for comment indicators
function M.setup()
  vim.fn.sign_define('NitComment', {
    text = '💬',
    texthl = 'NitCommentSign',
  })
  vim.fn.sign_define('NitCommentResolved', {
    text = '✓',
    texthl = 'NitCommentResolvedSign',
  })
end

---Place signs for review threads in buffer
---@param bufnr integer Buffer number
---@param threads Nit.Api.Thread[] Review threads to place signs for
function M.place(bufnr, threads)
  for _, thread in ipairs(threads) do
    if thread.side == 'RIGHT' and thread.line ~= nil then
      local sign_name = thread.isResolved and 'NitCommentResolved' or 'NitComment'
      vim.fn.sign_place(0, SIGN_GROUP, sign_name, bufnr, {
        lnum = thread.line,
        priority = 10,
      })
    end
  end
end

---Clear all comment signs from buffer
---@param bufnr integer Buffer number
function M.clear(bufnr)
  vim.fn.sign_unplace(SIGN_GROUP, { buffer = bufnr })
end

return M

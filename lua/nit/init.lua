---@class Nit
local M = {}

---@class Nit.Config
---@field debug? boolean Enable debug logging

---@type Nit.Config
M.config = {}

---@param opts? Nit.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

---Start the review session
function M.start()
  require('nit.review').start()
end

---Stop the review session
function M.stop()
  require('nit.review').stop()
end

---Open the context-aware action menu
function M.menu()
  require('nit.display.thread_panel').open_menu()
end

---Jump to next comment in current buffer
function M.next_comment()
  require('nit.navigation').next_comment()
end

---Jump to previous comment in current buffer
function M.prev_comment()
  require('nit.navigation').prev_comment()
end

return M

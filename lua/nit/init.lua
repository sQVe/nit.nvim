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

---@type Nit.Review
M.review = setmetatable({}, {
  __index = function(_, key)
    return require('nit.review')[key]
  end,
})

return M

---@class Nit.State.ObserverModule
local M = {}

---@type table<string, function[]>
local callbacks = {}

---@type table<string, boolean>
local pending = {}

---@type boolean
local scheduled = false

---Subscribe to state key changes
---@param key string The state key to observe
---@param callback fun(key: string) Callback invoked on notify
---@return fun() unsubscribe Unsubscribe function
function M.subscribe(key, callback)
  if not callbacks[key] then
    callbacks[key] = {}
  end
  table.insert(callbacks[key], callback)

  return function()
    local list = callbacks[key]
    if not list then
      return
    end
    for i, cb in ipairs(list) do
      if cb == callback then
        table.remove(list, i)
        break
      end
    end
  end
end

---Notify observers of a state key change
---Batches rapid notifications via vim.schedule
---@param key string The state key that changed
function M.notify(key)
  pending[key] = true
  if scheduled then
    return
  end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    local keys = vim.tbl_keys(pending)
    pending = {}
    for _, k in ipairs(keys) do
      for _, callback in ipairs(callbacks[k] or {}) do
        local ok, err = pcall(callback, k)
        if not ok then
          vim.notify('[nit] observer error: ' .. tostring(err), vim.log.levels.ERROR)
        end
      end
    end
  end)
end

---Clear all observers (for testing)
function M.clear()
  callbacks = {}
  pending = {}
  scheduled = false
end

return M

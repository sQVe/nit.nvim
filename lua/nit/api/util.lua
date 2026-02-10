---@class Nit.Api.Util
local M = {}

local tracker = require('nit.api.tracker')

---Normalize vim.NIL to nil
---@param value any
---@return any
function M.nil_if_vim_nil(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---Get owner and repo from git remote asynchronously
---@param callback fun(owner: string|nil, repo: string|nil)
---@return fun() cancel Cancel function
function M.get_repo_info(callback)
  local completed = false
  local request_id = nil

  local process = vim.system(
    { 'git', 'remote', 'get-url', 'origin' },
    { text = true },
    vim.schedule_wrap(function(result)
      if completed then
        return
      end
      completed = true
      if request_id then
        tracker.untrack(request_id)
      end

      if result.code ~= 0 then
        callback(nil, nil)
        return
      end

      local stdout = result.stdout or ''
      local owner, repo = stdout:match('github%.com[:/]([^/]+)/([^%s]+)')
      if owner and repo then
        callback(owner, repo:gsub('%.git$', ''):gsub('/$', ''))
      else
        callback(nil, nil)
      end
    end)
  )

  local cancel = function()
    if completed then
      return
    end
    completed = true
    if request_id then
      tracker.untrack(request_id)
    end
    if process then
      process:kill(9)
    end
  end

  request_id = tracker.track(cancel)

  return cancel
end

return M

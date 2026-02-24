---@class Nit.Api.Viewer
local M = {}

local gh = require('nit.api.gh')

---Fetch the authenticated GitHub user's login
---@param opts Nit.Api.RequestOpts Options
---@param callback fun(result: Nit.Api.Result) Callback function
---@return fun() cancel Cancel function
function M.fetch_viewer(opts, callback)
  opts = opts or {}

  local request_opts = {
    timeout = opts.timeout,
    retry = opts.retry,
  }

  return gh.execute({ 'api', 'user', '--jq', '.login' }, request_opts, function(result)
    if not result.ok then
      callback(result)
      return
    end

    local login = vim.trim(result.data)
    if login == '' then
      callback({ ok = false, error = 'Empty viewer login response' })
      return
    end

    callback({ ok = true, data = login })
  end)
end

return M

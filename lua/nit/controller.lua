---@class Nit.Controller
local M = {}

local pr_api = require('nit.api.pr')
local files_api = require('nit.api.files')
local comments_api = require('nit.api.comments')
local parallel_api = require('nit.api.parallel')
local tracker = require('nit.api.tracker')
local data = require('nit.state.data')

---@type fun()?
local cancel_load = nil

---@type table?
local active_load_id = nil

---Load PR data from API and populate state
---Fetches PR first to get the number, then files+comments in parallel.
---@param opts table? Options to pass to API functions
function M.load(opts)
  if cancel_load then
    cancel_load()
    cancel_load = nil
  end

  data.set_error(nil)
  data.set_loading(true)

  local load_id = {}
  active_load_id = load_id
  opts = opts or {}

  local cancel_pr = nil
  local cancel_rest = nil

  cancel_load = function()
    if cancel_pr then
      cancel_pr()
    end
    if cancel_rest then
      cancel_rest()
    end
  end

  cancel_pr = pr_api.fetch_pr(opts, function(pr_result)
    if active_load_id ~= load_id then
      return
    end

    if not pr_result.ok then
      cancel_load = nil
      active_load_id = nil
      data.set_loading(false)
      data.set_error(pr_result.error)
      return
    end

    ---@type Nit.Api.PR
    local pr = pr_result.data
    data.set_pr(pr)
    data.set_comments(pr.comments)

    local rest_opts = vim.tbl_extend('force', opts, { number = pr.number })
    cancel_rest = parallel_api.parallel({
      { fn = files_api.fetch_files, args = rest_opts },
      { fn = comments_api.fetch_comments, args = rest_opts },
    }, function(results)
      if active_load_id ~= load_id then
        return
      end

      cancel_load = nil
      active_load_id = nil
      data.set_loading(false)

      if results[1].ok then
        data.set_files(results[1].data)
      end
      if results[2].ok then
        data.set_threads(results[2].data)
      end

      local errors = {}
      for _, result in ipairs(results) do
        if not result.ok then
          table.insert(errors, result.error)
        end
      end
      if #errors > 0 then
        data.set_error(table.concat(errors, '; '))
      end
    end)
  end)
end

---Clean up controller state and cancel in-flight requests
function M.cleanup()
  if cancel_load then
    cancel_load()
    cancel_load = nil
  end
  active_load_id = nil
  tracker.cancel_all()
  data.clear()
end

---Refresh PR data (cleanup then load)
---@param opts table? Options to pass to API functions
function M.refresh(opts)
  M.cleanup()
  M.load(opts)
end

return M

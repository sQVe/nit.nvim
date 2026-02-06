local M = {}

---@class Nit.Api.ParallelOperation
---@field fn fun(opts: table, callback: fun(result: Nit.Api.Result)): fun() Function to execute
---@field args table Arguments to pass to the function

---Execute multiple API operations in parallel and collect results
---@param operations Nit.Api.ParallelOperation[] Operations to execute
---@param callback fun(results: Nit.Api.Result[]) Called when all operations complete
---@return fun() cancel Cancel function that cancels all operations
function M.parallel(operations, callback)
  if #operations == 0 then
    vim.schedule(function()
      callback({})
    end)
    return function() end
  end

  local results = {}
  local pending = #operations
  local cancel_fns = {}

  for i, op in ipairs(operations) do
    local ok, cancel_fn_or_err = pcall(op.fn, op.args, function(result)
      results[i] = result
      pending = pending - 1

      if pending == 0 then
        callback(results)
      end
    end)

    if ok then
      cancel_fns[i] = cancel_fn_or_err
    else
      cancel_fns[i] = function() end
      results[i] = { ok = false, error = tostring(cancel_fn_or_err) }
      pending = pending - 1
    end
  end

  if pending == 0 then
    vim.schedule(function()
      callback(results)
    end)
  end

  return function()
    for _, cancel_fn in ipairs(cancel_fns) do
      cancel_fn()
    end
  end
end

return M

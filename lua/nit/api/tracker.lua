local M = {}

local requests = {}
local next_id = 1

---Track a new request with its cancel function
---@param cancel_fn fun() Function to call to cancel the request
---@return integer id Unique request ID
function M.track(cancel_fn)
  local id = next_id
  next_id = next_id + 1
  requests[id] = cancel_fn
  return id
end

---Untrack a completed or cancelled request
---@param id integer Request ID to remove
function M.untrack(id)
  requests[id] = nil
end

---Cancel all in-flight requests
function M.cancel_all()
  for _, cancel_fn in pairs(requests) do
    cancel_fn()
  end
  requests = {}
end

---Get the number of in-flight requests
---@return integer count Number of tracked requests
function M.get_count()
  local count = 0
  for _ in pairs(requests) do
    count = count + 1
  end
  return count
end

return M

---@class Nit.Orchestration.Snapshot
---@field thread_id integer
---@field thread Nit.Api.Thread?

---@class Nit.Orchestration.SnapshotModule
local M = {}

local data = require('nit.state.data')

---Capture a thread-level state snapshot
---@param thread_id integer?
---@return Nit.Orchestration.Snapshot?
function M.capture(thread_id)
  if thread_id == nil then
    return nil
  end

  local thread = data.get_thread(thread_id)
  local thread_copy = thread and vim.deepcopy(thread) or nil

  return {
    thread_id = thread_id,
    thread = thread_copy,
  }
end

---Restore a captured thread state snapshot
---@param snap Nit.Orchestration.Snapshot
function M.restore(snap)
  local all_threads = data.get_threads()
  local updated_threads = {}

  for _, thread in ipairs(all_threads) do
    if thread.id ~= snap.thread_id then
      table.insert(updated_threads, thread)
    end
  end

  if snap.thread ~= nil then
    table.insert(updated_threads, snap.thread)
  end

  data.set_threads(updated_threads)
end

return M

---@class Nit.Orchestration.Snapshot
---@field thread_id Nit.Api.ThreadId
---@field thread Nit.Api.Thread?

---@class Nit.Orchestration.SnapshotModule
local M = {}

local data = require('nit.state.data')

---@param thread_id Nit.Api.ThreadId?
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

---@param snap Nit.Orchestration.Snapshot
function M.restore(snap)
  if snap.thread ~= nil then
    data.upsert_thread(snap.thread)
  else
    data.remove_thread(snap.thread_id)
  end
end

return M

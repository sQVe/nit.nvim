---@class Nit.Orchestration.Versioning
local M = {}

---@type table<integer|string, integer>
local versions = {}

---Increment and return the new version number for a thread
---@param thread_id integer|string
---@return integer
function M.increment(thread_id)
  local current = versions[thread_id] or 0
  local new_version = current + 1
  versions[thread_id] = new_version
  return new_version
end

---Get current version for a thread
---@param thread_id integer|string
---@return integer
function M.get(thread_id)
  return versions[thread_id] or 0
end

---Check if version is current for a thread
---@param thread_id integer|string
---@param version integer
---@return boolean
function M.is_current(thread_id, version)
  return versions[thread_id] == version
end

---Clear all version counters
function M.reset()
  versions = {}
end

return M

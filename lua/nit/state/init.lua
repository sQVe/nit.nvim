---@class Nit.State.Module
local M = {}

local observers = require('nit.state.observers')
local data = require('nit.state.data')
local pending = require('nit.state.pending')

M.subscribe = observers.subscribe

M.get_pr = data.get_pr
M.set_pr = data.set_pr
M.get_file = data.get_file
M.get_files = data.get_files
M.set_files = data.set_files
M.get_thread = data.get_thread
M.get_threads = data.get_threads
M.set_threads = data.set_threads
M.get_threads_for_file = data.get_threads_for_file

M.get_pending = pending.get_pending
M.add_pending = pending.add_pending
M.update_pending = pending.update_pending
M.remove_pending = pending.remove_pending

---Reset state (clears PR data, preserves pending)
function M.reset()
  data.clear()
end

---Trigger lazy loading of pending comments from disk
---Call during startup to ensure persistence is loaded before UI renders
function M.load_pending()
  pending.get_pending()
end

return M

---@class Nit.State.DataModule
local M = {}

local observers = require('nit.state.observers')

---@type Nit.Api.PR?
local pr = nil

---@type table<string, Nit.Api.File>
local files_by_path = {}

---@type table<integer, Nit.Api.Thread>
local threads_by_id = {}

---@type table<string, integer[]>
local threads_by_file = {}

---Set PR data
---@param data Nit.Api.PR?
function M.set_pr(data)
  pr = data
  observers.notify('pr')
end

---Get PR data
---@return Nit.Api.PR?
function M.get_pr()
  return pr
end

---Set files data (indexed by path)
---@param files Nit.Api.File[]
function M.set_files(files)
  files_by_path = {}
  for _, file in ipairs(files) do
    files_by_path[file.filename] = file
  end
  observers.notify('files')
end

---Get file by path
---@param path string
---@return Nit.Api.File?
function M.get_file(path)
  return files_by_path[path]
end

---Get all files (sorted by filename)
---@return Nit.Api.File[]
function M.get_files()
  local files = vim.tbl_values(files_by_path)
  table.sort(files, function(a, b)
    return a.filename < b.filename
  end)
  return files
end

---Rebuild threads_by_file index
local function rebuild_threads_by_file_index()
  threads_by_file = {}
  for id, thread in pairs(threads_by_id) do
    if thread.path then
      if not threads_by_file[thread.path] then
        threads_by_file[thread.path] = {}
      end
      table.insert(threads_by_file[thread.path], id)
    end
  end
end

---Set threads data (indexed by ID)
---@param threads Nit.Api.Thread[]
function M.set_threads(threads)
  threads_by_id = {}
  for _, thread in ipairs(threads) do
    threads_by_id[thread.id] = thread
  end
  rebuild_threads_by_file_index()
  observers.notify('comments')
end

---Get thread by ID
---@param id integer
---@return Nit.Api.Thread?
function M.get_thread(id)
  return threads_by_id[id]
end

---Get all threads (sorted by ID)
---@return Nit.Api.Thread[]
function M.get_threads()
  local threads = vim.tbl_values(threads_by_id)
  table.sort(threads, function(a, b)
    return a.id < b.id
  end)
  return threads
end

---Get threads for a specific file path
---@param path string
---@return Nit.Api.Thread[]
function M.get_threads_for_file(path)
  local ids = threads_by_file[path]
  if not ids then
    return {}
  end
  local result = {}
  for _, id in ipairs(ids) do
    local thread = threads_by_id[id]
    if thread then
      table.insert(result, thread)
    end
  end
  return result
end

---Clear all state data
function M.clear()
  pr = nil
  files_by_path = {}
  threads_by_id = {}
  threads_by_file = {}
  observers.notify('pr')
  observers.notify('files')
  observers.notify('comments')
end

return M

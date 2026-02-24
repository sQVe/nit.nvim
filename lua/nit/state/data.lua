---@class Nit.State.Data
local M = {}

local observers = require('nit.state.observers')

---@type Nit.Api.PR?
local pr = nil

---@type table<Nit.Api.FilePath, Nit.Api.File>
local files_by_path = {}

---@type table<Nit.Api.ThreadId, Nit.Api.Thread>
local threads_by_id = {}

---@type table<Nit.Api.FilePath, Nit.Api.ThreadId[]>
local threads_by_file = {}

---@type Nit.Api.IssueComment[]
local comments = {}

---@type boolean
local loading = false

---@type string?
local error_msg = nil

---@type string?
local viewer_login = nil

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
---@param path Nit.Api.FilePath
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
---@param id Nit.Api.ThreadId
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
---@param path Nit.Api.FilePath
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

---Insert or replace a thread by ID
---@param thread Nit.Api.Thread
function M.upsert_thread(thread)
  threads_by_id[thread.id] = thread
  rebuild_threads_by_file_index()
  observers.notify('comments')
end

---Remove a thread by ID
---@param id Nit.Api.ThreadId
function M.remove_thread(id)
  threads_by_id[id] = nil
  rebuild_threads_by_file_index()
  observers.notify('comments')
end

---Set PR-level comments
---@param data Nit.Api.IssueComment[]
function M.set_comments(data)
  comments = data
  observers.notify('pr_comments')
end

---Get PR-level comments
---@return Nit.Api.IssueComment[]
function M.get_comments()
  return comments
end

---Set viewer GitHub login
---@param login string?
function M.set_viewer_login(login)
  viewer_login = login
end

---Get viewer GitHub login
---@return string?
function M.get_viewer_login()
  return viewer_login
end

---Set loading state
---@param value boolean
function M.set_loading(value)
  loading = value
  observers.notify('loading')
end

---Get loading state
---@return boolean
function M.get_loading()
  return loading
end

---Set error state
---@param value string?
function M.set_error(value)
  error_msg = value
  observers.notify('error')
end

---Get error state
---@return string?
function M.get_error()
  return error_msg
end

---Clear all state data
function M.clear()
  comments = {}
  error_msg = nil
  viewer_login = nil
  files_by_path = {}
  loading = false
  observers.notify('comments')
  observers.notify('error')
  observers.notify('files')
  observers.notify('loading')
  observers.notify('pr')
  observers.notify('pr_comments')
  pr = nil
  threads_by_file = {}
  threads_by_id = {}
end

return M

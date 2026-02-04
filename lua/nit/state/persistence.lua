local M = {}

local CURRENT_VERSION = 1

---Compute a simple hash of a string
---@param str string
---@return string
local function hash_string(str)
  local sum = 0
  for i = 1, #str do
    sum = (sum * 31 + str:byte(i)) % 0x100000000
  end
  return string.format('%08x', sum)
end

---Get the git remote URL hash for the current repository
---@return string
local function get_repo_hash()
  local result = vim.fn.system('git remote get-url origin 2>/dev/null')
  if vim.v.shell_error ~= 0 then
    return 'unknown'
  end
  local trimmed = result:gsub('%s+$', '')
  return hash_string(trimmed)
end

---Get the persistence directory path
---@return string
local function get_persistence_dir()
  return vim.fn.stdpath('data') .. '/nit'
end

---Get the full path to the persistence file for the current repo
---@return string
function M.get_persistence_path()
  return get_persistence_dir() .. '/' .. get_repo_hash() .. '.json'
end

---Save pending comments to disk
---@param pending Nit.State.PendingComment[]
function M.save_pending(pending)
  local dir = get_persistence_dir()
  vim.fn.mkdir(dir, 'p')

  local data = {
    version = CURRENT_VERSION,
    pending = pending,
  }

  local json = vim.json.encode(data)
  vim.fn.writefile({ json }, M.get_persistence_path())
end

---Load pending comments from disk
---@return Nit.State.PendingComment[]
function M.load_pending()
  local path = M.get_persistence_path()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local lines = vim.fn.readfile(path)
  local content = table.concat(lines, '\n')

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= 'table' then
    return {}
  end

  if decoded.version ~= CURRENT_VERSION then
    return {}
  end

  return decoded.pending or {}
end

return M

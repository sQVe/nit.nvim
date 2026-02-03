local gh = require('nit.api.gh')

local M = {}

---Normalize file status from gh CLI to Nit.Api.File status
---@param status string
---@return 'added'|'modified'|'removed'|'renamed'
local function normalize_status(status)
  local lower = status:lower()
  if lower == 'added' or lower == 'a' then
    return 'added'
  elseif lower == 'removed' or lower == 'd' then
    return 'removed'
  elseif lower == 'renamed' or lower == 'r' then
    return 'renamed'
  else
    return 'modified'
  end
end

---Parse files JSON from gh CLI
---@param json_str string
---@return Nit.Api.File[]?
local function parse_files(json_str)
  local ok, parsed = pcall(vim.json.decode, json_str)
  if not ok or not parsed or not parsed.files then
    return nil
  end

  local files = {}
  for _, file in ipairs(parsed.files) do
    table.insert(files, {
      filename = file.path,
      status = normalize_status(file.status),
      additions = file.additions or 0,
      deletions = file.deletions or 0,
    })
  end

  return files
end

---Fetch list of files changed in a PR
---@param opts? { number?: integer, timeout?: integer }
---@param callback fun(result: Nit.Api.Result<Nit.Api.File[]>)
---@return fun() cancel Cancel function
function M.fetch_files(opts, callback)
  opts = opts or {}

  local args = { 'pr', 'view' }
  if opts.number then
    table.insert(args, tostring(opts.number))
  end
  vim.list_extend(args, { '--json', 'files' })

  return gh.execute(args, { timeout = opts.timeout }, function(result)
    if not result.ok then
      callback({ ok = false, error = result.error })
      return
    end

    local files = parse_files(result.data)
    if not files then
      callback({ ok = false, error = 'Failed to parse files JSON' })
      return
    end

    callback({ ok = true, data = files })
  end)
end

---Fetch diff for a PR or specific file
---@param opts? { number?: integer, path?: string, timeout?: integer }
---@param callback fun(result: Nit.Api.Result<string>)
---@return fun() cancel Cancel function
function M.fetch_diff(opts, callback)
  opts = opts or {}

  local args = { 'pr', 'diff' }
  if opts.number then
    table.insert(args, tostring(opts.number))
  end

  if opts.path then
    vim.list_extend(args, { '--', opts.path })
  end

  return gh.execute(args, { timeout = opts.timeout }, function(result)
    if not result.ok then
      callback({ ok = false, error = result.error })
      return
    end

    callback({ ok = true, data = result.data })
  end)
end

return M

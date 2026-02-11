---Navigation between comment lines in buffers
---@class Nit.Navigation
local M = {}

local review = require('nit.review')
local manager = require('nit.display.manager')

---Get sorted list of commented lines for a buffer
---@param bufnr integer Buffer number
---@return integer[]?
local function get_sorted_comment_lines(bufnr)
  local commented_lines = manager.get_commented_lines(bufnr)
  if not commented_lines then
    return nil
  end

  local lines = {}
  for line, _ in pairs(commented_lines) do
    table.insert(lines, line)
  end

  table.sort(lines)
  return lines
end

---Jump to next comment line
function M.next_comment()
  if not review.is_active() then
    vim.notify('[nit] no active review', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if not ok then
    return
  end

  local current_line = cursor[1]
  local lines = get_sorted_comment_lines(bufnr)
  if not lines or #lines == 0 then
    return
  end

  for _, line in ipairs(lines) do
    if line > current_line then
      local set_ok = pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
      if set_ok then
        vim.cmd('normal! ^')
      end
      return
    end
  end
end

---Jump to previous comment line
function M.prev_comment()
  if not review.is_active() then
    vim.notify('[nit] no active review', vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
  if not ok then
    return
  end

  local current_line = cursor[1]
  local lines = get_sorted_comment_lines(bufnr)
  if not lines or #lines == 0 then
    return
  end

  local prev_line = nil
  for _, line in ipairs(lines) do
    if line < current_line then
      prev_line = line
    else
      break
    end
  end

  if prev_line then
    local set_ok = pcall(vim.api.nvim_win_set_cursor, 0, { prev_line, 0 })
    if set_ok then
      vim.cmd('normal! ^')
    end
  end
end

return M

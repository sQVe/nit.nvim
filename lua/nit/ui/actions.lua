---@class Nit.Ui.Actions
local M = {}

local layout = require('nit.ui.layout')

---Open a file in the main editing window, optionally at a line.
---@param filepath string
---@param line? integer
function M.open_file(filepath, line)
  layout.open_in_main_window(function(winid)
    vim.api.nvim_set_current_win(winid)
    if line then
      vim.cmd('edit +' .. line .. ' ' .. vim.fn.fnameescape(filepath))
    else
      vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
    end
  end)
end

---Open the PR buffer in the main editing window.
function M.open_pr_buffer()
  local buffer = require('nit.buffer')
  local pr_bufnr = vim.api.nvim_create_buf(false, true)
  buffer.render(pr_bufnr)

  layout.open_in_main_window(function(winid)
    vim.api.nvim_win_set_buf(winid, pr_bufnr)
  end)
end

---Navigate to a comment's file location. Keeps focus on sidebar.
---@param filepath string
---@param line? integer
function M.go_to_comment(filepath, line)
  layout.open_in_main_window(function(winid)
    vim.api.nvim_set_current_win(winid)
    if line then
      vim.cmd('edit +' .. line .. ' ' .. vim.fn.fnameescape(filepath))
    else
      vim.cmd('edit ' .. vim.fn.fnameescape(filepath))
    end
  end, { stay = true })
end

return M

---@class Nit.Review
local M = {}

local controller = require('nit.controller')
local display_manager = require('nit.display.manager')
local observers = require('nit.state.observers')

local active = false
local git_root = nil
local git_root_failed = false
local review_augroup = nil
local observer_unsubscribe = nil

---Try to attach buffer if it matches a PR file
---@param bufnr integer Buffer number
local function try_attach_buffer(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' or vim.bo[bufnr].buftype ~= '' then
    return
  end

  if not git_root then
    if git_root_failed then
      return
    end
    local result = vim.fn.systemlist('git rev-parse --show-toplevel')
    if vim.v.shell_error == 0 and result[1] then
      git_root = result[1]
    else
      git_root_failed = true
      return
    end
  end

  local prefix = git_root .. '/'
  if bufname:sub(1, #prefix) ~= prefix then
    return
  end

  local relative_path = bufname:sub(#prefix + 1)
  display_manager.attach(bufnr, relative_path)
end

---Check if review session is active
---@return boolean
function M.is_active()
  return active
end

---Start review session
function M.start()
  if active then
    return
  end

  active = true
  display_manager.setup()

  -- BufEnter handles buffers opened during an active review session.
  -- The one-shot observer below handles buffers already open when data first loads.
  review_augroup = vim.api.nvim_create_augroup('NitReviewBuffers', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = review_augroup,
    callback = function(args)
      try_attach_buffer(args.buf)
    end,
  })

  observer_unsubscribe = observers.subscribe('comments', function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        try_attach_buffer(bufnr)
      end
    end
    if observer_unsubscribe then
      observer_unsubscribe()
      observer_unsubscribe = nil
    end
  end)

  controller.load()
end

---Stop review session
function M.stop()
  if not active then
    return
  end

  active = false

  if review_augroup then
    vim.api.nvim_create_augroup('NitReviewBuffers', { clear = true })
    review_augroup = nil
  end

  if observer_unsubscribe then
    observer_unsubscribe()
    observer_unsubscribe = nil
  end

  git_root = nil
  git_root_failed = false

  display_manager.detach_all()
  require('nit.display.comment_popup').close()
  controller.cleanup()
end

return M

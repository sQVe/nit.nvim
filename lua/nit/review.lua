---@class Nit.Review
local M = {}

local controller = require('nit.controller')
local display_manager = require('nit.display.manager')

local active = false

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
  controller.load()
end

---Stop review session
function M.stop()
  if not active then
    return
  end

  active = false
  display_manager.detach_all()
  require('nit.display.comment_popup').close()
  controller.cleanup()
end

return M

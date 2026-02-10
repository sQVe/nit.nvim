---@class Nit.Review
local M = {}

local controller = require('nit.controller')
local sidebar = require('nit.ui.sidebar')

---Start review session
function M.start()
  if sidebar.is_open() then
    return
  end
  sidebar.open({
    on_refresh = function()
      controller.refresh()
    end,
    on_close = function()
      controller.cleanup()
    end,
  })
  controller.load()
end

---Stop review session
function M.stop()
  if not sidebar.is_open() then
    return
  end
  sidebar.close()
end

---Toggle review session
function M.toggle()
  if sidebar.is_open() then
    M.stop()
  else
    M.start()
  end
end

return M

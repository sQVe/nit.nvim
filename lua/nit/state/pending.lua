---@class Nit.State.PendingModule
local M = {}

local observers = require('nit.state.observers')
local persistence = require('nit.state.persistence')

---@type Nit.State.PendingComment[]
local pending = {}

---@type boolean
local loaded = false

---@type integer
local next_id = 1

---Lazy load pending from persistence on first access
local function ensure_loaded()
  if loaded then
    return
  end
  loaded = true
  pending = persistence.load_pending()
  for _, comment in ipairs(pending) do
    if comment.id >= next_id then
      next_id = comment.id + 1
    end
  end
end

---Get all pending comments
---@return Nit.State.PendingComment[]
function M.get_pending()
  ensure_loaded()
  return pending
end

---Add a pending comment
---@param comment {path: string, line: integer, side: 'LEFT'|'RIGHT', body: string}
---@return integer id Generated ID
function M.add_pending(comment)
  ensure_loaded()
  local id = next_id
  next_id = next_id + 1

  ---@type Nit.State.PendingComment
  local new_comment = {
    id = id,
    path = comment.path,
    line = comment.line,
    side = comment.side,
    body = comment.body,
    created_at = os.date('!%Y-%m-%dT%H:%M:%SZ') --[[@as string]],
  }

  table.insert(pending, new_comment)
  observers.notify('pending')
  persistence.save_pending(pending)

  return id
end

---Update a pending comment body
---@param id integer Comment ID
---@param body string New body text
function M.update_pending(id, body)
  ensure_loaded()
  for _, comment in ipairs(pending) do
    if comment.id == id then
      comment.body = body
      observers.notify('pending')
      persistence.save_pending(pending)
      return
    end
  end
end

---Remove a pending comment
---@param id integer Comment ID
function M.remove_pending(id)
  ensure_loaded()
  for i, comment in ipairs(pending) do
    if comment.id == id then
      table.remove(pending, i)
      observers.notify('pending')
      persistence.save_pending(pending)
      return
    end
  end
end

---Clear all pending state (for testing)
function M.clear()
  pending = {}
  loaded = false
  next_id = 1
end

return M

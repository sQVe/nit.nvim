---@class Nit.Orchestration.Queue
local M = {}

---@class Nit.Orchestration.QueueState
---@field items fun(done: fun())[]
---@field processing boolean

---@type table<integer|string, Nit.Orchestration.QueueState>
local queues = {}

---Process next item in queue for a thread
---@param thread_id integer|string
local function process_next(thread_id)
  local queue = queues[thread_id]
  if not queue or #queue.items == 0 then
    if queue then
      queue.processing = false
    end
    return
  end

  local fn = table.remove(queue.items, 1)
  fn(function()
    process_next(thread_id)
  end)
end

---Enqueue a mutation function for a thread
---@param thread_id integer|string
---@param fn fun(done: fun())
function M.enqueue(thread_id, fn)
  if not queues[thread_id] then
    queues[thread_id] = {
      items = {},
      processing = false,
    }
  end

  local queue = queues[thread_id]

  if not queue.processing then
    queue.processing = true
    fn(function()
      process_next(thread_id)
    end)
  else
    table.insert(queue.items, fn)
  end
end

---Clear all queues
function M.reset()
  queues = {}
end

return M

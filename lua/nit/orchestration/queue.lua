---@class Nit.Orchestration.Queue
local M = {}

local MIN_DELAY_MS = 1100

---@class Nit.Orchestration.QueueState
---@field items fun(done: fun())[]
---@field processing boolean

---@type table<integer|string, Nit.Orchestration.QueueState>
local queues = {}

---@type integer|nil
local last_mutation_time = nil

---@type table<userdata|table, boolean>
local pending_timers = {}

local dispatch_next

---Run fn, record start time, handle errors
---@param thread_id integer|string
---@param fn fun(done: fun())
local function run(thread_id, fn)
  last_mutation_time = vim.uv.now()
  local dispatched = false
  local ok, err = pcall(fn, function()
    if dispatched then return end
    dispatched = true
    dispatch_next(thread_id, false)
  end)
  if not ok then
    vim.notify('[nit] Mutation failed: ' .. tostring(err), vim.log.levels.ERROR)
    if not dispatched then
      dispatch_next(thread_id, true)
    end
  end
end

---Schedule fn with global rate limiting, or immediately if skip_limit
---@param thread_id integer|string
---@param fn fun(done: fun())
---@param skip_limit boolean
local function schedule(thread_id, fn, skip_limit)
  if skip_limit or last_mutation_time == nil then
    run(thread_id, fn)
    return
  end
  local remaining = MIN_DELAY_MS - (vim.uv.now() - last_mutation_time)
  -- remaining >= MIN_DELAY_MS guards clock skew (negative elapsed)
  if remaining <= 0 or remaining >= MIN_DELAY_MS then
    run(thread_id, fn)
  else
    local timer = vim.uv.new_timer()
    pending_timers[timer] = true
    timer:start(remaining, 0, vim.schedule_wrap(function()
      timer:stop()
      timer:close()
      pending_timers[timer] = nil
      run(thread_id, fn)
    end))
  end
end

---Dispatch next queued item; skip_limit=true after errors
---@param thread_id integer|string
---@param skip_limit boolean
dispatch_next = function(thread_id, skip_limit)
  local q = queues[thread_id]
  if not q or #q.items == 0 then
    queues[thread_id] = nil
    return
  end
  schedule(thread_id, table.remove(q.items, 1), skip_limit)
end

---Enqueue a mutation function for a thread
---@param thread_id integer|string
---@param fn fun(done: fun())
function M.enqueue(thread_id, fn)
  if not queues[thread_id] then
    queues[thread_id] = { items = {}, processing = false }
  end
  local q = queues[thread_id]
  if not q.processing then
    q.processing = true
    schedule(thread_id, fn, false)
  else
    table.insert(q.items, fn)
  end
end

---Clear all queues and rate-limit state
function M.reset()
  for timer in pairs(pending_timers) do
    timer:stop()
    timer:close()
  end
  pending_timers = {}
  queues = {}
  last_mutation_time = nil
end

return M

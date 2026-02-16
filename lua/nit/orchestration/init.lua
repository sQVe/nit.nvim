---@class Nit.Orchestration
local M = {}

local data = require('nit.state.data')
local mutations = require('nit.api.mutations')
local versioning = require('nit.orchestration.versioning')
local snapshot = require('nit.orchestration.snapshot')
local queue = require('nit.orchestration.queue')

---@type table<integer, fun()>
local cancel_fns = {}
local cancel_counter = 0

---Track a cancel function and return its key
---@param cancel fun()
---@return integer
local function track_cancel(cancel)
  cancel_counter = cancel_counter + 1
  cancel_fns[cancel_counter] = cancel
  return cancel_counter
end

---Remove a tracked cancel function
---@param key integer?
local function untrack_cancel(key)
  if key ~= nil then
    cancel_fns[key] = nil
  end
end

---Submit a reply to a review thread
---@param opts { thread_id: Nit.Api.ThreadId, body: string }
---@param callback fun(ok: boolean, body: string?)
function M.submit_reply(opts, callback)
  local thread_id = opts.thread_id
  local thread = data.get_thread(thread_id)
  if not thread then
    callback(false, opts.body)
    return
  end

  local snap = snapshot.capture(thread_id)
  local submitted_body = opts.body

  local optimistic_comment = {
    id = 0,
    author = { login = 'you' },
    body = submitted_body,
    createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    path = nil,
    line = nil,
    side = nil,
    start_line = nil,
    start_side = nil,
  }

  local updated_thread = vim.deepcopy(thread)
  table.insert(updated_thread.comments, optimistic_comment)
  data.upsert_thread(updated_thread)

  queue.enqueue(thread_id, function(done)
    local version = versioning.increment(thread_id)
    local cancel_key
    local cancel = mutations.reply_to_thread(
      { thread_id = tostring(thread_id), body = submitted_body },
      function(result)
        untrack_cancel(cancel_key)

        if not versioning.is_current(thread_id, version) then
          done()
          callback(false, submitted_body)
          return
        end

        if result.ok then
          local current_thread = data.get_thread(thread_id)
          if current_thread then
            local updated = vim.deepcopy(current_thread)
            for i, comment in ipairs(updated.comments) do
              if comment.id == 0 and comment.body == submitted_body then
                updated.comments[i] = result.data
                break
              end
            end
            data.upsert_thread(updated)
          else
            vim.notify('[nit] Reply succeeded but thread was removed locally', vim.log.levels.WARN)
          end
          done()
          callback(true, nil)
        else
          if snap then
            snapshot.restore(snap)
          end
          done()
          vim.notify(
            '[nit] Reply failed: ' .. (result.error or 'unknown error'),
            vim.log.levels.ERROR
          )
          callback(false, submitted_body)
        end
      end
    )
    cancel_key = track_cancel(cancel)
  end)
end

---Toggle resolved state of a review thread
---@param opts { thread_id: Nit.Api.ThreadId }
---@param callback fun(ok: boolean)
function M.toggle_resolved(opts, callback)
  local thread_id = opts.thread_id
  local thread = data.get_thread(thread_id)
  if not thread then
    callback(false)
    return
  end

  local target_state = not thread.isResolved
  local snap = snapshot.capture(thread_id)

  local updated_thread = vim.deepcopy(thread)
  updated_thread.isResolved = target_state
  data.upsert_thread(updated_thread)

  local mutation_fn = target_state and mutations.resolve_thread or mutations.unresolve_thread
  local action_name = target_state and 'Resolve' or 'Unresolve'

  queue.enqueue(thread_id, function(done)
    local version = versioning.increment(thread_id)
    local cancel_key
    local cancel = mutation_fn({ thread_id = tostring(thread_id) }, function(result)
      untrack_cancel(cancel_key)

      if not versioning.is_current(thread_id, version) then
        done()
        callback(false)
        return
      end

      if result.ok then
        done()
        callback(true)
      else
        if snap then
          snapshot.restore(snap)
        end
        done()
        vim.notify(
          '[nit] ' .. action_name .. ' failed: ' .. (result.error or 'unknown error'),
          vim.log.levels.ERROR
        )
        callback(false)
      end
    end)
    cancel_key = track_cancel(cancel)
  end)
end

---Clean up orchestration state
function M.cleanup()
  for _, cancel in pairs(cancel_fns) do
    cancel()
  end
  cancel_fns = {}
  cancel_counter = 0
  versioning.reset()
  queue.reset()
end

return M

---@class Nit.Orchestration
local M = {}

local data = require('nit.state.data')
local mutations = require('nit.api.mutations')
local versioning = require('nit.orchestration.versioning')
local snapshot = require('nit.orchestration.snapshot')
local queue = require('nit.orchestration.queue')

---Rebuild state with updated thread
---@param thread Nit.Api.Thread
local function rebuild_threads(thread)
  local all_threads = data.get_threads()
  local updated_threads = {}

  for _, t in ipairs(all_threads) do
    if t.id ~= thread.id then
      table.insert(updated_threads, t)
    end
  end

  table.insert(updated_threads, thread)
  data.set_threads(updated_threads)
end

---Submit a reply to a review thread
---@param opts { thread_id: integer, body: string }
---@param callback fun(ok: boolean, body: string?)
function M.submit_reply(opts, callback)
  local thread_id = opts.thread_id
  local thread = data.get_thread(thread_id)
  if not thread then
    callback(false, opts.body)
    return
  end

  local snap = snapshot.capture(thread_id)
  local version = versioning.increment(thread_id)

  local optimistic_comment = {
    id = 0,
    author = { login = 'you' },
    body = opts.body,
    createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    path = nil,
    line = nil,
    side = nil,
    start_line = nil,
    start_side = nil,
  }

  local updated_thread = vim.deepcopy(thread)
  table.insert(updated_thread.comments, optimistic_comment)
  rebuild_threads(updated_thread)

  queue.enqueue(thread_id, function(done)
    mutations.reply_to_thread(
      { thread_id = tostring(thread_id), body = opts.body },
      function(result)
        if not versioning.is_current(thread_id, version) then
          done()
          callback(false, opts.body)
          return
        end

        if result.ok then
          local current_thread = data.get_thread(thread_id)
          if current_thread then
            local updated = vim.deepcopy(current_thread)
            for i, comment in ipairs(updated.comments) do
              if comment.id == 0 then
                updated.comments[i] = result.data
                break
              end
            end
            rebuild_threads(updated)
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
          callback(false, opts.body)
        end
      end
    )
  end)
end

---Toggle resolved state of a review thread
---@param opts { thread_id: integer }
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
  local version = versioning.increment(thread_id)

  local updated_thread = vim.deepcopy(thread)
  updated_thread.isResolved = target_state
  rebuild_threads(updated_thread)

  local mutation_fn = target_state and mutations.resolve_thread or mutations.unresolve_thread
  local action_name = target_state and 'Resolve' or 'Unresolve'

  queue.enqueue(thread_id, function(done)
    mutation_fn({ thread_id = tostring(thread_id) }, function(result)
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
  end)
end

---Clean up orchestration state
function M.cleanup()
  versioning.reset()
  queue.reset()
end

return M

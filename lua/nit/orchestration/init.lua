---@class Nit.Orchestration
local M = {}

---@class Nit.Orchestration.UpdateCommentOpts
---@field thread_id Nit.Api.ThreadId
---@field comment_id string
---@field comment_idx integer
---@field body string

---@class Nit.Orchestration.ToggleReactionOpts
---@field thread_id Nit.Api.ThreadId
---@field comment_idx integer
---@field content Nit.Api.ReactionContent

---@class Nit.Orchestration.SubmitReplyOpts
---@field thread_id Nit.Api.ThreadId
---@field body string

---@class Nit.Orchestration.ToggleResolvedOpts
---@field thread_id Nit.Api.ThreadId

local data = require('nit.state.data')
local mutations = require('nit.api.mutations')
local versioning = require('nit.orchestration.versioning')
local snapshot = require('nit.orchestration.snapshot')
local queue = require('nit.orchestration.queue')

---@type table<integer, fun()>
local cancel_fns = {}
local cancel_counter = 0
local optimistic_counter = 0

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
---@param opts Nit.Orchestration.SubmitReplyOpts
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

  optimistic_counter = optimistic_counter + 1
  local optimistic_id = 'optimistic_' .. optimistic_counter
  local optimistic_comment = {
    id = 0,
    _optimistic_id = optimistic_id,
    author = { login = data.get_viewer_login() or 'you' },
    body = submitted_body,
    createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    path = nil,
    line = nil,
    side = nil,
    start_line = nil,
    start_side = nil,
    reactions = {},
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
              if comment._optimistic_id == optimistic_id then
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
---@param opts Nit.Orchestration.ToggleResolvedOpts
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

---Update the body of an existing review comment
---@param opts Nit.Orchestration.UpdateCommentOpts
---@param callback fun(ok: boolean, body: string?)
function M.update_comment(opts, callback)
  local thread_id = opts.thread_id
  local thread = data.get_thread(thread_id)
  if not thread then
    callback(false, opts.body)
    return
  end

  local snap = snapshot.capture(thread_id)
  local submitted_body = opts.body

  local updated_thread = vim.deepcopy(thread)
  if updated_thread.comments[opts.comment_idx] then
    updated_thread.comments[opts.comment_idx].body = submitted_body
  end
  data.upsert_thread(updated_thread)

  queue.enqueue(thread_id, function(done)
    local version = versioning.increment(thread_id)
    local cancel_key
    local cancel = mutations.update_comment(
      { comment_id = opts.comment_id, body = submitted_body },
      function(result)
        untrack_cancel(cancel_key)

        if not versioning.is_current(thread_id, version) then
          done()
          callback(false, submitted_body)
          return
        end

        if result.ok then
          local current = data.get_thread(thread_id)
          if current and current.comments[opts.comment_idx] and result.data then
            local final = vim.deepcopy(current)
            final.comments[opts.comment_idx].body = result.data.body
            data.upsert_thread(final)
          end
          done()
          callback(true, nil)
        else
          if snap then
            snapshot.restore(snap)
          end
          done()
          vim.notify(
            '[nit] Edit failed: ' .. (result.error or 'unknown error'),
            vim.log.levels.ERROR
          )
          callback(false, submitted_body)
        end
      end
    )
    cancel_key = track_cancel(cancel)
  end)
end

---Toggle a reaction on a pull request review comment
---@param opts Nit.Orchestration.ToggleReactionOpts
---@param callback fun(ok: boolean)
function M.toggle_reaction(opts, callback)
  local thread_id = opts.thread_id
  local comment_idx = opts.comment_idx
  local content = opts.content

  local thread = data.get_thread(thread_id)
  if not thread then
    callback(false)
    return
  end

  local comment = thread.comments[comment_idx]
  if not comment then
    callback(false)
    return
  end

  if not comment.node_id or comment.node_id == '' then
    callback(false)
    return
  end

  local viewer_has_reacted = false
  for _, rg in ipairs(comment.reactions or {}) do
    if rg.content == content and rg.viewer_has_reacted then
      viewer_has_reacted = true
      break
    end
  end

  local snap = snapshot.capture(thread_id)

  local updated_thread = vim.deepcopy(thread)
  local updated_comment = updated_thread.comments[comment_idx]
  local found = false
  for _, rg in ipairs(updated_comment.reactions or {}) do
    if rg.content == content then
      rg.viewer_has_reacted = not viewer_has_reacted
      rg.count = viewer_has_reacted and math.max(0, rg.count - 1) or rg.count + 1
      found = true
      break
    end
  end
  if not found and not viewer_has_reacted then
    if not updated_comment.reactions then
      updated_comment.reactions = {}
    end
    table.insert(
      updated_comment.reactions,
      { content = content, count = 1, viewer_has_reacted = true }
    )
  end
  data.upsert_thread(updated_thread)

  local mutation_fn = viewer_has_reacted and mutations.remove_reaction or mutations.add_reaction

  queue.enqueue(thread_id, function(done)
    local version = versioning.increment(thread_id)
    local cancel_key
    local cancel = mutation_fn({ node_id = comment.node_id, content = content }, function(result)
      untrack_cancel(cancel_key)

      if not versioning.is_current(thread_id, version) then
        done()
        callback(false)
        return
      end

      if result.ok then
        local current_thread = data.get_thread(thread_id)
        if current_thread and current_thread.comments[comment_idx] then
          local final_thread = vim.deepcopy(current_thread)
          if result.data and #result.data > 0 then
            final_thread.comments[comment_idx].reactions = result.data
          end
          data.upsert_thread(final_thread)
        end
        done()
        callback(true)
      else
        if snap then
          snapshot.restore(snap)
        end
        done()
        vim.notify(
          '[nit] React failed: ' .. (result.error or 'unknown error'),
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
  optimistic_counter = 0
  versioning.reset()
  queue.reset()
end

return M

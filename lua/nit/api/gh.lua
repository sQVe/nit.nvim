local tracker = require('nit.api.tracker')

local M = {}

local DEFAULT_TIMEOUT = 10000
local DEFAULT_RETRY = 2

---Check if error is transient and should be retried
---@param stderr string
---@return boolean
local function is_transient_error(stderr)
  if not stderr then
    return false
  end
  local lower = stderr:lower()
  return lower:match('timeout') or lower:match('network') or lower:match('connection')
end

---Check if error is an authentication error
---@param stderr string
---@return boolean
local function is_auth_error(stderr)
  if not stderr then
    return false
  end
  return stderr:lower():match('authentication') or stderr:lower():match('not authenticated')
end

---Create user-friendly error message
---@param stderr string
---@param timed_out boolean
---@return string
local function make_error_message(stderr, timed_out)
  if timed_out then
    return 'Request timed out'
  end
  if is_auth_error(stderr) then
    return 'Not authenticated'
  end
  if is_transient_error(stderr) then
    return 'Network error'
  end
  return stderr and stderr:match('^[^\n]+') or 'Unknown error'
end

---Execute gh CLI command asynchronously
---@param args string[] Command arguments (e.g., {'pr', 'view', '--json', 'title'})
---@param opts? Nit.Api.RequestOpts Request options
---@param callback fun(result: Nit.Api.Result) Called on completion
---@return fun() cancel Cancel function
function M.execute(args, opts, callback)
  opts = opts or {}
  local timeout = opts.timeout or DEFAULT_TIMEOUT
  local max_retries = opts.retry or DEFAULT_RETRY
  local retry_count = 0

  local cmd = vim.list_extend({ 'gh' }, args)
  local completed = false
  local timer = nil
  local process = nil

  local wrapped_callback = vim.schedule_wrap(callback)
  local retry_timer = nil

  local function cleanup()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    if retry_timer then
      retry_timer:stop()
      retry_timer:close()
      retry_timer = nil
    end
  end

  local function complete_once(result)
    if completed then
      return
    end
    completed = true
    cleanup()
    wrapped_callback(result)
  end

  local function execute_with_retry()
    local timed_out = false

    timer = vim.uv.new_timer()
    if timer then
      timer:start(timeout, 0, vim.schedule_wrap(function()
        timed_out = true
        if process then
          process:kill(9)
        end
        complete_once({ ok = false, error = 'Request timed out' })
      end))
    end

    process = vim.system(cmd, { text = true }, function(result)
      if completed then
        return
      end

      cleanup()

      if timed_out then
        return
      end

      if result.code == 0 then
        complete_once({ ok = true, data = result.stdout })
      else
        local stderr = result.stderr or ''
        local should_retry = retry_count < max_retries
          and is_transient_error(stderr)
          and not is_auth_error(stderr)

        if should_retry then
          retry_count = retry_count + 1
          local delay = math.pow(2, retry_count - 1) * 1000
          retry_timer = vim.uv.new_timer()
          if retry_timer then
            retry_timer:start(delay, 0, vim.schedule_wrap(function()
              retry_timer:close()
              retry_timer = nil
              if not completed then
                execute_with_retry()
              end
            end))
          end
        else
          local error_msg = make_error_message(stderr, false)
          complete_once({ ok = false, error = error_msg })
        end
      end
    end)
  end

  local request_id = nil

  local cancel = function()
    if completed then
      return
    end
    completed = true
    cleanup()
    if request_id then
      tracker.untrack(request_id)
    end
    if process then
      process:kill(9)
    end
  end

  request_id = tracker.track(cancel)

  local original_callback = callback
  callback = function(result)
    tracker.untrack(request_id)
    original_callback(result)
  end
  wrapped_callback = vim.schedule_wrap(callback)

  execute_with_retry()

  return cancel
end

return M

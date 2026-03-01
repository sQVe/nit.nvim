describe('nit.orchestration.queue', function()
  local queue = require('nit.orchestration.queue')
  local real_uv_now = vim.uv.now
  local real_uv_new_timer = vim.uv.new_timer
  local auto_time

  before_each(function()
    auto_time = 0
    vim.uv.now = function()
      auto_time = auto_time + 2000
      return auto_time
    end
    vim.uv.new_timer = function()
      return {
        start = function(_, _, _, cb)
          cb()
        end,
        stop = function() end,
        close = function() end,
      }
    end
  end)

  after_each(function()
    queue.reset()
    vim.uv.now = real_uv_now
    vim.uv.new_timer = real_uv_new_timer
  end)

  describe('enqueue', function()
    it('calls fn immediately when queue is empty for that thread', function()
      local called = false
      queue.enqueue('thread-1', function(done)
        called = true
        done()
      end)
      assert.is_true(called)
    end)

    it('defers second fn until first calls done', function()
      local calls = {}

      local done1
      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'first')
        done1 = done
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'second')
        done()
      end)

      assert.are.same({ 'first' }, calls)

      done1()
      assert.are.same({ 'first', 'second' }, calls)
    end)

    it('processes items in FIFO order', function()
      local calls = {}
      local done_callbacks = {}

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'first')
        table.insert(done_callbacks, done)
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'second')
        table.insert(done_callbacks, done)
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'third')
        table.insert(done_callbacks, done)
      end)

      assert.are.same({ 'first' }, calls)

      done_callbacks[1]()
      assert.are.same({ 'first', 'second' }, calls)

      done_callbacks[2]()
      assert.are.same({ 'first', 'second', 'third' }, calls)

      done_callbacks[3]()
      assert.are.same({ 'first', 'second', 'third' }, calls)
    end)

    it('allows different thread_ids to have independent queues', function()
      local calls = {}

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'thread-1')
        done()
      end)

      queue.enqueue('thread-2', function(done)
        table.insert(calls, 'thread-2')
        done()
      end)

      assert.are.equal(2, #calls)
      assert.is_true(vim.tbl_contains(calls, 'thread-1'))
      assert.is_true(vim.tbl_contains(calls, 'thread-2'))
    end)
  end)

  describe('error recovery', function()
    local original_notify = vim.notify

    after_each(function()
      vim.notify = original_notify
    end)

    it('continues processing after immediate function throws', function()
      local notify_msg = ''
      vim.notify = function(msg)
        notify_msg = msg
      end

      local second_called = false
      queue.enqueue('thread-1', function()
        error('boom')
      end)

      queue.enqueue('thread-1', function(done)
        second_called = true
        done()
      end)

      assert.is_true(second_called)
      assert.is_truthy(notify_msg:find('boom'))
    end)

    it('continues processing after queued function throws', function()
      local notify_msg = ''
      vim.notify = function(msg)
        notify_msg = msg
      end

      local done1
      queue.enqueue('thread-1', function(done)
        done1 = done
      end)

      local third_called = false
      queue.enqueue('thread-1', function()
        error('queued boom')
      end)

      queue.enqueue('thread-1', function(done)
        third_called = true
        done()
      end)

      done1()

      assert.is_true(third_called)
      assert.is_truthy(notify_msg:find('queued boom'))
    end)
  end)

  describe('rate limiting', function()
    local original_uv_now = vim.uv.now
    local original_uv_new_timer = vim.uv.new_timer
    local original_schedule_wrap = vim.schedule_wrap
    local original_notify = vim.notify
    local mock_time
    local mock_timers

    before_each(function()
      mock_time = 0
      mock_timers = {}

      vim.uv.now = function()
        return mock_time
      end
      vim.schedule_wrap = function(fn)
        return fn
      end

      vim.uv.new_timer = function()
        local timer = {
          started = false,
          delay = nil,
          callback = nil,
        }
        table.insert(mock_timers, timer)
        return {
          start = function(_, delay, _, cb)
            timer.started = true
            timer.delay = delay
            timer.callback = cb
          end,
          stop = function()
            timer.started = false
          end,
          close = function() end,
        }
      end
    end)

    after_each(function()
      vim.uv.now = original_uv_now
      vim.uv.new_timer = original_uv_new_timer
      vim.schedule_wrap = original_schedule_wrap
      vim.notify = original_notify
    end)

    it('delays second mutation when dispatched within 1100ms', function()
      local calls = {}

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'first')
        mock_time = 500
        done()
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'second')
        done()
      end)

      assert.are.same({ 'first' }, calls)
      assert.are.equal(1, #mock_timers)
      assert.are.equal(600, mock_timers[1].delay)

      mock_time = 1100
      mock_timers[1].callback()
      assert.are.same({ 'first', 'second' }, calls)
    end)

    it('executes second mutation immediately when 1100ms elapsed', function()
      local calls = {}

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'first')
        mock_time = 1200
        done()
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'second')
        done()
      end)

      assert.are.same({ 'first', 'second' }, calls)
      assert.are.equal(0, #mock_timers)
    end)

    it('applies rate limit across different thread_ids', function()
      local calls = {}

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'thread-1')
        mock_time = 300
        done()
      end)

      queue.enqueue('thread-2', function(done)
        table.insert(calls, 'thread-2')
        done()
      end)

      assert.are.same({ 'thread-1' }, calls)
      assert.are.equal(1, #mock_timers)
      assert.are.equal(800, mock_timers[1].delay)

      mock_time = 1100
      mock_timers[1].callback()
      assert.are.same({ 'thread-1', 'thread-2' }, calls)
    end)

    it('resets rate-limit state on reset()', function()
      queue.enqueue('thread-1', function(done)
        mock_time = 500
        done()
      end)

      queue.reset()

      local called = false
      queue.enqueue('thread-1', function(done)
        called = true
        done()
      end)

      assert.is_true(called)
      assert.are.equal(0, #mock_timers)
    end)

    it('recovers from errors with delayed dispatch', function()
      vim.notify = function() end

      local done1
      queue.enqueue('thread-1', function(done)
        done1 = done
      end)

      queue.enqueue('thread-1', function()
        error('delayed boom')
      end)

      local third_called = false
      queue.enqueue('thread-1', function(done)
        third_called = true
        done()
      end)

      mock_time = 500
      done1()

      assert.are.equal(1, #mock_timers)
      assert.are.equal(600, mock_timers[1].delay)
      mock_time = 1100
      mock_timers[1].callback()

      assert.is_true(third_called)
    end)
  end)

  describe('reset', function()
    it('clears all queues', function()
      local calls = {}

      local done1
      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'first')
        done1 = done
      end)

      queue.enqueue('thread-1', function(done)
        table.insert(calls, 'second')
        done()
      end)

      queue.reset()

      done1()

      assert.are.same({ 'first' }, calls)
    end)
  end)
end)

describe('nit.orchestration.queue', function()
  local queue = require('nit.orchestration.queue')

  after_each(function()
    queue.reset()
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

      assert.same({ 'first' }, calls)

      done1()
      assert.same({ 'first', 'second' }, calls)
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

      assert.same({ 'first' }, calls)

      done_callbacks[1]()
      assert.same({ 'first', 'second' }, calls)

      done_callbacks[2]()
      assert.same({ 'first', 'second', 'third' }, calls)

      done_callbacks[3]()
      assert.same({ 'first', 'second', 'third' }, calls)
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

      assert.equals(2, #calls)
      assert.is_true(vim.tbl_contains(calls, 'thread-1'))
      assert.is_true(vim.tbl_contains(calls, 'thread-2'))
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

      assert.same({ 'first' }, calls)
    end)
  end)
end)

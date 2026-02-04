describe('nit.state.observers', function()
  local observers = require('nit.state.observers')

  after_each(function()
    observers.clear()
  end)

  describe('subscribe', function()
    it('returns unsubscribe function', function()
      local unsub = observers.subscribe('pr', function() end)
      assert.is_function(unsub)
    end)

    it('callback receives key name as argument', function()
      local received_key = nil
      observers.subscribe('comments', function(key)
        received_key = key
      end)

      observers.notify('comments')
      local ok = vim.wait(100, function()
        return received_key ~= nil
      end)

      assert.is_true(ok, 'callback was not invoked')
      assert.equals('comments', received_key)
    end)

    it('unsubscribe prevents future callbacks', function()
      local call_count = 0
      local unsub = observers.subscribe('files', function()
        call_count = call_count + 1
      end)

      observers.notify('files')
      local ok = vim.wait(100, function()
        return call_count > 0
      end)
      assert.is_true(ok, 'callback was not invoked')
      assert.equals(1, call_count)

      unsub()

      observers.notify('files')
      vim.wait(50)
      assert.equals(1, call_count, 'callback should not be called after unsubscribe')
    end)

    it('multiple subscribers on same key all called', function()
      local calls = {}
      observers.subscribe('pr', function()
        table.insert(calls, 'first')
      end)
      observers.subscribe('pr', function()
        table.insert(calls, 'second')
      end)

      observers.notify('pr')
      local ok = vim.wait(100, function()
        return #calls >= 2
      end)

      assert.is_true(ok, 'callbacks were not invoked')
      assert.equals(2, #calls)
    end)
  end)

  describe('notify', function()
    it('batches rapid notify calls into one callback execution', function()
      local call_count = 0
      observers.subscribe('comments', function()
        call_count = call_count + 1
      end)

      observers.notify('comments')
      observers.notify('comments')
      observers.notify('comments')

      local ok = vim.wait(100, function()
        return call_count > 0
      end)

      assert.is_true(ok, 'callback was not invoked')
      assert.equals(1, call_count, 'rapid notifies should batch into single callback')
    end)

    it('different keys both dirty run in same scheduled pass', function()
      local calls = {}
      observers.subscribe('pr', function()
        table.insert(calls, 'pr')
      end)
      observers.subscribe('files', function()
        table.insert(calls, 'files')
      end)

      observers.notify('pr')
      observers.notify('files')

      local ok = vim.wait(100, function()
        return #calls >= 2
      end)

      assert.is_true(ok, 'callbacks were not invoked')
      assert.equals(2, #calls)
    end)

    it('errors in one callback do not prevent others', function()
      local second_called = false
      observers.subscribe('pr', function()
        error('intentional error')
      end)
      observers.subscribe('pr', function()
        second_called = true
      end)

      observers.notify('pr')

      local ok = vim.wait(100, function()
        return second_called
      end)

      assert.is_true(ok, 'second callback was not invoked')
    end)
  end)
end)

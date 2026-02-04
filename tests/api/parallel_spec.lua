describe('nit.api.parallel', function()
  local parallel = require('nit.api.parallel')

  describe('parallel', function()
    it('returns a cancel function', function()
      local cancel = parallel.parallel({}, function() end)
      assert.is_function(cancel)
    end)

    it('handles empty operations array', function()
      local result = nil
      parallel.parallel({}, function(results)
        result = results
      end)

      vim.wait(100, function()
        return result ~= nil
      end)

      assert.are.same({}, result)
    end)

    it('executes all operations and collects results', function()
      local results = nil

      local op1 = {
        fn = function(_opts, callback)
          callback({ ok = true, data = 'result1' })
          return function() end
        end,
        args = {},
      }

      local op2 = {
        fn = function(_opts, callback)
          callback({ ok = true, data = 'result2' })
          return function() end
        end,
        args = {},
      }

      local op3 = {
        fn = function(_opts, callback)
          callback({ ok = true, data = 'result3' })
          return function() end
        end,
        args = {},
      }

      parallel.parallel({ op1, op2, op3 }, function(r)
        results = r
      end)

      assert.equals(3, #results)
      assert.is_true(results[1].ok)
      assert.equals('result1', results[1].data)
      assert.is_true(results[2].ok)
      assert.equals('result2', results[2].data)
      assert.is_true(results[3].ok)
      assert.equals('result3', results[3].data)
    end)

    it('maintains result order matching operations order', function()
      local results = nil
      local _completed = {}

      local op1 = {
        fn = function(_opts, callback)
          table.insert(_completed, 1)
          callback({ ok = true, data = 'first' })
          return function() end
        end,
        args = {},
      }

      local op2 = {
        fn = function(_opts, callback)
          table.insert(_completed, 2)
          callback({ ok = true, data = 'second' })
          return function() end
        end,
        args = {},
      }

      parallel.parallel({ op1, op2 }, function(r)
        results = r
      end)

      assert.equals('first', results[1].data)
      assert.equals('second', results[2].data)
    end)

    it('handles mixed success and error results', function()
      local results = nil

      local op1 = {
        fn = function(_opts, callback)
          callback({ ok = true, data = 'success' })
          return function() end
        end,
        args = {},
      }

      local op2 = {
        fn = function(_opts, callback)
          callback({ ok = false, error = 'failed' })
          return function() end
        end,
        args = {},
      }

      local op3 = {
        fn = function(_opts, callback)
          callback({ ok = true, data = 'another success' })
          return function() end
        end,
        args = {},
      }

      parallel.parallel({ op1, op2, op3 }, function(r)
        results = r
      end)

      assert.is_true(results[1].ok)
      assert.equals('success', results[1].data)
      assert.is_false(results[2].ok)
      assert.equals('failed', results[2].error)
      assert.is_true(results[3].ok)
      assert.equals('another success', results[3].data)
    end)

    it('passes args to operation functions', function()
      local received_args = nil

      local op = {
        fn = function(opts, callback)
          received_args = opts
          callback({ ok = true, data = 'ok' })
          return function() end
        end,
        args = { test = 'value', number = 123 },
      }

      parallel.parallel({ op }, function() end)

      assert.are.same({ test = 'value', number = 123 }, received_args)
    end)

    it('cancel function calls all operation cancel functions', function()
      local cancel_counts = { 0, 0, 0 }

      local op1 = {
        fn = function(_opts, _callback)
          return function()
            cancel_counts[1] = cancel_counts[1] + 1
          end
        end,
        args = {},
      }

      local op2 = {
        fn = function(_opts, _callback)
          return function()
            cancel_counts[2] = cancel_counts[2] + 1
          end
        end,
        args = {},
      }

      local op3 = {
        fn = function(_opts, _callback)
          return function()
            cancel_counts[3] = cancel_counts[3] + 1
          end
        end,
        args = {},
      }

      local cancel = parallel.parallel({ op1, op2, op3 }, function() end)
      cancel()

      assert.equals(1, cancel_counts[1])
      assert.equals(1, cancel_counts[2])
      assert.equals(1, cancel_counts[3])
    end)

    it('waits for all operations before calling callback', function()
      local callback_called = false
      local completed_count = 0

      local delayed_ops = {}
      for i = 1, 3 do
        table.insert(delayed_ops, {
          fn = function(_opts, callback)
            vim.defer_fn(function()
              completed_count = completed_count + 1
              callback({ ok = true, data = i })
            end, i * 10)
            return function() end
          end,
          args = {},
        })
      end

      parallel.parallel(delayed_ops, function(results)
        callback_called = true
        assert.equals(3, completed_count)
        assert.equals(3, #results)
      end)

      vim.wait(100, function()
        return callback_called
      end)

      assert.is_true(callback_called)
    end)
  end)
end)

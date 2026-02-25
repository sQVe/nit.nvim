describe('nit.api.tracker', function()
  local tracker

  before_each(function()
    package.loaded['nit.api.tracker'] = nil
    tracker = require('nit.api.tracker')
  end)

  describe('track', function()
    it('returns unique incrementing IDs', function()
      local id1 = tracker.track(function() end)
      local id2 = tracker.track(function() end)
      local id3 = tracker.track(function() end)

      assert.is_number(id1)
      assert.is_number(id2)
      assert.is_number(id3)
      assert.are.equal(id1 + 1, id2)
      assert.are.equal(id2 + 1, id3)
    end)
  end)

  describe('untrack', function()
    it('removes specific request', function()
      tracker.track(function() end)
      local id2 = tracker.track(function() end)
      tracker.track(function() end)

      tracker.untrack(id2)

      assert.are.equal(2, tracker.get_count())
    end)

    it('does nothing for nonexistent ID', function()
      tracker.track(function() end)

      tracker.untrack(999)

      assert.are.equal(1, tracker.get_count())
    end)
  end)

  describe('cancel_all', function()
    it('invokes all cancel functions and clears table', function()
      local cancelled = {}

      tracker.track(function()
        table.insert(cancelled, 'a')
      end)
      tracker.track(function()
        table.insert(cancelled, 'b')
      end)
      tracker.track(function()
        table.insert(cancelled, 'c')
      end)

      tracker.cancel_all()

      assert.are.equal(3, #cancelled)
      assert.are.equal(0, tracker.get_count())
    end)

    it('does not double-cancel on second call', function()
      local cancel_count = 0

      tracker.track(function()
        cancel_count = cancel_count + 1
      end)

      tracker.cancel_all()
      tracker.cancel_all()

      assert.are.equal(1, cancel_count)
    end)
  end)

  describe('get_count', function()
    it('returns 0 when empty', function()
      assert.are.equal(0, tracker.get_count())
    end)

    it('reflects current tracked count after track and untrack', function()
      local id1 = tracker.track(function() end)
      tracker.track(function() end)
      assert.are.equal(2, tracker.get_count())

      tracker.untrack(id1)
      assert.are.equal(1, tracker.get_count())
    end)
  end)
end)

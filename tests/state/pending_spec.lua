describe('nit.state.pending', function()
  local pending_module
  local observers
  local persistence

  local original_save_pending
  local original_load_pending
  local saved_data
  local loaded_data

  before_each(function()
    package.loaded['nit.state.pending'] = nil
    package.loaded['nit.state.observers'] = nil
    observers = require('nit.state.observers')

    persistence = require('nit.state.persistence')
    original_save_pending = persistence.save_pending
    original_load_pending = persistence.load_pending

    saved_data = nil
    loaded_data = {}

    persistence.save_pending = function(data)
      saved_data = vim.deepcopy(data)
    end

    persistence.load_pending = function()
      return vim.deepcopy(loaded_data)
    end

    pending_module = require('nit.state.pending')
  end)

  after_each(function()
    pending_module.clear()
    observers.clear()
    persistence.save_pending = original_save_pending
    persistence.load_pending = original_load_pending
  end)

  describe('add_pending', function()
    it('creates comment with generated ID', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test comment',
      })

      assert.is_number(id)
      assert.is_true(id > 0)
    end)

    it('sets created_at to ISO 8601 timestamp', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test comment',
      })

      local comments = pending_module.get_pending()
      assert.are.equal(1, #comments)
      assert.is_string(comments[1].created_at)
      assert.is_truthy(comments[1].created_at:match('^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$'))
    end)

    it('generates incrementing IDs', function()
      local id1 = pending_module.add_pending({
        path = 'file1.lua',
        line = 1,
        side = 'RIGHT',
        body = 'First',
      })

      local id2 = pending_module.add_pending({
        path = 'file2.lua',
        line = 2,
        side = 'LEFT',
        body = 'Second',
      })

      assert.are.equal(id1 + 1, id2)
    end)

    it('continues ID sequence from max loaded ID', function()
      loaded_data = {
        {
          id = 5,
          path = 'first.lua',
          line = 1,
          side = 'RIGHT',
          body = 'First',
          created_at = '2026-01-01T00:00:00Z',
        },
        {
          id = 10,
          path = 'second.lua',
          line = 2,
          side = 'LEFT',
          body = 'Second',
          created_at = '2026-01-01T00:00:00Z',
        },
        {
          id = 3,
          path = 'third.lua',
          line = 3,
          side = 'RIGHT',
          body = 'Third',
          created_at = '2026-01-01T00:00:00Z',
        },
      }

      package.loaded['nit.state.pending'] = nil
      pending_module = require('nit.state.pending')

      local new_id = pending_module.add_pending({
        path = 'new.lua',
        line = 100,
        side = 'RIGHT',
        body = 'New comment',
      })

      assert.are.equal(11, new_id)
    end)

    it('triggers observer notification', function()
      local notified_key = nil
      observers.subscribe('pending', function(key)
        notified_key = key
      end)

      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test comment',
      })

      local ok = vim.wait(100, function()
        return notified_key ~= nil
      end)

      assert.is_true(ok, 'observer was not notified')
      assert.are.equal('pending', notified_key)
    end)

    it('auto-persists to disk', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test comment',
      })

      assert.is_not_nil(saved_data)
      assert.are.equal(1, #saved_data)
      assert.are.equal('src/main.lua', saved_data[1].path)
    end)
  end)

  describe('get_pending', function()
    it('returns empty array when no pending comments', function()
      local result = pending_module.get_pending()

      assert.is_table(result)
      assert.are.equal(0, #result)
    end)

    it('returns added comments', function()
      pending_module.add_pending({
        path = 'file1.lua',
        line = 1,
        side = 'RIGHT',
        body = 'First',
      })
      pending_module.add_pending({
        path = 'file2.lua',
        line = 2,
        side = 'LEFT',
        body = 'Second',
      })

      local result = pending_module.get_pending()

      assert.are.equal(2, #result)
      assert.are.equal('file1.lua', result[1].path)
      assert.are.equal('file2.lua', result[2].path)
    end)

    it('lazy-loads from persistence on first access', function()
      loaded_data = {
        {
          id = 1,
          path = 'loaded.lua',
          line = 5,
          side = 'RIGHT',
          body = 'Loaded from disk',
          created_at = '2026-01-01T00:00:00Z',
        },
      }

      package.loaded['nit.state.pending'] = nil
      pending_module = require('nit.state.pending')

      local result = pending_module.get_pending()

      assert.are.equal(1, #result)
      assert.are.equal('loaded.lua', result[1].path)
      assert.are.equal('Loaded from disk', result[1].body)
    end)

    it('returns copy to prevent mutation of internal state', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original',
      })

      local result = pending_module.get_pending()
      result[1].body = 'Mutated'
      table.insert(result, { id = 999, path = 'fake.lua' })

      local fresh = pending_module.get_pending()
      assert.are.equal('Original', fresh[1].body)
      assert.are.equal(1, #fresh)
    end)
  end)

  describe('update_pending', function()
    it('updates body of existing comment', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original body',
      })

      pending_module.update_pending(id, 'Updated body')

      local comments = pending_module.get_pending()
      assert.are.equal(1, #comments)
      assert.are.equal('Updated body', comments[1].body)
    end)

    it('triggers observer notification', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original',
      })

      local notification_count = 0
      observers.subscribe('pending', function()
        notification_count = notification_count + 1
      end)

      pending_module.update_pending(id, 'Updated')

      local ok = vim.wait(100, function()
        return notification_count > 0
      end)

      assert.is_true(ok, 'observer was not notified')
    end)

    it('auto-persists to disk', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original',
      })

      saved_data = nil
      pending_module.update_pending(id, 'Updated')

      assert.is_not_nil(saved_data)
      assert.are.equal('Updated', saved_data[1].body)
    end)

    it('does nothing for nonexistent ID', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original',
      })

      pending_module.update_pending(999, 'Should not apply')

      local comments = pending_module.get_pending()
      assert.are.equal('Original', comments[1].body)
    end)

    it('returns true when comment is found and updated', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Original',
      })

      assert.is_true(pending_module.update_pending(id, 'Updated'))
    end)

    it('returns false when comment is not found', function()
      assert.is_false(pending_module.update_pending(999, 'No match'))
    end)
  end)

  describe('remove_pending', function()
    it('removes comment by ID', function()
      local id1 = pending_module.add_pending({
        path = 'file1.lua',
        line = 1,
        side = 'RIGHT',
        body = 'First',
      })
      pending_module.add_pending({
        path = 'file2.lua',
        line = 2,
        side = 'LEFT',
        body = 'Second',
      })

      pending_module.remove_pending(id1)

      local comments = pending_module.get_pending()
      assert.are.equal(1, #comments)
      assert.are.equal('file2.lua', comments[1].path)
    end)

    it('triggers observer notification', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test',
      })

      local notification_count = 0
      observers.subscribe('pending', function()
        notification_count = notification_count + 1
      end)

      pending_module.remove_pending(id)

      local ok = vim.wait(100, function()
        return notification_count > 0
      end)

      assert.is_true(ok, 'observer was not notified')
    end)

    it('auto-persists to disk', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test',
      })

      saved_data = nil
      pending_module.remove_pending(id)

      assert.is_not_nil(saved_data)
      assert.are.equal(0, #saved_data)
    end)

    it('does nothing for nonexistent ID', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test',
      })

      pending_module.remove_pending(999)

      local comments = pending_module.get_pending()
      assert.are.equal(1, #comments)
    end)

    it('returns true when comment is found and removed', function()
      local id = pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test',
      })

      assert.is_true(pending_module.remove_pending(id))
    end)

    it('returns false when comment is not found', function()
      assert.is_false(pending_module.remove_pending(999))
    end)
  end)

  describe('clear', function()
    it('resets pending to empty array', function()
      pending_module.add_pending({
        path = 'src/main.lua',
        line = 10,
        side = 'RIGHT',
        body = 'Test',
      })

      pending_module.clear()

      local comments = pending_module.get_pending()
      assert.are.equal(0, #comments)
    end)

    it('resets loaded flag for lazy loading', function()
      pending_module.add_pending({
        path = 'in-memory.lua',
        line = 1,
        side = 'RIGHT',
        body = 'In memory',
      })

      pending_module.clear()

      loaded_data = {
        {
          id = 1,
          path = 'from-disk.lua',
          line = 5,
          side = 'LEFT',
          body = 'From disk',
          created_at = '2026-01-01T00:00:00Z',
        },
      }

      local comments = pending_module.get_pending()
      assert.are.equal(1, #comments)
      assert.are.equal('from-disk.lua', comments[1].path)
    end)
  end)
end)

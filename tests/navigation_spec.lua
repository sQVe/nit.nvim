describe('navigation', function()
  local navigation
  local review_mock = {
    active = true,
  }

  local manager_mock = {
    commented_lines = {},
  }

  local api_mock = {
    current_buf = 1,
    cursor = { 10, 0 },
    cursor_set_calls = {},
    cursor_fails = false,
    set_cursor_fails = false,
  }

  local cmd_calls = {}
  local notify_calls = {}
  local orig_vim = {}

  before_each(function()
    review_mock.active = true
    manager_mock.commented_lines = {}
    api_mock.current_buf = 1
    api_mock.cursor = { 10, 0 }
    api_mock.cursor_set_calls = {}
    api_mock.cursor_fails = false
    api_mock.set_cursor_fails = false
    cmd_calls = {}
    notify_calls = {}

    orig_vim.nvim_get_current_buf = vim.api.nvim_get_current_buf
    orig_vim.nvim_win_get_cursor = vim.api.nvim_win_get_cursor
    orig_vim.nvim_win_set_cursor = vim.api.nvim_win_set_cursor
    orig_vim.cmd = vim.cmd
    orig_vim.notify = vim.notify

    package.loaded['nit.review'] = {
      is_active = function()
        return review_mock.active
      end,
    }

    package.loaded['nit.display.manager'] = {
      get_commented_lines = function(_)
        return manager_mock.commented_lines
      end,
    }

    vim.api.nvim_get_current_buf = function()
      return api_mock.current_buf
    end

    vim.api.nvim_win_get_cursor = function(_)
      if api_mock.cursor_fails then
        error('cursor API failed')
      end
      return api_mock.cursor
    end

    vim.api.nvim_win_set_cursor = function(_, pos)
      if api_mock.set_cursor_fails then
        error('set cursor failed')
      end
      table.insert(api_mock.cursor_set_calls, { pos = pos })
    end

    vim.cmd = function(cmd)
      table.insert(cmd_calls, cmd)
    end

    vim.notify = function(msg, level)
      table.insert(notify_calls, { msg = msg, level = level })
    end

    package.loaded['nit.navigation'] = nil
    navigation = require('nit.navigation')
  end)

  after_each(function()
    vim.api.nvim_get_current_buf = orig_vim.nvim_get_current_buf
    vim.api.nvim_win_get_cursor = orig_vim.nvim_win_get_cursor
    vim.api.nvim_win_set_cursor = orig_vim.nvim_win_set_cursor
    vim.cmd = orig_vim.cmd
    vim.notify = orig_vim.notify

    package.loaded['nit.review'] = nil
    package.loaded['nit.display.manager'] = nil
    package.loaded['nit.navigation'] = nil
  end)

  describe('next_comment', function()
    it('jumps to next comment line', function()
      api_mock.cursor = { 5, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 10, 0 }, api_mock.cursor_set_calls[1].pos)
      assert.are.same({ 'normal! ^' }, cmd_calls)
    end)

    it('jumps to immediate next when between comments', function()
      api_mock.cursor = { 12, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 20, 0 }, api_mock.cursor_set_calls[1].pos)
      assert.are.same({ 'normal! ^' }, cmd_calls)
    end)

    it('is silent no-op at last comment', function()
      api_mock.cursor = { 20, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, cmd_calls)
    end)

    it('is silent no-op past last comment', function()
      api_mock.cursor = { 25, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, cmd_calls)
    end)

    it('is silent no-op with no comments', function()
      api_mock.cursor = { 10, 0 }
      manager_mock.commented_lines = {}

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('is silent no-op when active review but buffer unattached', function()
      api_mock.cursor = { 10, 0 }
      manager_mock.commented_lines = nil

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('is silent no-op when nvim_win_get_cursor fails', function()
      api_mock.cursor_fails = true
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('handles unsorted commented_lines keys deterministically', function()
      api_mock.cursor = { 5, 0 }
      manager_mock.commented_lines = { [20] = {}, [3] = {}, [10] = {} }

      navigation.next_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 10, 0 }, api_mock.cursor_set_calls[1].pos)
    end)

    it('notifies when no active review', function()
      review_mock.active = false
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.next_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.is_not_nil(notify_calls[1])
      assert.are.equal('[nit] no active review', notify_calls[1].msg)
      assert.are.equal(vim.log.levels.WARN, notify_calls[1].level)
    end)
  end)

  describe('prev_comment', function()
    it('jumps to previous comment line', function()
      api_mock.cursor = { 20, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 10, 0 }, api_mock.cursor_set_calls[1].pos)
      assert.are.same({ 'normal! ^' }, cmd_calls)
    end)

    it('jumps to immediate previous when between comments', function()
      api_mock.cursor = { 15, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 10, 0 }, api_mock.cursor_set_calls[1].pos)
      assert.are.same({ 'normal! ^' }, cmd_calls)
    end)

    it('is silent no-op at first comment', function()
      api_mock.cursor = { 3, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, cmd_calls)
    end)

    it('is silent no-op before first comment', function()
      api_mock.cursor = { 1, 0 }
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, cmd_calls)
    end)

    it('is silent no-op with no comments', function()
      api_mock.cursor = { 10, 0 }
      manager_mock.commented_lines = {}

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('is silent no-op when active review but buffer unattached', function()
      api_mock.cursor = { 10, 0 }
      manager_mock.commented_lines = nil

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('is silent no-op when nvim_win_get_cursor fails', function()
      api_mock.cursor_fails = true
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.are.same({}, notify_calls)
    end)

    it('handles unsorted commented_lines keys deterministically', function()
      api_mock.cursor = { 15, 0 }
      manager_mock.commented_lines = { [20] = {}, [3] = {}, [10] = {} }

      navigation.prev_comment()

      assert.is_not_nil(api_mock.cursor_set_calls[1])
      assert.are.same({ 10, 0 }, api_mock.cursor_set_calls[1].pos)
    end)

    it('notifies when no active review', function()
      review_mock.active = false
      manager_mock.commented_lines = { [3] = {}, [10] = {}, [20] = {} }

      navigation.prev_comment()

      assert.are.same({}, api_mock.cursor_set_calls)
      assert.is_not_nil(notify_calls[1])
      assert.are.equal('[nit] no active review', notify_calls[1].msg)
      assert.are.equal(vim.log.levels.WARN, notify_calls[1].level)
    end)
  end)

  describe('first non-blank character', function()
    it('lands on first non-blank character after jump', function()
      api_mock.cursor = { 5, 0 }
      manager_mock.commented_lines = { [10] = {} }

      navigation.next_comment()

      assert.are.same({ 'normal! ^' }, cmd_calls)
    end)

    it('does not run normal! ^ if nvim_win_set_cursor fails', function()
      api_mock.cursor = { 5, 0 }
      manager_mock.commented_lines = { [10] = {} }
      api_mock.set_cursor_fails = true

      navigation.next_comment()

      assert.are.same({}, cmd_calls)
    end)
  end)
end)

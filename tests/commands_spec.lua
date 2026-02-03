describe('commands', function()
  before_each(function()
    vim.g.loaded_nit = nil
    package.loaded['nit'] = nil
    package.loaded['nit.commands'] = nil
    package.loaded['nit.health'] = nil
  end)

  describe('dispatch()', function()
    it('is a function', function()
      local commands = require('nit.commands')
      assert.is_function(commands.dispatch)
    end)

    it('calls healthcheck subcommand', function()
      local commands = require('nit.commands')
      local called = false
      local original_cmd = vim.cmd
      vim.cmd = function(cmd)
        if cmd == 'checkhealth nit' then
          called = true
        else
          original_cmd(cmd)
        end
      end

      commands.dispatch({ fargs = { 'healthcheck' } })

      vim.cmd = original_cmd
      assert.is_true(called)
    end)

    it('shows error for unknown subcommand', function()
      local commands = require('nit.commands')
      local notified = false
      local captured_level = nil
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match('Unknown subcommand') then
          notified = true
          captured_level = level
        end
      end

      commands.dispatch({ fargs = { 'unknown' } })

      vim.notify = original_notify
      assert.is_true(notified)
      assert.are.equal(vim.log.levels.ERROR, captured_level)
    end)

    it('shows available subcommands when no subcommand provided', function()
      local commands = require('nit.commands')
      ---@type string?
      local captured_msg = nil
      local captured_level = nil
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        captured_msg = msg
        captured_level = level
      end

      commands.dispatch({ fargs = {} })

      vim.notify = original_notify
      assert.is_not_nil(captured_msg)
      assert.is_true(captured_msg:match('Nit subcommands:') ~= nil)
      assert.is_true(captured_msg:match('healthcheck') ~= nil)
      assert.are.equal(vim.log.levels.INFO, captured_level)
    end)
  end)

  describe('complete()', function()
    it('is a function', function()
      local commands = require('nit.commands')
      assert.is_function(commands.complete)
    end)

    it('returns subcommands when completing first arg', function()
      local commands = require('nit.commands')
      local results = commands.complete('', 'Nit ', 4)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'healthcheck'))
    end)

    it('filters subcommands by prefix', function()
      local commands = require('nit.commands')
      local results = commands.complete('health', 'Nit health', 10)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'healthcheck'))
    end)

    it('returns empty table for unknown subcommand args', function()
      local commands = require('nit.commands')
      local results = commands.complete('', 'Nit healthcheck ', 17)
      assert.is_table(results)
      assert.are.equal(0, #results)
    end)

    it('handles visual range prefix in cmdline', function()
      local commands = require('nit.commands')
      local results = commands.complete('', "'<,'>Nit ", 9)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'healthcheck'))
    end)

    it('handles bang modifier in cmdline', function()
      local commands = require('nit.commands')
      local results = commands.complete('health', 'Nit! health', 11)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'healthcheck'))
    end)

    it('handles visual range with bang modifier', function()
      local commands = require('nit.commands')
      local results = commands.complete('', "'<,'>Nit! ", 10)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'healthcheck'))
    end)
  end)

  describe('command registration', function()
    it('Nit command exists after loading plugin', function()
      vim.cmd('runtime plugin/nit.lua')
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.Nit)
    end)

    it('Nit command accepts any number of args', function()
      vim.cmd('runtime plugin/nit.lua')
      local commands = vim.api.nvim_get_commands({})
      assert.are.equal('*', commands.Nit.nargs)
    end)
  end)
end)

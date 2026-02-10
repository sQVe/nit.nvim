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

    it('calls review subcommand', function()
      local commands = require('nit.commands')
      local toggled = false
      package.loaded['nit.review'] = {
        toggle = function()
          toggled = true
        end,
      }
      package.loaded['nit'] = nil

      commands.dispatch({ fargs = { 'review' } })

      package.loaded['nit.review'] = nil
      assert.is_true(toggled)
    end)

    it('passes remaining args to subcommand impl', function()
      local commands = require('nit.commands')

      package.loaded['nit.commands'] = nil
      commands = require('nit.commands')

      local called = false
      local original_cmd = vim.cmd
      vim.cmd = function(cmd)
        if cmd == 'checkhealth nit' then
          called = true
        else
          original_cmd(cmd)
        end
      end

      commands.dispatch({ fargs = { 'healthcheck', 'extra', 'args' } })

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

    it('toggles review panel when no subcommand provided', function()
      local commands = require('nit.commands')
      local toggled = false
      package.loaded['nit.review'] = {
        toggle = function()
          toggled = true
        end,
      }
      package.loaded['nit'] = nil

      commands.dispatch({ fargs = {} })

      package.loaded['nit.review'] = nil
      assert.is_true(toggled)
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

    it('filters subcommands by rev prefix', function()
      local commands = require('nit.commands')
      local results = commands.complete('rev', 'Nit rev', 7)
      assert.is_table(results)
      assert.is_true(vim.tbl_contains(results, 'review'))
      assert.is_false(vim.tbl_contains(results, 'healthcheck'))
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

describe('integration', function()
  before_each(function()
    vim.g.loaded_nit = nil
    package.loaded['nit'] = nil
    package.loaded['nit.commands'] = nil
    package.loaded['nit.health'] = nil
  end)

  describe('plugin loading', function()
    it('sets vim.g.loaded_nit after loading', function()
      vim.cmd('runtime plugin/nit.lua')
      assert.is_true(vim.g.loaded_nit)
    end)

    it(':Nit command exists after loading plugin', function()
      vim.cmd('runtime plugin/nit.lua')
      local commands = vim.api.nvim_get_commands({})
      assert.is_not_nil(commands.Nit)
    end)
  end)

  describe(':Nit healthcheck', function()
    it('runs without error', function()
      vim.cmd('runtime plugin/nit.lua')
      local original = vim.cmd
      local ok, err = pcall(function()
        vim.cmd = function(cmd)
          if cmd == 'checkhealth nit' then
            return
          end
          return original(cmd)
        end
        require('nit.commands').dispatch({ fargs = { 'healthcheck' } })
      end)
      vim.cmd = original
      assert.is_true(ok, 'healthcheck subcommand failed: ' .. tostring(err))
    end)
  end)

  describe('<Plug>(nit-healthcheck)', function()
    it('is callable', function()
      vim.cmd('runtime plugin/nit.lua')
      local called = false
      local original = vim.cmd

      local mapping = vim.fn.maparg('<Plug>(nit-healthcheck)', 'n', false, true)
      assert.is_not_nil(mapping.callback, '<Plug>(nit-healthcheck) has no callback')

      local ok, err = pcall(function()
        vim.cmd = function(cmd)
          if cmd == 'checkhealth nit' then
            called = true
            return
          end
          return original(cmd)
        end
        mapping.callback()
      end)
      vim.cmd = original

      assert.is_true(ok, '<Plug>(nit-healthcheck) callback failed: ' .. tostring(err))
      assert.is_true(called, '<Plug>(nit-healthcheck) did not trigger checkhealth')
    end)
  end)

  describe('require("nit").setup()', function()
    it('works without error', function()
      vim.cmd('runtime plugin/nit.lua')
      local ok, err = pcall(function()
        require('nit').setup({})
      end)
      assert.is_true(ok, 'setup() failed: ' .. tostring(err))
    end)

    it('accepts empty config', function()
      vim.cmd('runtime plugin/nit.lua')
      local nit = require('nit')
      ---@diagnostic disable-next-line: undefined-field
      assert.has_no.errors(function()
        nit.setup({})
      end)
    end)
  end)
end)

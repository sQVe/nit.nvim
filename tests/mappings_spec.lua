describe('mappings', function()
  before_each(function()
    vim.g.loaded_nit = nil
    package.loaded['nit'] = nil
    package.loaded['nit.commands'] = nil
    package.loaded['nit.health'] = nil
  end)

  describe('<Plug> mappings', function()
    it('<Plug>(nit-open) exists in normal mode', function()
      vim.cmd('runtime plugin/nit.lua')
      local mappings = vim.api.nvim_get_keymap('n')
      local found = vim.tbl_filter(function(m)
        return m.lhs == '<Plug>(nit-open)'
      end, mappings)
      assert.is_true(#found > 0, '<Plug>(nit-open) mapping not found')
    end)

    it('<Plug>(nit-healthcheck) exists in normal mode', function()
      vim.cmd('runtime plugin/nit.lua')
      local mappings = vim.api.nvim_get_keymap('n')
      local found = vim.tbl_filter(function(m)
        return m.lhs == '<Plug>(nit-healthcheck)'
      end, mappings)
      assert.is_true(#found > 0, '<Plug>(nit-healthcheck) mapping not found')
    end)

    it('no automatic keymaps are set', function()
      vim.cmd('runtime plugin/nit.lua')
      local mappings = vim.api.nvim_get_keymap('n')
      local nit_mappings = vim.tbl_filter(function(m)
        local is_nit = (m.desc and m.desc:lower():match('^nit')) and not m.lhs:match('^<Plug>')
        return is_nit
      end, mappings)
      assert.are.equal(0, #nit_mappings, 'Found automatic keymaps: ' .. vim.inspect(nit_mappings))
    end)
  end)
end)

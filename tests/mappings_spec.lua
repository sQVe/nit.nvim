describe('mappings', function()
  before_each(function()
    vim.g.loaded_nit = nil
    package.loaded['nit'] = nil
    package.loaded['nit.commands'] = nil
    package.loaded['nit.health'] = nil
  end)

  it('no automatic keymaps are set', function()
    vim.cmd('runtime plugin/nit.lua')
    local mappings = vim.api.nvim_get_keymap('n')
    local nit_mappings = vim.tbl_filter(function(m)
      return m.desc and m.desc:lower():match('^nit')
    end, mappings)
    assert.are.equal(0, #nit_mappings, 'Found automatic keymaps: ' .. vim.inspect(nit_mappings))
  end)
end)

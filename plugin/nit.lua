if vim.g.loaded_nit then
  return
end
vim.g.loaded_nit = true

vim.api.nvim_create_user_command('Nit', function(opts)
  require('nit.commands').dispatch(opts)
end, {
  nargs = '*',
  complete = function(...)
    return require('nit.commands').complete(...)
  end,
  desc = 'nit.nvim PR review',
})

vim.keymap.set('n', '<Plug>(nit-open)', function()
  vim.notify('nit-open: not yet implemented', vim.log.levels.WARN)
end, { desc = 'Open PR review' })

vim.keymap.set('n', '<Plug>(nit-healthcheck)', function()
  vim.cmd('checkhealth nit')
end, { desc = 'Run nit health check' })

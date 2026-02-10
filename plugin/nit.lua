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

local M = {}

---Check if gh CLI is installed
---@return boolean
function M.is_gh_installed()
  return vim.fn.executable('gh') == 1
end

---Get gh CLI version
---@return string|nil version Version string like "2.45.0", or nil if not installed or on error
function M.get_gh_version()
  if not M.is_gh_installed() then
    return nil
  end
  local output = vim.fn.system('gh --version')
  if vim.api.nvim_get_vvar('shell_error') ~= 0 then
    return nil
  end
  return output:match('gh version ([%d%.]+)')
end

---Get GitHub authentication status
---@return table|nil hosts Hosts table with authentication info, or nil if not authenticated
---@return string|nil error Error message if not authenticated
function M.get_auth_status()
  if not M.is_gh_installed() then
    return nil, 'gh CLI not installed'
  end

  local output = vim.fn.system('gh auth status --json hosts 2>&1')
  local exit_code = vim.api.nvim_get_vvar('shell_error')

  if exit_code ~= 0 then
    return nil, 'Not authenticated'
  end

  local ok, data = pcall(vim.json.decode, output)
  if not ok or not data or not data.hosts then
    return nil, 'Failed to parse auth status'
  end

  return data.hosts
end

---Run health checks for nit.nvim
function M.check()
  vim.health.start('nit.nvim')

  -- Check gh CLI installation
  if M.is_gh_installed() then
    local version = M.get_gh_version()
    vim.health.ok('gh CLI installed: ' .. (version or 'unknown version'))
  else
    vim.health.error('gh CLI not found', {
      'Install GitHub CLI: https://cli.github.com/',
      'Verify with: gh --version',
    })
    return
  end

  -- Check authentication
  local hosts, err = M.get_auth_status()
  if hosts then
    local github_hosts = hosts['github.com']
    if github_hosts and github_hosts[1] then
      local account = github_hosts[1]
      if account.state == 'success' then
        vim.health.ok('Authenticated as: ' .. (account.login or 'unknown'))
      else
        vim.health.error('Authentication failed', {
          'Run: gh auth login',
        })
      end
    else
      vim.health.warn('No GitHub.com authentication found')
    end
  else
    vim.health.error('Not authenticated with GitHub: ' .. (err or 'unknown error'), {
      'Run: gh auth login',
      'Then verify with: gh auth status',
    })
  end

  -- Check Neovim version
  if vim.fn.has('nvim-0.10') == 1 then
    vim.health.ok('Neovim version: ' .. vim.version().major .. '.' .. vim.version().minor)
  else
    vim.health.error('Neovim 0.10+ required', {
      'Upgrade Neovim: https://neovim.io/',
    })
  end
end

return M

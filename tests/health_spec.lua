describe('nit.health', function()
  local health

  before_each(function()
    package.loaded['nit.health'] = nil
    health = require('nit.health')
  end)

  describe('module', function()
    it('loads without error', function()
      assert.is_not_nil(health)
    end)

    it('has check function', function()
      assert.is_function(health.check)
    end)
  end)

  describe('is_gh_installed()', function()
    it('is a function', function()
      assert.is_function(health.is_gh_installed)
    end)

    it('returns boolean', function()
      local result = health.is_gh_installed()
      assert.is_boolean(result)
    end)
  end)

  describe('get_gh_version()', function()
    it('is a function', function()
      assert.is_function(health.get_gh_version)
    end)

    it('returns nil when gh not installed', function()
      local original = vim.fn.executable
      vim.fn.executable = function()
        return 0
      end

      local result = health.get_gh_version()
      assert.is_nil(result)

      vim.fn.executable = original
    end)

    it('returns version string when gh installed', function()
      local original_exec = vim.fn.executable
      local original_system = vim.fn.system

      vim.fn.executable = function()
        return 1
      end
      vim.fn.system = function()
        return 'gh version 2.45.0 (2024-01-15)\nhttps://github.com/cli/cli/releases/tag/v2.45.0\n'
      end

      local result = health.get_gh_version()
      assert.are.equal('2.45.0', result)

      vim.fn.executable = original_exec
      vim.fn.system = original_system
    end)
  end)

  describe('get_auth_status()', function()
    it('is a function', function()
      assert.is_function(health.get_auth_status)
    end)

    it('returns nil and error when gh not installed', function()
      local original = vim.fn.executable
      vim.fn.executable = function()
        return 0
      end

      local result, err = health.get_auth_status()
      assert.is_nil(result)
      assert.is_string(err)

      vim.fn.executable = original
    end)

    it('returns nil and error when not authenticated', function()
      local original_exec = vim.fn.executable
      local original_system = vim.fn.system
      local original_vvar = vim.api.nvim_get_vvar

      vim.fn.executable = function()
        return 1
      end
      vim.fn.system = function()
        return 'Not logged in to any GitHub hosts'
      end
      vim.api.nvim_get_vvar = function(name)
        if name == 'shell_error' then
          return 1
        end
        return original_vvar(name)
      end

      local result, err = health.get_auth_status()
      assert.is_nil(result)
      assert.is_string(err)

      vim.fn.executable = original_exec
      vim.fn.system = original_system
      vim.api.nvim_get_vvar = original_vvar
    end)

    it('returns hosts table when authenticated', function()
      local original_exec = vim.fn.executable
      local original_system = vim.fn.system
      local original_vvar = vim.api.nvim_get_vvar

      vim.fn.executable = function()
        return 1
      end
      vim.fn.system = function()
        return '{"hosts":{"github.com":[{"login":"testuser","state":"success"}]}}'
      end
      vim.api.nvim_get_vvar = function(name)
        if name == 'shell_error' then
          return 0
        end
        return original_vvar(name)
      end

      local result = health.get_auth_status()
      assert.is_table(result)
      assert.is_not_nil(result['github.com'])

      vim.fn.executable = original_exec
      vim.fn.system = original_system
      vim.api.nvim_get_vvar = original_vvar
    end)
  end)

  describe('check()', function()
    local reports
    local original

    local function mock_health()
      reports = {}
      original = {
        start = vim.health.start,
        ok = vim.health.ok,
        warn = vim.health.warn,
        error = vim.health.error,
      }
      vim.health.start = function(name)
        table.insert(reports, { type = 'start', name = name })
      end
      vim.health.ok = function(msg)
        table.insert(reports, { type = 'ok', msg = msg })
      end
      vim.health.warn = function(msg)
        table.insert(reports, { type = 'warn', msg = msg })
      end
      vim.health.error = function(msg)
        table.insert(reports, { type = 'error', msg = msg })
      end
    end

    local function restore_health()
      vim.health.start = original.start
      vim.health.ok = original.ok
      vim.health.warn = original.warn
      vim.health.error = original.error
    end

    it('calls vim.health.start', function()
      mock_health()
      health.check()
      restore_health()

      assert.is_true(#reports > 0)
      assert.are.equal('start', reports[1].type)
      assert.are.equal('nit.nvim', reports[1].name)
    end)

    it('reports multiple health checks', function()
      mock_health()
      health.check()
      restore_health()

      local non_start = vim.tbl_filter(function(r)
        return r.type ~= 'start'
      end, reports)
      assert.is_true(
        #non_start >= 3,
        'Expected at least 3 health reports (gh CLI, auth, Neovim version)'
      )
    end)

    it('reports error when account state is not success', function()
      mock_health()

      local original_exec = vim.fn.executable
      local original_system = vim.fn.system
      local original_vvar = vim.api.nvim_get_vvar
      local original_has = vim.fn.has

      vim.fn.executable = function()
        return 1
      end
      vim.fn.system = function(cmd)
        if cmd:match('auth status') then
          return '{"hosts":{"github.com":[{"login":"testuser","state":"failed"}]}}'
        end
        return 'gh version 2.45.0\n'
      end
      vim.api.nvim_get_vvar = function(name)
        if name == 'shell_error' then
          return 0
        end
        return original_vvar(name)
      end
      vim.fn.has = function()
        return 1
      end

      health.check()

      vim.fn.executable = original_exec
      vim.fn.system = original_system
      vim.api.nvim_get_vvar = original_vvar
      vim.fn.has = original_has
      restore_health()

      local auth_error = vim.tbl_filter(function(r)
        return r.type == 'error' and r.msg and r.msg:match('Authentication failed')
      end, reports)
      assert.is_true(#auth_error > 0, 'Expected auth failure error when state != success')
    end)
  end)
end)

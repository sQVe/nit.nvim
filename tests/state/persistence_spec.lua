describe('nit.state.persistence', function()
  local persistence

  local original_system
  local original_shell_error
  local original_stdpath
  local mock_remote_url = 'git@github.com:user/repo.git'
  local mock_shell_error = 0
  local test_data_dir

  before_each(function()
    package.loaded['nit.state.persistence'] = nil
    original_system = vim.fn.system
    original_shell_error = vim.v.shell_error
    original_stdpath = vim.fn.stdpath

    test_data_dir = vim.fn.tempname()
    vim.fn.mkdir(test_data_dir, 'p')

    vim.fn.system = function(cmd)
      if cmd:match('git remote get%-url origin') then
        if mock_shell_error ~= 0 then
          return ''
        end
        return mock_remote_url .. '\n'
      end
      return original_system(cmd)
    end

    rawset(vim.v, 'shell_error', mock_shell_error)

    vim.fn.stdpath = function(what)
      if what == 'data' then
        return test_data_dir
      end
      return original_stdpath(what)
    end

    persistence = require('nit.state.persistence')
  end)

  after_each(function()
    vim.fn.system = original_system
    rawset(vim.v, 'shell_error', original_shell_error)
    vim.fn.stdpath = original_stdpath

    if test_data_dir and vim.fn.isdirectory(test_data_dir) == 1 then
      vim.fn.delete(test_data_dir, 'rf')
    end
  end)

  describe('get_persistence_path', function()
    it('returns path under stdpath data with repo hash', function()
      local path = persistence.get_persistence_path()

      assert.is_string(path)
      assert.truthy(path:match(test_data_dir))
      assert.truthy(path:match('/nit/'))
      assert.truthy(path:match('%.json$'))
    end)

    it('returns different path for different repos', function()
      local path1 = persistence.get_persistence_path()

      mock_remote_url = 'git@github.com:other/project.git'
      package.loaded['nit.state.persistence'] = nil
      persistence = require('nit.state.persistence')

      local path2 = persistence.get_persistence_path()

      assert.not_equals(path1, path2)
    end)

    it('uses unknown hash when not in git repo', function()
      mock_shell_error = 1
      rawset(vim.v, 'shell_error', mock_shell_error)
      package.loaded['nit.state.persistence'] = nil
      persistence = require('nit.state.persistence')

      local path = persistence.get_persistence_path()

      assert.truthy(path:match('/nit/unknown%.json$'))
    end)
  end)

  describe('save_pending', function()
    it('creates nit directory if missing', function()
      local nit_dir = test_data_dir .. '/nit'
      assert.equals(0, vim.fn.isdirectory(nit_dir))

      persistence.save_pending({})

      assert.equals(1, vim.fn.isdirectory(nit_dir))
    end)

    it('writes JSON file with version field', function()
      persistence.save_pending({})

      local path = persistence.get_persistence_path()
      local content = table.concat(vim.fn.readfile(path), '\n')
      local decoded = vim.json.decode(content)

      assert.equals(1, decoded.version)
    end)

    it('writes pending comments to file', function()
      local pending = {
        {
          id = 1,
          path = 'src/main.lua',
          line = 10,
          side = 'RIGHT',
          body = 'Test comment',
          created_at = '2026-02-04T10:00:00Z',
        },
      }

      persistence.save_pending(pending)

      local path = persistence.get_persistence_path()
      local content = table.concat(vim.fn.readfile(path), '\n')
      local decoded = vim.json.decode(content)

      assert.equals(1, #decoded.pending)
      assert.equals(1, decoded.pending[1].id)
      assert.equals('src/main.lua', decoded.pending[1].path)
      assert.equals(10, decoded.pending[1].line)
      assert.equals('RIGHT', decoded.pending[1].side)
      assert.equals('Test comment', decoded.pending[1].body)
    end)
  end)

  describe('load_pending', function()
    it('returns empty array when file does not exist', function()
      local result = persistence.load_pending()

      assert.same({}, result)
    end)

    it('returns empty array for invalid JSON', function()
      local path = persistence.get_persistence_path()
      vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
      vim.fn.writefile({ 'not valid json {{{' }, path)

      local result = persistence.load_pending()

      assert.same({}, result)
    end)

    it('returns empty array for wrong version', function()
      local path = persistence.get_persistence_path()
      vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
      vim.fn.writefile({ vim.json.encode({ version = 999, pending = {} }) }, path)

      local result = persistence.load_pending()

      assert.same({}, result)
    end)

    it('returns pending comments from valid file', function()
      local pending = {
        {
          id = 1,
          path = 'lib/utils.lua',
          line = 25,
          side = 'LEFT',
          body = 'Another comment',
          created_at = '2026-02-04T11:00:00Z',
        },
      }

      persistence.save_pending(pending)
      local result = persistence.load_pending()

      assert.equals(1, #result)
      assert.equals(1, result[1].id)
      assert.equals('lib/utils.lua', result[1].path)
      assert.equals(25, result[1].line)
      assert.equals('LEFT', result[1].side)
      assert.equals('Another comment', result[1].body)
    end)

    it('round-trips multiple pending comments', function()
      local pending = {
        {
          id = 1,
          path = 'file1.lua',
          line = 1,
          side = 'RIGHT',
          body = 'First',
          created_at = '2026-02-04T10:00:00Z',
        },
        {
          id = 2,
          path = 'file2.lua',
          line = 2,
          side = 'LEFT',
          body = 'Second',
          created_at = '2026-02-04T10:01:00Z',
        },
        {
          id = 3,
          path = 'file3.lua',
          line = 3,
          side = 'RIGHT',
          body = 'Third',
          created_at = '2026-02-04T10:02:00Z',
        },
      }

      persistence.save_pending(pending)
      local result = persistence.load_pending()

      assert.equals(3, #result)
      assert.equals(1, result[1].id)
      assert.equals(2, result[2].id)
      assert.equals(3, result[3].id)
    end)
  end)
end)

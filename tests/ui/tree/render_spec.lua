describe('nit.ui.tree.render', function()
  local icons
  local render
  local tree_module

  before_each(function()
    package.loaded['nit.ui.icons'] = nil
    package.loaded['nit.ui.tree.render'] = nil
    package.loaded['nit.ui.tree.indent'] = nil
    package.loaded['nit.ui.tree'] = nil
    icons = require('nit.ui.icons')
  end)

  describe('icons', function()
    it('returns icon and highlight when devicons available', function()
      local ok = pcall(require, 'nvim-web-devicons')
      if ok then
        local icon, hl = icons.get_icon('test.lua')
        assert.is_string(icon)
        assert.is_string(hl)
        assert.is_true(#icon > 0)
      end
    end)

    it('returns fallback icon when devicons not available', function()
      package.loaded['nvim-web-devicons'] = nil
      package.preload['nvim-web-devicons'] = function()
        error('not found')
      end

      package.loaded['nit.ui.icons'] = nil
      local icons_no_dev = require('nit.ui.icons')

      local icon, hl = icons_no_dev.get_icon('test.lua')
      assert.equals('', icon)
      assert.equals('NitIcon', hl)

      package.preload['nvim-web-devicons'] = nil
    end)

    it('provides section header icons', function()
      assert.is_string(icons.overview)
      assert.is_string(icons.files)
      assert.is_string(icons.comment)
      assert.is_string(icons.resolved)
      assert.is_string(icons.folder_open)
      assert.is_string(icons.folder_closed)
    end)

    it('caches devicons availability check', function()
      local _, hl1 = icons.get_icon('test.lua')
      local _, hl2 = icons.get_icon('other.lua')
      assert.is_string(hl1)
      assert.is_string(hl2)
    end)
  end)

  describe('prepare_node', function()
    before_each(function()
      local ok = pcall(require, 'nui.line')
      if not ok then
        return
      end
      render = require('nit.ui.tree.render')
    end)

    it('renders overview node', function()
      if not render then
        return
      end

      local node = {
        _type = 'overview',
        text = 'PR Overview',
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
    end)

    it('renders separator as empty line', function()
      if not render then
        return
      end

      local node = {
        _type = 'separator',
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      assert.equals('', line:content())
    end)

    it('renders files_header node', function()
      if not render then
        return
      end

      local node = {
        _type = 'files_header',
        count = 5,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      local content = line:content()
      assert.truthy(content:find('Files %(5%)'))
    end)

    it('renders directory node with tree indent', function()
      if not render then
        return
      end

      local node = {
        _type = 'directory',
        directory = 'src/components',
        indent_state = { false },
        is_expanded = function()
          return true
        end,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      local content = line:content()
      assert.truthy(content:find('src/components'))
      assert.truthy(content:find('├'))
    end)

    it('renders last directory with last-child marker', function()
      if not render then
        return
      end

      local node = {
        _type = 'directory',
        directory = 'utils',
        indent_state = { true },
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      local content = line:content()
      assert.truthy(content:find('└'))
    end)

    it('renders file node with tree indent and stats', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'modified',
        additions = 10,
        deletions = 5,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      local content = line:content()
      assert.truthy(content:find('+10 %-5'))
      assert.truthy(content:find('└'))
    end)

    it('renders nested file with continuation lines', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'src/test.lua',
        display_path = 'test.lua',
        status = 'modified',
        additions = 3,
        deletions = 1,
        indent_state = { false, true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      local content = line:content()
      assert.truthy(content:find('│'))
      assert.truthy(content:find('└'))
    end)

    it('renders file node with children', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'added',
        additions = 20,
        deletions = 0,
        indent_state = { true },
        has_children = function()
          return true
        end,
        is_expanded = function()
          return true
        end,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
    end)

    it('omits zero additions in stats', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'removed',
        additions = 0,
        deletions = 5,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      local content = line:content()
      assert.truthy(content:find('%-5'))
      assert.falsy(content:find('+0'))
    end)

    it('omits zero deletions in stats', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'added',
        additions = 10,
        deletions = 0,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      local content = line:content()
      assert.truthy(content:find('+10'))
      assert.falsy(content:find('%-0'))
    end)

    it('omits stats entirely when both are zero', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'renamed',
        additions = 0,
        deletions = 0,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      local content = line:content()
      assert.falsy(content:find('+'))
      assert.falsy(content:find('%-'))
    end)

    it('renders unresolved comment node with tree indent', function()
      if not render then
        return
      end

      local node = {
        _type = 'comment',
        thread_id = 'PRRT_123',
        author = 'testuser',
        is_resolved = false,
        line = 42,
        indent_state = { true, true },
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      local content = line:content()
      assert.truthy(content:find('testuser'))
    end)

    it('renders resolved comment node with tree indent', function()
      if not render then
        return
      end

      local node = {
        _type = 'comment',
        thread_id = 'PRRT_456',
        author = 'reviewer',
        is_resolved = true,
        line = 100,
        indent_state = { false, true, true },
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
      local content = line:content()
      assert.truthy(content:find('reviewer'))
    end)

    it('renders file node with renamed status', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'old_name.lua',
        display_path = 'old_name.lua',
        status = 'renamed',
        additions = 0,
        deletions = 0,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
    end)

    it('falls back to NitFileModified for unknown status', function()
      if not render then
        return
      end

      local node = {
        _type = 'file',
        path = 'test.lua',
        display_path = 'test.lua',
        status = 'unknown_status',
        additions = 1,
        deletions = 1,
        indent_state = { true },
        has_children = function()
          return false
        end,
        is_expanded = function()
          return false
        end,
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
    end)

    it('returns empty line for unknown node type', function()
      if not render then
        return
      end

      local node = {
        _type = 'unknown',
      }

      local line = render.prepare_node(node, 40)
      assert.is_not_nil(line)
    end)
  end)

  describe('tree lifecycle', function()
    before_each(function()
      local ok = pcall(require, 'nui.tree')
      if not ok then
        return
      end
      tree_module = require('nit.ui.tree')
    end)

    it('creates tree with buffer', function()
      if not tree_module then
        return
      end

      local bufnr = vim.api.nvim_create_buf(false, true)
      tree_module.create(bufnr)
      tree_module.destroy()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('updates tree with files and threads', function()
      if not tree_module then
        return
      end

      local bufnr = vim.api.nvim_create_buf(false, true)
      tree_module.create(bufnr)

      local files = {
        { filename = 'test.lua', status = 'modified', additions = 10, deletions = 5 },
        { filename = 'other.lua', status = 'added', additions = 20, deletions = 0 },
      }

      local threads = {}

      tree_module.update(files, threads)
      tree_module.destroy()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('returns nil for get_node_at_cursor when tree not created', function()
      if not tree_module then
        return
      end

      local node = tree_module.get_node_at_cursor()
      assert.is_nil(node)
    end)
  end)
end)

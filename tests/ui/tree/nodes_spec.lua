local has_nui, _ = pcall(require, 'nui.tree')

describe('nit.ui.tree.nodes', function()
  if not has_nui then
    it('skipped: nui.nvim not available', function() end)
    return
  end

  local NuiTree = require('nui.tree')
  local nodes

  ---Create a NUI Tree from nodes so we can query the hierarchy
  ---@param tree_nodes any[]
  ---@return any tree, number bufnr
  local function mount_tree(tree_nodes)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local tree = NuiTree({
      bufnr = bufnr,
      nodes = tree_nodes,
    })
    return tree, bufnr
  end

  before_each(function()
    package.loaded['nit.ui.tree.nodes'] = nil
    nodes = require('nit.ui.tree.nodes')
  end)

  describe('create_comment_node', function()
    it('extracts author from first comment', function()
      local thread = {
        id = 'PRRT_1',
        comments = { { author = { login = 'octocat' } } },
        isResolved = false,
        line = 10,
      }

      local node = nodes.create_comment_node(thread, { true })
      assert.equals('octocat', node.author)
    end)

    it('falls back to unknown when comments are empty', function()
      local thread = {
        id = 'PRRT_2',
        comments = {},
        isResolved = false,
        line = nil,
      }

      local node = nodes.create_comment_node(thread, { true })
      assert.equals('unknown', node.author)
    end)

    it('falls back to unknown when first comment has no author', function()
      local thread = {
        id = 'PRRT_3',
        comments = { { body = 'text' } },
        isResolved = true,
        line = 5,
      }

      local node = nodes.create_comment_node(thread, { true })
      assert.equals('unknown', node.author)
    end)

    it('falls back to unknown when author has no login', function()
      local thread = {
        id = 'PRRT_4',
        comments = { { author = { name = 'Test' } } },
        isResolved = false,
        line = 1,
      }

      local node = nodes.create_comment_node(thread, { true })
      assert.equals('unknown', node.author)
    end)

    it('sets node fields from thread', function()
      local thread = {
        id = 'PRRT_42',
        comments = { { author = { login = 'reviewer' } } },
        isResolved = true,
        line = 99,
      }

      local node = nodes.create_comment_node(thread, { false, true })
      assert.equals('comment:PRRT_42', node.id)
      assert.equals('comment', node._type)
      assert.equals('PRRT_42', node.thread_id)
      assert.is_true(node.is_resolved)
      assert.equals(99, node.line)
      assert.same({ false, true }, node.indent_state)
    end)
  end)

  describe('build_tree_data', function()
    it('returns overview, separator, and files_header when files are empty', function()
      local result = nodes.build_tree_data({}, {})
      assert.equals(3, #result)
      assert.equals('overview', result[1]._type)
      assert.equals('separator', result[2]._type)
      assert.equals('files_header', result[3]._type)
      assert.equals(0, result[3].count)
    end)

    it('creates files_header with correct count', function()
      local files = {
        { filename = 'a.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'b.lua', status = 'modified', additions = 2, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      assert.equals('files_header', result[3]._type)
      assert.equals(2, result[3].count)
    end)

    it('nests files under directory nodes as children of files_header', function()
      local files = {
        { filename = 'src/a.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'src/b.lua', status = 'modified', additions = 2, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      assert.equals(3, #result)
      local files_header = result[3]
      assert.equals('files_header', files_header._type)
      assert.is_true(files_header:has_children())

      local header_children = files_header:get_child_ids()
      assert.equals(1, #header_children)

      local dir_node = tree:get_node(header_children[1])
      assert.equals('directory', dir_node._type)
      assert.equals('src', dir_node.directory)
      assert.is_true(dir_node:has_children())

      local dir_children = dir_node:get_child_ids()
      assert.equals(2, #dir_children)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('assigns indent_state to files under a directory', function()
      local files = {
        { filename = 'src/a.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local dir_node = tree:get_node(files_header:get_child_ids()[1])
      assert.same({ true }, dir_node.indent_state)

      local file_node = tree:get_node(dir_node:get_child_ids()[1])
      assert.same({ true, true }, file_node.indent_state)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('assigns indent_state to root files', function()
      local files = {
        { filename = 'root.lua', status = 'modified', additions = 2, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local file_node = tree:get_node(files_header:get_child_ids()[1])
      assert.equals('file', file_node._type)
      assert.same({ true }, file_node.indent_state)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('places directories before root files', function()
      local files = {
        { filename = 'src/nested.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'root.lua', status = 'modified', additions = 2, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()
      assert.equals(2, #children)

      local first_child = tree:get_node(children[1])
      assert.equals('directory', first_child._type)
      assert.equals('src', first_child.directory)

      local second_child = tree:get_node(children[2])
      assert.equals('file', second_child._type)
      assert.equals('root.lua', second_child.display_path)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('sorts directory groups alphabetically', function()
      local files = {
        { filename = 'z/file.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'a/file.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'm/file.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()
      assert.equals(3, #children)

      local first = tree:get_node(children[1])
      assert.equals('a', first.directory)
      local second = tree:get_node(children[2])
      assert.equals('m', second.directory)
      local third = tree:get_node(children[3])
      assert.equals('z', third.directory)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('sorts files alphabetically within a directory group', function()
      local files = {
        { filename = 'src/z.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'src/a.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local dir_node = tree:get_node(files_header:get_child_ids()[1])
      local file_ids = dir_node:get_child_ids()

      local first_file = tree:get_node(file_ids[1])
      assert.equals('src/a.lua', first_file.path)
      local second_file = tree:get_node(file_ids[2])
      assert.equals('src/z.lua', second_file.path)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('uses basename as display_path', function()
      local files = {
        { filename = 'src/core/utils.lua', status = 'modified', additions = 3, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local dir_node = tree:get_node(files_header:get_child_ids()[1])
      local file_node = tree:get_node(dir_node:get_child_ids()[1])
      assert.equals('utils.lua', file_node.display_path)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('attaches comment children to files with matching threads', function()
      local files = {
        { filename = 'app.lua', status = 'modified', additions = 10, deletions = 2 },
      }
      local threads = {
        {
          id = 'PRRT_1',
          path = 'app.lua',
          comments = { { author = { login = 'user1' } } },
          isResolved = false,
          line = 5,
        },
      }

      local result = nodes.build_tree_data(files, threads)
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local file_node = tree:get_node(files_header:get_child_ids()[1])
      assert.equals('file', file_node._type)
      assert.is_true(file_node:has_children())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('ignores threads with nil path', function()
      local files = {
        { filename = 'init.lua', status = 'added', additions = 20, deletions = 0 },
      }
      local threads = {
        {
          id = 'PRRT_10',
          path = nil,
          comments = { { author = { login = 'bot' } } },
          isResolved = false,
          line = nil,
        },
      }

      local result = nodes.build_tree_data(files, threads)
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local file_node = tree:get_node(files_header:get_child_ids()[1])
      assert.is_false(file_node:has_children())

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('assigns correct indent_state for mixed directories and root files', function()
      local files = {
        { filename = 'src/a.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'lib/b.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'root.lua', status = 'modified', additions = 2, deletions = 1 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()

      local lib_dir = tree:get_node(children[1])
      assert.same({ false }, lib_dir.indent_state)

      local src_dir = tree:get_node(children[2])
      assert.same({ false }, src_dir.indent_state)

      local root_file = tree:get_node(children[3])
      assert.same({ true }, root_file.indent_state)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('assigns comment indent_state extending parent file', function()
      local files = {
        { filename = 'src/app.lua', status = 'modified', additions = 5, deletions = 2 },
      }
      local threads = {
        {
          id = 'PRRT_1',
          path = 'src/app.lua',
          comments = { { author = { login = 'alice' } } },
          isResolved = false,
          line = 10,
        },
        {
          id = 'PRRT_2',
          path = 'src/app.lua',
          comments = { { author = { login = 'bob' } } },
          isResolved = true,
          line = 20,
        },
      }

      local result = nodes.build_tree_data(files, threads)
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local dir_node = tree:get_node(files_header:get_child_ids()[1])
      local file_node = tree:get_node(dir_node:get_child_ids()[1])
      local comment_ids = file_node:get_child_ids()

      local first_comment = tree:get_node(comment_ids[1])
      assert.same({ true, true, false }, first_comment.indent_state)

      local last_comment = tree:get_node(comment_ids[2])
      assert.same({ true, true, true }, last_comment.indent_state)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('compresses single-child directory chains', function()
      local files = {
        { filename = 'a/b/c/file.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()
      assert.equals(1, #children)

      local dir_node = tree:get_node(children[1])
      assert.equals('directory', dir_node._type)
      assert.equals('a/b/c', dir_node.directory)

      local dir_children = dir_node:get_child_ids()
      assert.equals(1, #dir_children)

      local file_node = tree:get_node(dir_children[1])
      assert.equals('file', file_node._type)
      assert.equals('file.lua', file_node.display_path)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('stops compression at directory with multiple children', function()
      local files = {
        { filename = 'a/b/x.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'a/c/y.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()
      assert.equals(1, #children)

      local a_dir = tree:get_node(children[1])
      assert.equals('directory', a_dir._type)
      assert.equals('a', a_dir.directory)

      local a_children = a_dir:get_child_ids()
      assert.equals(2, #a_children)

      local b_dir = tree:get_node(a_children[1])
      assert.equals('directory', b_dir._type)
      assert.equals('b', b_dir.directory)

      local c_dir = tree:get_node(a_children[2])
      assert.equals('directory', c_dir._type)
      assert.equals('c', c_dir.directory)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('stops compression when directory has files', function()
      local files = {
        { filename = 'a/root.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'a/b/nested.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local children = files_header:get_child_ids()
      assert.equals(1, #children)

      local a_dir = tree:get_node(children[1])
      assert.equals('directory', a_dir._type)
      assert.equals('a', a_dir.directory)

      local a_children = a_dir:get_child_ids()
      assert.equals(2, #a_children)

      local b_dir = tree:get_node(a_children[1])
      assert.equals('directory', b_dir._type)
      assert.equals('b', b_dir.directory)

      local root_file = tree:get_node(a_children[2])
      assert.equals('file', root_file._type)
      assert.equals('root.lua', root_file.display_path)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it('assigns correct indent_state for deeply nested directories', function()
      local files = {
        { filename = 'a/b/file1.lua', status = 'added', additions = 1, deletions = 0 },
        { filename = 'a/c/file2.lua', status = 'added', additions = 1, deletions = 0 },
      }

      local result = nodes.build_tree_data(files, {})
      local tree, bufnr = mount_tree(result)

      local files_header = result[3]
      local a_dir = tree:get_node(files_header:get_child_ids()[1])
      assert.same({ true }, a_dir.indent_state)

      local a_children = a_dir:get_child_ids()
      local b_dir = tree:get_node(a_children[1])
      assert.same({ true, false }, b_dir.indent_state)

      local c_dir = tree:get_node(a_children[2])
      assert.same({ true, true }, c_dir.indent_state)

      local file1 = tree:get_node(b_dir:get_child_ids()[1])
      assert.same({ true, false, true }, file1.indent_state)

      local file2 = tree:get_node(c_dir:get_child_ids()[1])
      assert.same({ true, true, true }, file2.indent_state)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)

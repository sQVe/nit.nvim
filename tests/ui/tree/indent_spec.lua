describe('nit.ui.tree.indent', function()
  local indent

  before_each(function()
    package.loaded['nit.ui.tree.indent'] = nil
    indent = require('nit.ui.tree.indent')
  end)

  describe('build', function()
    it('returns empty string for nil indent_state', function()
      assert.equals('', indent.build(nil))
    end)

    it('returns empty string for empty indent_state', function()
      assert.equals('', indent.build({}))
    end)

    it('returns branch marker for single non-last item', function()
      local result = indent.build({ false })
      assert.equals('├ ', result)
    end)

    it('returns last marker for single last item', function()
      local result = indent.build({ true })
      assert.equals('└ ', result)
    end)

    it('renders edge continuation for non-last ancestor', function()
      local result = indent.build({ false, true })
      assert.equals('│ └ ', result)
    end)

    it('renders space for last ancestor', function()
      local result = indent.build({ true, false })
      assert.equals('  ├ ', result)
    end)

    it('renders deep nesting correctly', function()
      local result = indent.build({ false, false, true })
      assert.equals('│ │ └ ', result)
    end)

    it('renders all-last path correctly', function()
      local result = indent.build({ true, true, true })
      assert.equals('    └ ', result)
    end)

    it('renders mixed ancestry correctly', function()
      local result = indent.build({ false, true, false })
      assert.equals('│   ├ ', result)
    end)
  end)
end)

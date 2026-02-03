local nit = require('nit')

describe('nit', function()
  before_each(function()
    nit.config = {}
  end)

  describe('setup()', function()
    it('is a function', function()
      assert.is_function(nit.setup)
    end)

    it('accepts empty config', function()
      assert.has_no.errors(function()
        nit.setup({})
      end)
    end)

    it('accepts config options', function()
      nit.setup({ debug = true })
      assert.are.equal(true, nit.config.debug)
    end)
  end)

  describe('module', function()
    it('loads without error', function()
      assert.is_not_nil(nit)
    end)

    it('has config table', function()
      assert.is_table(nit.config)
    end)
  end)
end)

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
      ---@diagnostic disable-next-line: undefined-field
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

    it('exposes start function', function()
      assert.is_function(nit.start)
    end)

    it('exposes stop function', function()
      assert.is_function(nit.stop)
    end)

    it('exposes menu function', function()
      assert.is_function(nit.menu)
    end)

    it('exposes next_comment function', function()
      assert.is_function(nit.next_comment)
    end)

    it('exposes prev_comment function', function()
      assert.is_function(nit.prev_comment)
    end)
  end)

  describe('next_comment()', function()
    it('delegates to navigation.next_comment', function()
      local called = false
      package.loaded['nit.navigation'] = {
        next_comment = function()
          called = true
        end,
        prev_comment = function() end,
      }
      package.loaded['nit'] = nil
      local fresh_nit = require('nit')
      fresh_nit.next_comment()
      package.loaded['nit.navigation'] = nil
      assert.is_true(called)
    end)
  end)

  describe('prev_comment()', function()
    it('delegates to navigation.prev_comment', function()
      local called = false
      package.loaded['nit.navigation'] = {
        next_comment = function() end,
        prev_comment = function()
          called = true
        end,
      }
      package.loaded['nit'] = nil
      local fresh_nit = require('nit')
      fresh_nit.prev_comment()
      package.loaded['nit.navigation'] = nil
      assert.is_true(called)
    end)
  end)

  describe('menu()', function()
    it('delegates to thread_panel.open_menu', function()
      local called = false
      package.loaded['nit.display.thread_panel'] = {
        open_menu = function()
          called = true
        end,
        close = function() end,
      }
      package.loaded['nit'] = nil
      local fresh_nit = require('nit')
      fresh_nit.menu()
      package.loaded['nit.display.thread_panel'] = nil
      assert.is_true(called)
    end)
  end)
end)

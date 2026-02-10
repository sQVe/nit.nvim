describe('review session', function()
  local review
  local controller_mock = {
    load_called = false,
    cleanup_called = false,
    refresh_called = false,
  }

  local sidebar_mock = {
    is_open_value = false,
    open_called = false,
    close_called = false,
    captured_opts = nil,
  }

  before_each(function()
    controller_mock.load_called = false
    controller_mock.cleanup_called = false
    controller_mock.refresh_called = false
    sidebar_mock.is_open_value = false
    sidebar_mock.open_called = false
    sidebar_mock.close_called = false
    sidebar_mock.captured_opts = nil

    package.loaded['nit.controller'] = {
      load = function()
        controller_mock.load_called = true
      end,
      cleanup = function()
        controller_mock.cleanup_called = true
      end,
      refresh = function()
        controller_mock.refresh_called = true
      end,
    }

    package.loaded['nit.ui.sidebar'] = {
      is_open = function()
        return sidebar_mock.is_open_value
      end,
      open = function(opts)
        sidebar_mock.open_called = true
        sidebar_mock.captured_opts = opts
        sidebar_mock.is_open_value = true
      end,
      close = function()
        sidebar_mock.close_called = true
        sidebar_mock.is_open_value = false
      end,
    }

    package.loaded['nit.review'] = nil
    review = require('nit.review')
  end)

  after_each(function()
    package.loaded['nit.controller'] = nil
    package.loaded['nit.ui.sidebar'] = nil
    package.loaded['nit.review'] = nil
  end)

  describe('start', function()
    it('calls controller.load and sidebar.open', function()
      review.start()

      assert.is_true(controller_mock.load_called, 'Expected controller.load to be called')
      assert.is_true(sidebar_mock.open_called, 'Expected sidebar.open to be called')
    end)

    it('passes on_refresh callback that calls controller.refresh', function()
      review.start()

      assert.is_not_nil(sidebar_mock.captured_opts, 'Expected opts to be captured')
      assert.is_not_nil(sidebar_mock.captured_opts.on_refresh, 'Expected on_refresh callback')

      sidebar_mock.captured_opts.on_refresh()

      assert.is_true(controller_mock.refresh_called, 'Expected controller.refresh to be called')
    end)

    it('passes on_close callback that calls controller.cleanup', function()
      review.start()

      assert.is_not_nil(sidebar_mock.captured_opts, 'Expected opts to be captured')
      assert.is_not_nil(sidebar_mock.captured_opts.on_close, 'Expected on_close callback')

      sidebar_mock.captured_opts.on_close()

      assert.is_true(controller_mock.cleanup_called, 'Expected controller.cleanup to be called')
    end)

    it('is no-op when already open', function()
      sidebar_mock.is_open_value = true

      review.start()

      assert.is_false(controller_mock.load_called, 'Expected controller.load not to be called')
      assert.is_false(sidebar_mock.open_called, 'Expected sidebar.open not to be called')
    end)
  end)

  describe('stop', function()
    it('calls sidebar.close', function()
      sidebar_mock.is_open_value = true

      review.stop()

      assert.is_true(sidebar_mock.close_called, 'Expected sidebar.close to be called')
    end)

    it('is no-op when already closed', function()
      sidebar_mock.is_open_value = false

      review.stop()

      assert.is_false(sidebar_mock.close_called, 'Expected sidebar.close not to be called')
    end)
  end)

  describe('toggle', function()
    it('calls start when closed', function()
      sidebar_mock.is_open_value = false

      review.toggle()

      assert.is_true(controller_mock.load_called, 'Expected controller.load to be called')
      assert.is_true(sidebar_mock.open_called, 'Expected sidebar.open to be called')
    end)

    it('calls stop when open', function()
      sidebar_mock.is_open_value = true

      review.toggle()

      assert.is_true(sidebar_mock.close_called, 'Expected sidebar.close to be called')
    end)
  end)
end)

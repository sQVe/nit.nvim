describe('review session', function()
  local review
  local controller_mock = {
    load_called = false,
    cleanup_called = false,
  }

  local display_manager_mock = {
    setup_called = false,
    detach_all_called = false,
  }

  local comment_popup_mock = {
    close_called = false,
  }

  before_each(function()
    controller_mock.load_called = false
    controller_mock.cleanup_called = false
    display_manager_mock.setup_called = false
    display_manager_mock.detach_all_called = false
    comment_popup_mock.close_called = false

    package.loaded['nit.controller'] = {
      load = function()
        controller_mock.load_called = true
      end,
      cleanup = function()
        controller_mock.cleanup_called = true
      end,
    }

    package.loaded['nit.display.manager'] = {
      setup = function()
        display_manager_mock.setup_called = true
      end,
      detach_all = function()
        display_manager_mock.detach_all_called = true
      end,
    }

    package.loaded['nit.display.comment_popup'] = {
      close = function()
        comment_popup_mock.close_called = true
      end,
    }

    package.loaded['nit.review'] = nil
    review = require('nit.review')
  end)

  after_each(function()
    package.loaded['nit.controller'] = nil
    package.loaded['nit.display.manager'] = nil
    package.loaded['nit.display.comment_popup'] = nil
    package.loaded['nit.review'] = nil
  end)

  describe('start', function()
    it('sets up display manager and loads data', function()
      review.start()

      assert.is_true(display_manager_mock.setup_called, 'Expected display_manager.setup to be called')
      assert.is_true(controller_mock.load_called, 'Expected controller.load to be called')
    end)

    it('is no-op when already active', function()
      review.start()
      controller_mock.load_called = false
      display_manager_mock.setup_called = false

      review.start()

      assert.is_false(controller_mock.load_called, 'Expected controller.load not to be called')
      assert.is_false(display_manager_mock.setup_called, 'Expected display_manager.setup not to be called')
    end)

    it('reports active after start', function()
      assert.is_false(review.is_active())
      review.start()
      assert.is_true(review.is_active())
    end)
  end)

  describe('stop', function()
    it('detaches display and cleans up controller', function()
      review.start()

      review.stop()

      assert.is_true(display_manager_mock.detach_all_called, 'Expected display_manager.detach_all to be called')
      assert.is_true(comment_popup_mock.close_called, 'Expected comment_popup.close to be called')
      assert.is_true(controller_mock.cleanup_called, 'Expected controller.cleanup to be called')
    end)

    it('is no-op when not active', function()
      review.stop()

      assert.is_false(display_manager_mock.detach_all_called, 'Expected display_manager.detach_all not to be called')
      assert.is_false(controller_mock.cleanup_called, 'Expected controller.cleanup not to be called')
    end)

    it('reports inactive after stop', function()
      review.start()
      review.stop()
      assert.is_false(review.is_active())
    end)
  end)
end)

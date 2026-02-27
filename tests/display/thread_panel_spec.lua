local assert = require('luassert')
local thread_panel = require('nit.display.thread_panel')
local data = require('nit.state.data')

describe('thread_panel', function()
  describe('format_relative_time', function()
    local orig_time

    before_each(function()
      orig_time = os.time
    end)

    after_each(function()
      -- selene: allow(incorrect_standard_library_use)
      os.time = orig_time
    end)

    it(
      'shows just now for a UTC timestamp equal to current time in a UTC+1 timezone (regression nit.nvim-231)',
      function()
        local real_now = orig_time()
        local utc_timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ', real_now)

        -- selene: allow(incorrect_standard_library_use)
        os.time = function(t)
          if t == nil then
            return real_now
          end
          return orig_time(t) - 3600
        end

        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'Hello',
              createdAt = utc_timestamp,
            },
          },
        }

        local lines = thread_panel.format_thread(thread)
        local combined = table.concat(lines, '\n')

        assert.matches('just now', combined, 1, true)
      end
    )
  end)

  describe('format_thread', function()
    it('formats single comment with @ prefix in header', function()
      local thread = {
        comments = {
          {
            author = { login = 'testuser' },
            body = 'Test body',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local lines, author_indices = thread_panel.format_thread(thread)

      assert.is_table(lines)
      assert.is_true(#lines > 0)

      local combined = table.concat(lines, '\n')
      assert.matches(' @testuser', combined, 1, true)
      assert.matches('·', combined, 1, true)
      assert.matches('Test body', combined, 1, true)

      assert.is_true(author_indices[1])
    end)

    it('separates multiple comments with blank lines', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = 'First comment',
            createdAt = '2026-01-01T12:00:00Z',
          },
          {
            author = { login = 'bob' },
            body = 'Second comment',
            createdAt = '2026-01-02T12:00:00Z',
          },
          {
            author = { login = 'charlie' },
            body = 'Third comment',
            createdAt = '2026-01-03T12:00:00Z',
          },
        },
      }

      local lines = thread_panel.format_thread(thread)

      local combined = table.concat(lines, '\n')
      assert.matches(' @alice', combined, 1, true)
      assert.matches(' @bob', combined, 1, true)
      assert.matches(' @charlie', combined, 1, true)

      local blank_count = 0
      for _, line in ipairs(lines) do
        if line == '' then
          blank_count = blank_count + 1
        end
      end
      assert.is_true(blank_count >= 2)
    end)

    it('splits multi-line body correctly', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = 'Line 1\nLine 2\nLine 3',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local lines = thread_panel.format_thread(thread)

      local combined = table.concat(lines, '\n')
      assert.matches('Line 1', combined, 1, true)
      assert.matches('Line 2', combined, 1, true)
      assert.matches('Line 3', combined, 1, true)
    end)

    it('handles empty body', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = '',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local lines = thread_panel.format_thread(thread)

      assert.is_table(lines)
      local combined = table.concat(lines, '\n')
      assert.matches(' @alice', combined, 1, true)
    end)

    describe('viewer header alignment', function()
      after_each(function()
        data.clear()
      end)

      it('right-aligns header when comment author matches viewer login', function()
        data.set_viewer_login('me')
        local thread = {
          comments = {
            {
              author = { login = 'me' },
              body = 'My comment',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
        }

        local lines, author_indices = thread_panel.format_thread(thread)

        assert.is_true(author_indices[1])
        assert.are.equal(60, vim.fn.strdisplaywidth(lines[1]))
        assert.is_true(
          #lines[1] - #vim.trim(lines[1]) > 1,
          'viewer header should have many leading spaces'
        )
        assert.are.equal('@', vim.trim(lines[1]):sub(1, 1))
      end)

      it('left-aligns header when comment author does not match viewer login', function()
        data.set_viewer_login('me')
        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'Their comment',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
        }

        local lines, _ = thread_panel.format_thread(thread)

        assert.are.equal(' ', lines[1]:sub(1, 1))
        assert.are.equal('@', lines[1]:sub(2, 2))
      end)

      it('left-aligns all headers when viewer login is nil', function()
        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'Comment',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
        }

        local lines, _ = thread_panel.format_thread(thread)

        assert.are.equal(' ', lines[1]:sub(1, 1))
        assert.are.equal('@', lines[1]:sub(2, 2))
      end)
    end)

    it('does not produce separator lines between comments', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = 'First',
            createdAt = '2026-01-01T12:00:00Z',
          },
          {
            author = { login = 'bob' },
            body = 'Second',
            createdAt = '2026-01-02T12:00:00Z',
          },
        },
      }

      local lines = thread_panel.format_thread(thread)

      for _, line in ipairs(lines) do
        assert.is_nil(line:find('─'))
      end
    end)

    describe('ranges', function()
      it('returns empty ranges for zero comments', function()
        local thread = { comments = {} }

        local _, _, ranges = thread_panel.format_thread(thread)

        assert.are.same({}, ranges)
      end)

      it('returns correct start and end line for single comment', function()
        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'Test body',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
        }

        local _, _, ranges = thread_panel.format_thread(thread)

        assert.are.equal(1, #ranges)
        assert.are.equal(1, ranges[1].start_line)
        assert.are.equal(3, ranges[1].end_line)
        assert.are.equal(1, ranges[1].comment_index)
      end)

      it('places separator line in gap between two comment ranges', function()
        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'First',
              createdAt = '2026-01-01T12:00:00Z',
            },
            {
              author = { login = 'bob' },
              body = 'Second',
              createdAt = '2026-01-02T12:00:00Z',
            },
          },
        }

        local _, _, ranges = thread_panel.format_thread(thread)

        assert.are.equal(2, #ranges)
        assert.are.equal(1, ranges[1].start_line)
        assert.are.equal(3, ranges[1].end_line)
        assert.are.equal(5, ranges[2].start_line)
        assert.are.equal(7, ranges[2].end_line)
        assert.is_true(
          ranges[1].end_line < ranges[2].start_line - 1,
          'separator line must be outside all ranges'
        )
      end)

      it('covers all lines of a multiline body', function()
        local thread = {
          comments = {
            {
              author = { login = 'alice' },
              body = 'Line 1\nLine 2\nLine 3',
              createdAt = '2026-01-01T12:00:00Z',
            },
          },
        }

        local _, _, ranges = thread_panel.format_thread(thread)

        assert.are.equal(1, #ranges)
        assert.are.equal(1, ranges[1].start_line)
        assert.are.equal(5, ranges[1].end_line)
      end)

      it('sets correct comment_index for three comments', function()
        local thread = {
          comments = {
            { author = { login = 'alice' }, body = 'A', createdAt = '2026-01-01T12:00:00Z' },
            { author = { login = 'bob' }, body = 'B', createdAt = '2026-01-02T12:00:00Z' },
            { author = { login = 'carol' }, body = 'C', createdAt = '2026-01-03T12:00:00Z' },
          },
        }

        local _, _, ranges = thread_panel.format_thread(thread)

        assert.are.equal(3, #ranges)
        assert.are.equal(1, ranges[1].comment_index)
        assert.are.equal(2, ranges[2].comment_index)
        assert.are.equal(3, ranges[3].comment_index)
      end)
    end)
  end)

  describe('format_title', function()
    it('returns " Thread" for unresolved single comment', function()
      local thread = {
        isResolved = false,
        comments = {
          {
            author = { login = 'alice' },
            body = 'test',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local title = thread_panel.format_title(thread)

      assert.are.equal(' Thread', title)
    end)

    it('returns " Thread · Resolved" for resolved single comment', function()
      local thread = {
        isResolved = true,
        comments = {
          {
            author = { login = 'alice' },
            body = 'test',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local title = thread_panel.format_title(thread)

      assert.are.equal(' Thread · Resolved', title)
    end)

    it('returns " Thread (1 reply)" for unresolved 2-comment thread', function()
      local thread = {
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'test', createdAt = '2026-01-01T12:00:00Z' },
          { author = { login = 'bob' }, body = 'test', createdAt = '2026-01-02T12:00:00Z' },
        },
      }

      local title = thread_panel.format_title(thread)

      assert.are.equal(' Thread (1 reply)', title)
    end)

    it('returns " Thread (2 replies)" for unresolved 3-comment thread', function()
      local thread = {
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'test', createdAt = '2026-01-01T12:00:00Z' },
          { author = { login = 'bob' }, body = 'test', createdAt = '2026-01-02T12:00:00Z' },
          { author = { login = 'charlie' }, body = 'test', createdAt = '2026-01-03T12:00:00Z' },
        },
      }

      local title = thread_panel.format_title(thread)

      assert.are.equal(' Thread (2 replies)', title)
    end)

    it('returns " Thread · Resolved (2 replies)" for resolved multi-comment thread', function()
      local thread = {
        isResolved = true,
        comments = {
          { author = { login = 'alice' }, body = 'test', createdAt = '2026-01-01T12:00:00Z' },
          { author = { login = 'bob' }, body = 'test', createdAt = '2026-01-02T12:00:00Z' },
          { author = { login = 'charlie' }, body = 'test', createdAt = '2026-01-03T12:00:00Z' },
        },
      }

      local title = thread_panel.format_title(thread)

      assert.are.equal(' Thread · Resolved (2 replies)', title)
    end)
  end)

  describe('register_hints', function()
    before_each(function()
      thread_panel.clear_hints()
    end)

    it('appends additional hints to registry', function()
      thread_panel.register_hints({
        { key = 'q', label = 'Close' },
      })

      thread_panel.register_hints({
        { key = 'r', label = 'Reply' },
        { key = 't', label = 'Resolve' },
      })

      local hints = thread_panel.get_hints()

      assert.are.equal(3, #hints)
      assert.are.equal('q', hints[1].key)
      assert.are.equal('r', hints[2].key)
      assert.are.equal('t', hints[3].key)
    end)
  end)

  describe('clear_hints', function()
    it('resets hint registry correctly', function()
      thread_panel.clear_hints()
      thread_panel.register_hints({
        { key = 'q', label = 'Close' },
      })

      assert.are.equal(1, #thread_panel.get_hints())

      thread_panel.clear_hints()

      assert.are.equal(0, #thread_panel.get_hints())

      thread_panel.register_hints({
        { key = 'x', label = 'New' },
      })

      local hints = thread_panel.get_hints()
      assert.are.equal(1, #hints)
      assert.are.equal('x', hints[1].key)
    end)
  end)

  describe('build_winbar', function()
    local thread

    before_each(function()
      thread_panel.clear_hints()
      thread_panel.register_hints({
        { key = 'q', label = 'Close' },
        { key = '?', label = 'Help' },
      })
      thread = {
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'test', createdAt = '2026-01-01T12:00:00Z' },
        },
      }
    end)

    it('contains the thread title', function()
      local winbar = thread_panel.build_winbar(thread)

      assert.is_string(winbar)
      assert.matches('Thread', winbar, 1, true)
    end)

    it('shows ? Help indicator', function()
      local winbar = thread_panel.build_winbar(thread)

      assert.matches('?', winbar, 1, true)
      assert.matches('Help', winbar, 1, true)
    end)

    it('does not show q or Esc hints inline', function()
      local winbar = thread_panel.build_winbar(thread)

      assert.not_matches(' q ', winbar, 1, true)
      assert.not_matches('Esc', winbar, 1, true)
    end)
  end)

  describe('get_hints', function()
    before_each(function()
      thread_panel.clear_hints()
    end)

    it('returns registered hints', function()
      thread_panel.register_hints({ { key = 'q', label = 'Close' } })

      local hints = thread_panel.get_hints()

      assert.is_table(hints)
      assert.are.equal(1, #hints)
      assert.are.equal('q', hints[1].key)
      assert.are.equal('Close', hints[1].label)
    end)

    it('default hints include ? Help entry', function()
      package.loaded['nit.display.thread_panel'] = nil
      local tp = require('nit.display.thread_panel')

      local hints = tp.get_hints()

      local has_help = false
      for _, hint in ipairs(hints) do
        if hint.key == '?' and hint.label == 'Help' then
          has_help = true
        end
      end
      assert.is_true(has_help)
    end)

    it('default hints include C-s Submit entry', function()
      package.loaded['nit.display.thread_panel'] = nil
      local tp = require('nit.display.thread_panel')

      local hints = tp.get_hints()

      local found = false
      for _, hint in ipairs(hints) do
        if hint.key == 'C-s' and hint.label == 'Submit reply' then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('default hints include C-a Actions entry', function()
      package.loaded['nit.display.thread_panel'] = nil
      local tp = require('nit.display.thread_panel')

      local hints = tp.get_hints()

      local found = false
      for _, hint in ipairs(hints) do
        if hint.key == 'C-a' and hint.label == 'Actions' then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it('default hints include j/k Navigate comments entry', function()
      package.loaded['nit.display.thread_panel'] = nil
      local tp = require('nit.display.thread_panel')

      local hints = tp.get_hints()

      local found = false
      for _, hint in ipairs(hints) do
        if hint.key == 'j/k' and hint.label == 'Navigate comments' then
          found = true
        end
      end
      assert.is_true(found)
    end)
  end)

  describe('get_line_highlights', function()
    it('single comment: no lines get alt background', function()
      local lines = {
        ' @alice · just now',
        '',
        ' Body text',
      }
      local author_indices = { [1] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      for _, hl in pairs(result) do
        assert.not_equals('NitThreadCommentAlt', hl.line_hl_group)
      end
    end)

    it(
      'second comment author line gets NitThreadCommentAlt, body lines are unhighlighted',
      function()
        local lines = {
          ' @alice · just now',
          '',
          ' First comment',
          '',
          ' @bob · 1 day ago',
          '',
          ' Second comment',
        }
        local author_indices = { [1] = true, [5] = true }

        local result = thread_panel.get_line_highlights(lines, author_indices)

        assert.is_not_nil(result[5])
        assert.are.equal('NitThreadCommentAlt', result[5].line_hl_group)
        assert.are.equal('NitThreadAuthor', result[5].hl_group)

        assert.is_nil(result[6])
        assert.is_nil(result[7])
      end
    )

    it('three comments: comments 1 and 3 use default, comment 2 uses alt', function()
      local lines = {
        ' @alice · just now',
        '',
        ' First',
        '',
        ' @bob · 1 day ago',
        '',
        ' Second',
        '',
        ' @charlie · 2 days ago',
        '',
        ' Third',
      }
      local author_indices = { [1] = true, [5] = true, [9] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.is_not_nil(result[1])
      assert.not_equals('NitThreadCommentAlt', result[1].line_hl_group)

      assert.is_not_nil(result[5])
      assert.are.equal('NitThreadCommentAlt', result[5].line_hl_group)

      if result[9] then
        assert.not_equals('NitThreadCommentAlt', result[9].line_hl_group)
      end
    end)

    it('author line in even comment uses NitThreadCommentAlt for line_hl_group', function()
      local lines = {
        ' @alice · just now',
        '',
        ' First',
        '',
        ' @bob · 1 day ago',
      }
      local author_indices = { [1] = true, [5] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.is_not_nil(result[5])
      assert.are.equal('NitThreadAuthor', result[5].hl_group)
      assert.are.equal('NitThreadCommentAlt', result[5].line_hl_group)
    end)

    it('author line in odd comment uses NitThreadComment for line_hl_group', function()
      local lines = {
        ' @alice · just now',
        '',
        ' Body',
      }
      local author_indices = { [1] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.is_not_nil(result[1])
      assert.are.equal('NitThreadAuthor', result[1].hl_group)
      assert.are.equal('NitThreadComment', result[1].line_hl_group)
    end)

    it('returns text_col matching leading whitespace count for right-aligned header', function()
      local padding = string.rep(' ', 42)
      local right_line = padding .. '@alice - 1 hour ago'
      local lines = { right_line }
      local author_indices = { [1] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.is_not_nil(result[1])
      assert.are.equal(42, result[1].text_col)
    end)

    it('returns text_col of 1 for left-aligned header', function()
      local lines = { ' @alice - 1 hour ago' }
      local author_indices = { [1] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.is_not_nil(result[1])
      assert.are.equal(1, result[1].text_col)
    end)

    it('separator blank before even comment gets no alt (belongs to odd comment)', function()
      local lines = {
        ' @alice · just now',
        '',
        ' First',
        '',
        ' @bob · 1 day ago',
      }
      local author_indices = { [1] = true, [5] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      if result[4] then
        assert.not_equals('NitThreadCommentAlt', result[4].line_hl_group)
      end
    end)
  end)

  describe('get_title_highlight', function()
    it('returns NitThreadTitle for unresolved thread', function()
      local thread = {
        isResolved = false,
        comments = {},
      }

      local hl = thread_panel.get_title_highlight(thread)

      assert.are.equal('NitThreadTitle', hl)
    end)

    it('returns NitThreadTitleResolved for resolved thread', function()
      local thread = {
        isResolved = true,
        comments = {},
      }

      local hl = thread_panel.get_title_highlight(thread)

      assert.are.equal('NitThreadTitleResolved', hl)
    end)
  end)

  describe('window lifecycle', function()
    local orig_observers, orig_data, orig_orchestration

    before_each(function()
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil

      orig_observers = package.loaded['nit.state.observers']
      orig_data = package.loaded['nit.state.data']
      orig_orchestration = package.loaded['nit.orchestration']

      package.loaded['nit.state.observers'] = {
        subscribe = function(_event, _cb)
          return function() end
        end,
      }

      package.loaded['nit.state.data'] = {
        get_viewer_login = function()
          return nil
        end,
        get_thread = function(_id)
          return nil
        end,
        clear = function() end,
        set_viewer_login = function(_login) end,
      }

      package.loaded['nit.orchestration'] = {
        submit_reply = function() end,
        toggle_resolved = function() end,
      }
    end)

    after_each(function()
      package.loaded['nit.state.observers'] = orig_observers
      package.loaded['nit.state.data'] = orig_data
      package.loaded['nit.orchestration'] = orig_orchestration
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil
    end)

    local function make_thread()
      return {
        id = 'thread-1',
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'Hello', createdAt = '2026-01-01T12:00:00Z' },
        },
      }
    end

    it('closing panel window externally also closes reply input', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open()
      end)
      assert.is_true(tp.is_open())

      local panel_winid = tp.get_winid()
      assert.is_not_nil(panel_winid)

      vim.api.nvim_win_close(panel_winid, true)

      vim.wait(100, function()
        return not tp.is_open()
      end)

      assert.is_false(tp.is_open())
      assert.is_false(ri.is_open())

      tp.close()
    end)

    it('closing reply input window externally also closes panel', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open() and ri.is_open()
      end)
      assert.is_true(tp.is_open())
      assert.is_true(ri.is_open())

      local reply_winid = ri.get_winid()
      assert.is_not_nil(reply_winid)

      vim.api.nvim_win_close(reply_winid, true)

      vim.wait(100, function()
        return not tp.is_open()
      end)

      assert.is_false(tp.is_open())
      assert.is_false(ri.is_open())

      tp.close()
    end)

    it('reply input has <CR> normal mode mapping after show', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open() and ri.is_open()
      end)

      local bufnr = ri.get_bufnr()
      assert.is_not_nil(bufnr)

      local keymaps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
      local has_cr = false
      for _, km in ipairs(keymaps) do
        if km.lhs == '<CR>' then
          has_cr = true
          break
        end
      end

      assert.is_true(has_cr, 'reply input must have <CR> normal mode mapping for submit')

      tp.close()
    end)

    it('reply input buffer has textwidth=0 after show', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open() and ri.is_open()
      end)

      local bufnr = ri.get_bufnr()
      assert.is_not_nil(bufnr)
      assert.are.equal(0, vim.bo[bufnr].textwidth)

      tp.close()
    end)

    it('reply input buffer has formatoptions="" after show', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open() and ri.is_open()
      end)

      local bufnr = ri.get_bufnr()
      assert.is_not_nil(bufnr)
      assert.are.equal('', vim.bo[bufnr].formatoptions)

      tp.close()
    end)

    it('reply input window has wrap=true after show', function()
      local tp = require('nit.display.thread_panel')
      local ri = require('nit.display.reply_input')

      tp.show(make_thread())

      vim.wait(50, function()
        return tp.is_open() and ri.is_open()
      end)

      local winid = ri.get_winid()
      assert.is_not_nil(winid)
      assert.is_true(vim.wo[winid].wrap)
      assert.is_true(vim.wo[winid].linebreak)
      assert.is_true(vim.wo[winid].breakindent)
      assert.are.equal(' ', vim.wo[winid].showbreak)

      tp.close()
    end)

    it('calling M.close() twice does not error', function()
      local tp = require('nit.display.thread_panel')

      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      assert.has_no.errors(function()
        tp.close()
        tp.close()
      end)
    end)
  end)

  describe('window equalization', function()
    local orig_observers, orig_data, orig_orchestration

    before_each(function()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        pcall(vim.api.nvim_win_close, w, true)
      end
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil

      orig_observers = package.loaded['nit.state.observers']
      orig_data = package.loaded['nit.state.data']
      orig_orchestration = package.loaded['nit.orchestration']

      package.loaded['nit.state.observers'] = {
        subscribe = function(_event, _cb)
          return function() end
        end,
      }

      package.loaded['nit.state.data'] = {
        get_viewer_login = function()
          return nil
        end,
        get_thread = function(_id)
          return nil
        end,
        clear = function() end,
        set_viewer_login = function(_login) end,
      }

      package.loaded['nit.orchestration'] = {
        submit_reply = function() end,
        toggle_resolved = function() end,
      }
    end)

    after_each(function()
      package.loaded['nit.state.observers'] = orig_observers
      package.loaded['nit.state.data'] = orig_data
      package.loaded['nit.orchestration'] = orig_orchestration
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil
    end)

    local function make_thread()
      return {
        id = 'thread-1',
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'Hello', createdAt = '2026-01-01T12:00:00Z' },
        },
      }
    end

    it('panel width is 60 after mount', function()
      local tp = require('nit.display.thread_panel')

      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      local panel_winid = tp.get_winid()
      assert.is_not_nil(panel_winid)
      assert.are.equal(60, vim.api.nvim_win_get_width(panel_winid))

      tp.close()
    end)

    it('other windows are equalized after panel mounts in multi-window layout', function()
      local tp = require('nit.display.thread_panel')

      vim.cmd('vsplit')
      vim.cmd('vsplit')

      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      local ri = require('nit.display.reply_input')
      local panel_winid = tp.get_winid()
      local reply_winid = ri.get_winid()
      local all_wins = vim.api.nvim_list_wins()
      local non_panel_wins = vim.tbl_filter(function(w)
        return w ~= panel_winid
          and w ~= reply_winid
          and vim.api.nvim_win_is_valid(w)
          and vim.api.nvim_win_get_config(w).relative == ''
      end, all_wins)

      if #non_panel_wins >= 2 then
        local widths = vim.tbl_map(vim.api.nvim_win_get_width, non_panel_wins)
        local min_w = math.min(unpack(widths))
        local max_w = math.max(unpack(widths))
        assert.is_true(max_w - min_w <= 2, 'non-panel windows should be equalized')
      end

      tp.close()
      pcall(vim.cmd, 'only')
    end)

    it('windows are re-equalized after panel closes', function()
      local tp = require('nit.display.thread_panel')

      vim.cmd('vsplit')

      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp.close()
      vim.wait(20)

      local all_wins = vim.api.nvim_list_wins()
      local normal_wins = vim.tbl_filter(function(w)
        return vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == ''
      end, all_wins)

      if #normal_wins >= 2 then
        local widths = vim.tbl_map(vim.api.nvim_win_get_width, normal_wins)
        local min_w = math.min(unpack(widths))
        local max_w = math.max(unpack(widths))
        assert.is_true(max_w - min_w <= 2, 'windows should equalize after close')
      end

      pcall(vim.cmd, 'only')
    end)
  end)

  describe('find_comment_at_line', function()
    it('returns nil for empty ranges table', function()
      assert.is_nil(thread_panel._find_comment_at_line(1, {}))
    end)

    it('returns nil for line before all ranges', function()
      local ranges = { { comment_index = 1, start_line = 3, end_line = 5 } }
      assert.is_nil(thread_panel._find_comment_at_line(1, ranges))
      assert.is_nil(thread_panel._find_comment_at_line(2, ranges))
    end)

    it('returns comment_index for lines within a range', function()
      local ranges = { { comment_index = 1, start_line = 1, end_line = 3 } }
      assert.are.equal(1, thread_panel._find_comment_at_line(1, ranges))
      assert.are.equal(1, thread_panel._find_comment_at_line(2, ranges))
      assert.are.equal(1, thread_panel._find_comment_at_line(3, ranges))
    end)

    it('returns nil for separator line between two comment ranges', function()
      local ranges = {
        { comment_index = 1, start_line = 1, end_line = 3 },
        { comment_index = 2, start_line = 5, end_line = 7 },
      }
      assert.is_nil(thread_panel._find_comment_at_line(4, ranges))
    end)

    it('returns comment_index for last line of a range', function()
      local ranges = { { comment_index = 2, start_line = 5, end_line = 9 } }
      assert.are.equal(2, thread_panel._find_comment_at_line(9, ranges))
      assert.is_nil(thread_panel._find_comment_at_line(10, ranges))
    end)

    it('returns correct index for multiple ranges', function()
      local ranges = {
        { comment_index = 1, start_line = 1, end_line = 3 },
        { comment_index = 2, start_line = 5, end_line = 7 },
        { comment_index = 3, start_line = 9, end_line = 11 },
      }
      assert.are.equal(2, thread_panel._find_comment_at_line(6, ranges))
      assert.are.equal(3, thread_panel._find_comment_at_line(9, ranges))
    end)
  end)

  describe('select_comment', function()
    before_each(function()
      package.loaded['nit.display.thread_panel'] = nil
      thread_panel = require('nit.display.thread_panel')
    end)

    after_each(function()
      package.loaded['nit.display.thread_panel'] = nil
      thread_panel = require('nit.display.thread_panel')
    end)

    it('starts with no selection', function()
      assert.is_nil(thread_panel._get_selected_idx())
    end)

    it('select_comment with nil deselects without error', function()
      thread_panel._select_comment(nil)
      assert.is_nil(thread_panel._get_selected_idx())
    end)

    it('select_comment with 0 is a no-op', function()
      thread_panel._select_comment(0)
      assert.is_nil(thread_panel._get_selected_idx())
    end)

    it('select_comment with index beyond empty ranges is a no-op', function()
      thread_panel._select_comment(1)
      assert.is_nil(thread_panel._get_selected_idx())
    end)
  end)

  describe('comment selection lifecycle', function()
    local orig_observers, orig_data, orig_orchestration
    local tp

    before_each(function()
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil

      orig_observers = package.loaded['nit.state.observers']
      orig_data = package.loaded['nit.state.data']
      orig_orchestration = package.loaded['nit.orchestration']

      package.loaded['nit.state.observers'] = {
        subscribe = function(_event, _cb)
          return function() end
        end,
      }

      package.loaded['nit.state.data'] = {
        get_viewer_login = function()
          return nil
        end,
        get_thread = function(_id)
          return nil
        end,
        clear = function() end,
        set_viewer_login = function(_login) end,
      }

      package.loaded['nit.orchestration'] = {
        submit_reply = function() end,
        toggle_resolved = function() end,
      }

      tp = require('nit.display.thread_panel')
    end)

    after_each(function()
      if tp.is_open() then
        tp.close()
      end
      package.loaded['nit.state.observers'] = orig_observers
      package.loaded['nit.state.data'] = orig_data
      package.loaded['nit.orchestration'] = orig_orchestration
      package.loaded['nit.display.thread_panel'] = nil
      package.loaded['nit.display.reply_input'] = nil
    end)

    local function make_thread()
      return {
        id = 'thread-1',
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'Hello', createdAt = '2026-01-01T12:00:00Z' },
        },
      }
    end

    local function make_thread_multi()
      return {
        id = 'thread-multi',
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'First', createdAt = '2026-01-01T12:00:00Z' },
          { author = { login = 'bob' }, body = 'Second', createdAt = '2026-01-02T12:00:00Z' },
        },
      }
    end

    it('CursorMoved on panel buffer updates selected_comment_idx', function()
      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      local bufnr = vim.api.nvim_win_get_buf(tp.get_winid())
      vim.api.nvim_win_set_cursor(tp.get_winid(), { 1, 0 })
      vim.api.nvim_exec_autocmds('CursorMoved', { buffer = bufnr })

      assert.are.equal(1, tp._get_selected_idx())
    end)

    it('j keymap from unselected state selects first comment', function()
      tp.show(make_thread_multi())
      vim.wait(50, function()
        return tp.is_open()
      end)

      vim.api.nvim_set_current_win(tp.get_winid())
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('j', true, false, true), 'x', false)

      assert.are.equal(1, tp._get_selected_idx())
    end)

    it('k keymap when first comment selected is a no-op', function()
      tp.show(make_thread_multi())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(1)
      vim.api.nvim_set_current_win(tp.get_winid())
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('k', true, false, true), 'x', false)

      assert.are.equal(1, tp._get_selected_idx())
    end)

    it('j keymap advances from comment 1 to comment 2', function()
      tp.show(make_thread_multi())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(1)
      vim.api.nvim_set_current_win(tp.get_winid())
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('j', true, false, true), 'x', false)

      assert.are.equal(2, tp._get_selected_idx())
    end)

    it('j keymap when last comment selected is a no-op', function()
      tp.show(make_thread_multi())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(2)
      vim.api.nvim_set_current_win(tp.get_winid())
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('j', true, false, true), 'x', false)

      assert.are.equal(2, tp._get_selected_idx())
    end)

    it('k keymap goes from comment 2 to comment 1', function()
      tp.show(make_thread_multi())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(2)
      vim.api.nvim_set_current_win(tp.get_winid())
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('k', true, false, true), 'x', false)

      assert.are.equal(1, tp._get_selected_idx())
    end)

    it('thread change resets selected_comment_idx to nil', function()
      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(1)
      assert.are.equal(1, tp._get_selected_idx())

      local different_thread = {
        id = 'thread-different',
        isResolved = false,
        comments = {
          { author = { login = 'carol' }, body = 'Other', createdAt = '2026-01-03T12:00:00Z' },
        },
      }
      tp.update(different_thread)

      assert.is_nil(tp._get_selected_idx())
    end)

    it('M.close() resets selected_comment_idx to nil', function()
      tp.show(make_thread())
      vim.wait(50, function()
        return tp.is_open()
      end)

      tp._select_comment(1)
      assert.are.equal(1, tp._get_selected_idx())

      tp.close()

      assert.is_nil(tp._get_selected_idx())
    end)
  end)
end)

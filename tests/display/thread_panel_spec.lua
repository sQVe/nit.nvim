local assert = require('luassert')
local thread_panel = require('nit.display.thread_panel')

describe('thread_panel', function()
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

      assert.equals(' Thread', title)
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

      assert.equals(' Thread · Resolved', title)
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

      assert.equals(' Thread (1 reply)', title)
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

      assert.equals(' Thread (2 replies)', title)
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

      assert.equals(' Thread · Resolved (2 replies)', title)
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

      assert.equals(3, #hints)
      assert.equals('q', hints[1].key)
      assert.equals('r', hints[2].key)
      assert.equals('t', hints[3].key)
    end)
  end)

  describe('clear_hints', function()
    it('resets hint registry correctly', function()
      thread_panel.clear_hints()
      thread_panel.register_hints({
        { key = 'q', label = 'Close' },
      })

      assert.equals(1, #thread_panel.get_hints())

      thread_panel.clear_hints()

      assert.equals(0, #thread_panel.get_hints())

      thread_panel.register_hints({
        { key = 'x', label = 'New' },
      })

      local hints = thread_panel.get_hints()
      assert.equals(1, #hints)
      assert.equals('x', hints[1].key)
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
      assert.equals(1, #hints)
      assert.equals('q', hints[1].key)
      assert.equals('Close', hints[1].label)
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

        assert.not_nil(result[5])
        assert.equals('NitThreadCommentAlt', result[5].line_hl_group)
        assert.equals('NitThreadAuthor', result[5].hl_group)

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

      assert.not_nil(result[1])
      assert.not_equals('NitThreadCommentAlt', result[1].line_hl_group)

      assert.not_nil(result[5])
      assert.equals('NitThreadCommentAlt', result[5].line_hl_group)

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

      assert.not_nil(result[5])
      assert.equals('NitThreadAuthor', result[5].hl_group)
      assert.equals('NitThreadCommentAlt', result[5].line_hl_group)
    end)

    it('author line in odd comment uses NitThreadComment for line_hl_group', function()
      local lines = {
        ' @alice · just now',
        '',
        ' Body',
      }
      local author_indices = { [1] = true }

      local result = thread_panel.get_line_highlights(lines, author_indices)

      assert.not_nil(result[1])
      assert.equals('NitThreadAuthor', result[1].hl_group)
      assert.equals('NitThreadComment', result[1].line_hl_group)
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

      assert.equals('NitThreadTitle', hl)
    end)

    it('returns NitThreadTitleResolved for resolved thread', function()
      local thread = {
        isResolved = true,
        comments = {},
      }

      local hl = thread_panel.get_title_highlight(thread)

      assert.equals('NitThreadTitleResolved', hl)
    end)
  end)
end)

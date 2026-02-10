local assert = require('luassert')
local comment_popup = require('nit.display.comment_popup')

describe('comment_popup', function()
  describe('format_thread', function()
    it('formats single comment thread', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = 'Looks good',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local lines = comment_popup.format_thread(thread)

      assert.is_table(lines)
      assert.is_true(#lines > 0)

      local combined = table.concat(lines, '\n')
      assert.matches('alice', combined, 1, true)
      assert.matches('Looks good', combined, 1, true)
    end)

    it('formats multi-comment thread with separators', function()
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

      local lines = comment_popup.format_thread(thread)

      local combined = table.concat(lines, '\n')
      assert.matches('alice', combined, 1, true)
      assert.matches('bob', combined, 1, true)
      assert.matches('charlie', combined, 1, true)
      assert.matches('First comment', combined, 1, true)
      assert.matches('Second comment', combined, 1, true)
      assert.matches('Third comment', combined, 1, true)

      local separator_count = 0
      for _, line in ipairs(lines) do
        if line == '---' then
          separator_count = separator_count + 1
        end
      end
      assert.equals(2, separator_count)
    end)

    it('handles multi-line comment body', function()
      local thread = {
        comments = {
          {
            author = { login = 'alice' },
            body = 'Line 1\nLine 2\nLine 3',
            createdAt = '2026-01-01T12:00:00Z',
          },
        },
      }

      local lines = comment_popup.format_thread(thread)

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

      local lines = comment_popup.format_thread(thread)

      assert.is_table(lines)
      local combined = table.concat(lines, '\n')
      assert.matches('alice', combined, 1, true)
    end)
  end)

  describe('format_title', function()
    it('shows resolved indicator for resolved threads', function()
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

      local title = comment_popup.format_title(thread)

      assert.is_string(title)
      assert.matches('Resolved', title, 1, true)
    end)

    it('shows comment thread for unresolved threads', function()
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

      local title = comment_popup.format_title(thread)

      assert.is_string(title)
      assert.matches('Comment Thread', title, 1, true)
    end)

    it('includes reply count for multi-comment threads', function()
      local thread = {
        isResolved = false,
        comments = {
          { author = { login = 'alice' }, body = 'test', createdAt = '2026-01-01T12:00:00Z' },
          { author = { login = 'bob' }, body = 'test', createdAt = '2026-01-02T12:00:00Z' },
          { author = { login = 'charlie' }, body = 'test', createdAt = '2026-01-03T12:00:00Z' },
        },
      }

      local title = comment_popup.format_title(thread)

      assert.matches('3 repl', title, 1, true)
    end)
  end)
end)

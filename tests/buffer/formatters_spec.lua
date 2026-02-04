describe('nit.buffer.formatters', function()
  local formatters = require('nit.buffer.formatters')

  describe('format_relative_time', function()
    it('formats recent times as "just now"', function()
      local current_time = os.time()
      assert.equals(
        'just now',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 30))
      )
      assert.equals(
        'just now',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 59))
      )
    end)

    it('formats minutes ago', function()
      local current_time = os.time()
      assert.equals(
        '1 minute ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 60))
      )
      assert.equals(
        '2 minutes ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 120))
      )
      assert.equals(
        '59 minutes ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 3540))
      )
    end)

    it('formats hours ago', function()
      local current_time = os.time()
      assert.equals(
        '1 hour ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 3600))
      )
      assert.equals(
        '2 hours ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 7200))
      )
      assert.equals(
        '23 hours ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 82800))
      )
    end)

    it('formats days ago', function()
      local current_time = os.time()
      assert.equals(
        '1 day ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 86400))
      )
      assert.equals(
        '2 days ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 172800))
      )
      assert.equals(
        '6 days ago',
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 518400))
      )
    end)

    it('formats 7+ days as date', function()
      local current_time = os.time()
      local seven_days_ago = os.date('!*t', current_time - 604800)
      local expected_date = string.format(
        '%02d/%02d/%04d',
        seven_days_ago.month,
        seven_days_ago.day,
        seven_days_ago.year
      )
      assert.equals(
        expected_date,
        formatters.format_relative_time(os.date('!%Y-%m-%dT%H:%M:%SZ', current_time - 604800))
      )
    end)

    it('returns original string if parsing fails', function()
      assert.equals('invalid-timestamp', formatters.format_relative_time('invalid-timestamp'))
      assert.equals('', formatters.format_relative_time(''))
    end)
  end)

  describe('format_pr_state', function()
    it('formats states correctly', function()
      assert.equals('OPEN', formatters.format_pr_state('open', false))
      assert.equals('CLOSED', formatters.format_pr_state('closed', false))
      assert.equals('MERGED', formatters.format_pr_state('merged', false))
    end)

    it('prioritizes draft over state', function()
      assert.equals('DRAFT', formatters.format_pr_state('open', true))
      assert.equals('DRAFT', formatters.format_pr_state('closed', true))
      assert.equals('DRAFT', formatters.format_pr_state('merged', true))
    end)
  end)

  describe('format_review_state', function()
    it('formats known states', function()
      assert.equals('Pending', formatters.format_review_state('PENDING'))
      assert.equals('Approved', formatters.format_review_state('APPROVED'))
      assert.equals('Changes requested', formatters.format_review_state('CHANGES_REQUESTED'))
      assert.equals('Commented', formatters.format_review_state('COMMENTED'))
      assert.equals('Dismissed', formatters.format_review_state('DISMISSED'))
    end)

    it('returns original string for unknown states', function()
      assert.equals('UNKNOWN_STATE', formatters.format_review_state('UNKNOWN_STATE'))
    end)
  end)

  describe('format_reactions', function()
    it('returns empty string for nil or empty reactions', function()
      assert.equals('', formatters.format_reactions(nil))
      assert.equals('', formatters.format_reactions({}))
    end)

    it('formats single reaction', function()
      local single_reaction = {
        { content = 'THUMBS_UP', count = 3 },
      }
      assert.equals('+1 3', formatters.format_reactions(single_reaction))
    end)

    it('formats multiple reactions', function()
      local multiple_reactions = {
        { content = 'THUMBS_UP', count = 3 },
        { content = 'HEART', count = 2 },
        { content = 'LAUGH', count = 1 },
      }
      assert.equals('+1 3  heart 2  laugh 1', formatters.format_reactions(multiple_reactions))
    end)

    it('skips reactions with zero count', function()
      local zero_count = {
        { content = 'THUMBS_UP', count = 0 },
      }
      assert.equals('', formatters.format_reactions(zero_count))
    end)

    it('filters zero count from mixed reactions', function()
      local mixed_counts = {
        { content = 'THUMBS_UP', count = 5 },
        { content = 'HEART', count = 0 },
        { content = 'ROCKET', count = 1 },
      }
      assert.equals('+1 5  rocket 1', formatters.format_reactions(mixed_counts))
    end)
  end)
end)

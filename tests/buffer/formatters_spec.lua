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

  describe('get_reaction_icon', function()
    it('returns +1 for THUMBS_UP', function()
      assert.equals('+1', formatters.get_reaction_icon('THUMBS_UP'))
    end)

    it('returns -1 for THUMBS_DOWN', function()
      assert.equals('-1', formatters.get_reaction_icon('THUMBS_DOWN'))
    end)

    it('returns mapped icons for known reactions', function()
      assert.equals('laugh', formatters.get_reaction_icon('LAUGH'))
      assert.equals('hooray', formatters.get_reaction_icon('HOORAY'))
      assert.equals('confused', formatters.get_reaction_icon('CONFUSED'))
      assert.equals('heart', formatters.get_reaction_icon('HEART'))
      assert.equals('rocket', formatters.get_reaction_icon('ROCKET'))
      assert.equals('eyes', formatters.get_reaction_icon('EYES'))
    end)

    it('returns lowercase for unknown reactions', function()
      assert.equals('unknown_emoji', formatters.get_reaction_icon('UNKNOWN_EMOJI'))
    end)
  end)
end)

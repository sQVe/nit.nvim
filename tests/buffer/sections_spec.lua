describe('nit.buffer.sections', function()
  local sections = require('nit.buffer.sections')

  describe('metadata', function()
    it('renders complete PR metadata', function()
      local pr = {
        title = 'Add new feature',
        isDraft = false,
        state = 'open',
        author = { login = 'johndoe' },
        labels = {
          { name = 'bug' },
          { name = 'enhancement' },
        },
        assignees = {
          { login = 'alice' },
          { login = 'bob' },
        },
        reviewers = {
          { login = 'charlie', state = 'APPROVED' },
          { login = 'diana', state = 'PENDING' },
        },
      }

      local lines = sections.metadata(pr)

      assert.equals('# Add new feature', lines[1])
      assert.equals('', lines[2])
      assert.equals('**Author:** johndoe', lines[3])
      assert.equals('**Status:** OPEN', lines[4])
      assert.equals('**Labels:** bug, enhancement', lines[5])
      assert.equals('**Assignees:** alice, bob', lines[6])
      assert.equals('**Reviewers:** charlie (Approved), diana (Pending)', lines[7])
    end)

    it('renders draft indicator in title', function()
      local pr = {
        title = 'Work in progress',
        isDraft = true,
        state = 'open',
        author = { login = 'johndoe' },
      }

      local lines = sections.metadata(pr)

      assert.equals('# [DRAFT] Work in progress', lines[1])
    end)

    it('omits labels when not present', function()
      local pr = {
        title = 'Test PR',
        isDraft = false,
        state = 'open',
        author = { login = 'johndoe' },
        labels = {},
      }

      local lines = sections.metadata(pr)

      for _, line in ipairs(lines) do
        assert.is_nil(line:match('^%*%*Labels:%*%*'))
      end
    end)

    it('omits assignees when not present', function()
      local pr = {
        title = 'Test PR',
        isDraft = false,
        state = 'open',
        author = { login = 'johndoe' },
        assignees = {},
      }

      local lines = sections.metadata(pr)

      for _, line in ipairs(lines) do
        assert.is_nil(line:match('^%*%*Assignees:%*%*'))
      end
    end)

    it('omits reviewers when not present', function()
      local pr = {
        title = 'Test PR',
        isDraft = false,
        state = 'open',
        author = { login = 'johndoe' },
        reviewers = {},
      }

      local lines = sections.metadata(pr)

      for _, line in ipairs(lines) do
        assert.is_nil(line:match('^%*%*Reviewers:%*%*'))
      end
    end)

    it('includes branch information', function()
      local pr = {
        title = 'Test PR',
        isDraft = false,
        state = 'open',
        author = { login = 'johndoe' },
        headRefName = 'feature-branch',
        baseRefName = 'main',
      }

      local lines = sections.metadata(pr)

      local has_branch = false
      for _, line in ipairs(lines) do
        if line == '**Branch:** feature-branch -> main' then
          has_branch = true
          break
        end
      end
      assert.is_true(has_branch)
    end)
  end)

  describe('separator', function()
    it('returns horizontal rule with blank lines', function()
      local lines = sections.separator()

      assert.equals(3, #lines)
      assert.equals('', lines[1])
      assert.equals('---', lines[2])
      assert.equals('', lines[3])
    end)
  end)

  describe('description', function()
    it('renders description section with content', function()
      local pr = {
        body = 'This PR adds a new feature.\n\nIt includes:\n- Feature A\n- Feature B',
      }

      local lines = sections.description(pr)

      assert.equals('## Description', lines[1])
      assert.equals('', lines[2])
      assert.equals('This PR adds a new feature.', lines[3])
      assert.equals('', lines[4])
      assert.equals('It includes:', lines[5])
      assert.equals('- Feature A', lines[6])
      assert.equals('- Feature B', lines[7])
    end)

    it('shows placeholder for empty body', function()
      local pr = {
        body = nil,
      }

      local lines = sections.description(pr)

      assert.equals('## Description', lines[1])
      assert.equals('', lines[2])
      assert.equals('*No description provided.*', lines[3])
    end)

    it('shows placeholder for empty string body', function()
      local pr = {
        body = '',
      }

      local lines = sections.description(pr)

      assert.equals('## Description', lines[1])
      assert.equals('', lines[2])
      assert.equals('*No description provided.*', lines[3])
    end)
  end)

  describe('comments', function()
    it('renders comments with author and timestamp', function()
      local comments = {
        {
          author = { login = 'alice' },
          createdAt = '2024-01-15T10:30:00Z',
          body = 'Looks good to me!',
          reactions = {},
        },
        {
          author = { login = 'bob' },
          createdAt = '2024-01-15T11:00:00Z',
          body = 'Can you add tests?',
          reactions = {},
        },
      }

      local lines = sections.comments(comments)

      assert.equals('## Conversation', lines[1])
      assert.equals('', lines[2])
      assert.is_not_nil(lines[3]:match('^%*%*alice%*%* commented'))
      assert.equals('', lines[4])
      assert.equals('Looks good to me!', lines[5])
      assert.equals('', lines[6])
      assert.is_not_nil(lines[7]:match('^%*%*bob%*%* commented'))
      assert.equals('', lines[8])
      assert.equals('Can you add tests?', lines[9])
    end)

    it('renders multiline comment body', function()
      local comments = {
        {
          author = { login = 'alice' },
          createdAt = '2024-01-15T10:30:00Z',
          body = 'First line.\nSecond line.\nThird line.',
          reactions = {},
        },
      }

      local lines = sections.comments(comments)

      assert.equals('First line.', lines[5])
      assert.equals('Second line.', lines[6])
      assert.equals('Third line.', lines[7])
    end)

    it('renders reactions when present', function()
      local comments = {
        {
          author = { login = 'alice' },
          createdAt = '2024-01-15T10:30:00Z',
          body = 'Great work!',
          reactions = {
            THUMBS_UP = 3,
            HEART = 2,
          },
        },
      }

      local lines = sections.comments(comments)

      local has_reactions = false
      for _, line in ipairs(lines) do
        if line:match('^> ') and line:match('%+1') then
          has_reactions = true
          break
        end
      end
      assert.is_true(has_reactions)
    end)

    it('shows placeholder for empty comments', function()
      local comments = {}

      local lines = sections.comments(comments)

      assert.equals('## Conversation', lines[1])
      assert.equals('', lines[2])
      assert.equals('*No comments yet.*', lines[3])
    end)
  end)
end)

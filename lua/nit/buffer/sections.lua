local formatters = require('nit.buffer.formatters')

local M = {}

---@param pr Nit.Api.PR
---@return string[]
function M.metadata(pr)
  local lines = {}

  local title = pr.isDraft and '# [DRAFT] ' .. pr.title or '# ' .. pr.title
  table.insert(lines, title)
  table.insert(lines, '')

  table.insert(lines, '**Author:** ' .. pr.author.login)

  local status = formatters.format_pr_state(pr.state, pr.isDraft)
  table.insert(lines, '**Status:** ' .. status)

  if pr.headRefName and pr.baseRefName then
    table.insert(lines, '**Branch:** ' .. pr.headRefName .. ' -> ' .. pr.baseRefName)
  end

  if pr.labels and #pr.labels > 0 then
    local label_names = {}
    for _, label in ipairs(pr.labels) do
      table.insert(label_names, label.name)
    end
    table.insert(lines, '**Labels:** ' .. table.concat(label_names, ', '))
  end

  if pr.assignees and #pr.assignees > 0 then
    local assignee_logins = {}
    for _, assignee in ipairs(pr.assignees) do
      table.insert(assignee_logins, assignee.login)
    end
    table.insert(lines, '**Assignees:** ' .. table.concat(assignee_logins, ', '))
  end

  if pr.reviewers and #pr.reviewers > 0 then
    local reviewer_parts = {}
    for _, reviewer in ipairs(pr.reviewers) do
      local state_label = formatters.format_review_state(reviewer.state)
      table.insert(reviewer_parts, reviewer.login .. ' (' .. state_label .. ')')
    end
    table.insert(lines, '**Reviewers:** ' .. table.concat(reviewer_parts, ', '))
  end

  return lines
end

---@return string[]
function M.separator()
  return { '', '---', '' }
end

---@param pr Nit.Api.PR
---@return string[]
function M.description(pr)
  local lines = {}

  table.insert(lines, '## Description')
  table.insert(lines, '')

  if not pr.body or pr.body == '' then
    table.insert(lines, '*No description provided.*')
    return lines
  end

  for line in (pr.body .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end

  return lines
end

---@param comments Nit.Api.IssueComment[]
---@return string[]
function M.comments(comments)
  local lines = {}

  table.insert(lines, '## Conversation')
  table.insert(lines, '')

  if not comments or #comments == 0 then
    table.insert(lines, '*No comments yet.*')
    return lines
  end

  for _, comment in ipairs(comments) do
    local timestamp = formatters.format_relative_time(comment.createdAt)
    table.insert(lines, '**' .. comment.author.login .. '** commented ' .. timestamp)
    table.insert(lines, '')

    for line in (comment.body .. '\n'):gmatch('([^\n]*)\n') do
      table.insert(lines, line)
    end

    if comment.reactions and next(comment.reactions) then
      local reaction_parts = {}
      for emoji, count in pairs(comment.reactions) do
        if count > 0 then
          local icon = emoji:lower():gsub('thumbs_up', '+1'):gsub('thumbs_down', '-1')
          table.insert(reaction_parts, icon .. ' ' .. count)
        end
      end
      if #reaction_parts > 0 then
        table.insert(lines, '> ' .. table.concat(reaction_parts, '  '))
      end
    end

    table.insert(lines, '')
  end

  return lines
end

return M

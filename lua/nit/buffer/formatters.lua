local M = {}

local REVIEW_STATE_LABELS = {
  PENDING = 'Pending',
  APPROVED = 'Approved',
  CHANGES_REQUESTED = 'Changes requested',
  COMMENTED = 'Commented',
  DISMISSED = 'Dismissed',
}

---@param iso_timestamp string
---@return string
function M.format_relative_time(iso_timestamp)
  local year, month, day, hour, min, sec =
    iso_timestamp:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if not year then
    return iso_timestamp
  end

  local utc_time = os.time({
    year = assert(tonumber(year)),
    month = assert(tonumber(month)),
    day = assert(tonumber(day)),
    hour = assert(tonumber(hour)),
    min = assert(tonumber(min)),
    sec = assert(tonumber(sec)),
    isdst = false,
  })

  local utc_date = os.date('!*t')
  assert(type(utc_date) == 'table', 'os.date failed to return table')
  utc_date.isdst = false
  local utc_now = os.time(utc_date)

  local diff = os.difftime(utc_now, utc_time)

  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    local mins = math.floor(diff / 60)
    return mins .. (mins == 1 and ' minute ago' or ' minutes ago')
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. (hours == 1 and ' hour ago' or ' hours ago')
  elseif diff < 604800 then
    local days = math.floor(diff / 86400)
    return days .. (days == 1 and ' day ago' or ' days ago')
  else
    return string.format('%02d/%02d/%04d', tonumber(month), tonumber(day), tonumber(year))
  end
end

---@param state string
---@param is_draft boolean
---@return string
function M.format_pr_state(state, is_draft)
  if is_draft then
    return 'DRAFT'
  end

  return state:upper()
end

---@param state string
---@return string
function M.format_review_state(state)
  return REVIEW_STATE_LABELS[state] or state
end

---Get reaction icon for emoji name
---@param emoji string
---@return string
function M.get_reaction_icon(emoji)
  return emoji:lower()
end

return M

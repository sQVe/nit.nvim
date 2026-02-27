---@class Nit.Api.Result<T>
---@field ok boolean
---@field data? T
---@field error? string

---@alias Nit.Api.FilePath string
---@alias Nit.Api.ThreadId string
---@alias Nit.Api.CommentId integer
---@alias Nit.Api.LineNumber integer
---@alias Nit.Api.Timestamp string
---@alias Nit.Api.PrNumber integer

---@class Nit.Api.User
---@field login string
---@field name? string

---@class Nit.Api.Label
---@field name string
---@field color string
---@field description? string

---@alias Nit.Api.ReviewerState 'PENDING'|'APPROVED'|'CHANGES_REQUESTED'|'COMMENTED'|'DISMISSED'

---@class Nit.Api.Reviewer
---@field login string
---@field state Nit.Api.ReviewerState

---@alias Nit.Api.Reactions table<string, integer>

---@alias Nit.Api.PrStateRaw 'OPEN'|'CLOSED'|'MERGED'
---@alias Nit.Api.PrState 'open'|'closed'|'merged'
---@alias Nit.Api.MergeableState 'clean'|'dirty'|'unknown'
---@alias Nit.Api.FileStatus 'added'|'modified'|'removed'|'renamed'
---@alias Nit.Api.CommentSide 'LEFT'|'RIGHT'

---@class Nit.Api.IssueComment
---@field id Nit.Api.CommentId
---@field author Nit.Api.User
---@field body string
---@field createdAt Nit.Api.Timestamp ISO 8601 timestamp
---@field reactions Nit.Api.Reactions

---@class Nit.Api.PR
---@field number Nit.Api.PrNumber
---@field title string
---@field state Nit.Api.PrState
---@field author Nit.Api.User
---@field body? string
---@field createdAt Nit.Api.Timestamp ISO 8601 timestamp
---@field updatedAt Nit.Api.Timestamp ISO 8601 timestamp
---@field mergeable Nit.Api.MergeableState
---@field isDraft boolean
---@field headRefName? string
---@field baseRefName? string
---@field labels Nit.Api.Label[]
---@field assignees Nit.Api.User[]
---@field reviewers Nit.Api.Reviewer[]
---@field comments Nit.Api.IssueComment[]

---@class Nit.Api.File
---@field filename Nit.Api.FilePath
---@field status Nit.Api.FileStatus
---@field additions integer
---@field deletions integer

---@class Nit.Api.Comment
---@field id Nit.Api.CommentId
---@field node_id string? GraphQL node ID (e.g. PRRC_kwDO...)
---@field author Nit.Api.User
---@field body string
---@field createdAt Nit.Api.Timestamp ISO 8601 timestamp
---@field path Nit.Api.FilePath?
---@field line Nit.Api.LineNumber?
---@field side Nit.Api.CommentSide?
---@field start_line Nit.Api.LineNumber?
---@field start_side Nit.Api.CommentSide?
---@field _optimistic_id string? Temporary marker for optimistic updates

---@class Nit.Api.Thread
---@field id Nit.Api.ThreadId
---@field comments Nit.Api.Comment[]
---@field isResolved boolean
---@field isOutdated boolean
---@field path Nit.Api.FilePath?
---@field line Nit.Api.LineNumber?
---@field side Nit.Api.CommentSide?
---@field start_line Nit.Api.LineNumber?
---@field start_side Nit.Api.CommentSide?

---@class Nit.Api.RequestOpts
---@field timeout? integer Timeout in milliseconds (default: 10000)
---@field retry? integer Number of retry attempts (default: 2)

return {}

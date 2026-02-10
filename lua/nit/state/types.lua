---@class Nit.State.PendingComment
---@field id integer Unique identifier
---@field path Nit.Api.FilePath File path
---@field line Nit.Api.LineNumber Line number
---@field side Nit.Api.CommentSide Diff side
---@field body string Comment body
---@field created_at Nit.Api.Timestamp ISO 8601 timestamp

---@class Nit.State.Data
---@field pr Nit.Api.PR? Current PR
---@field files_by_path table<Nit.Api.FilePath, Nit.Api.File> Files indexed by path
---@field threads_by_id table<Nit.Api.ThreadId, Nit.Api.Thread> Threads indexed by ID
---@field comments Nit.Api.IssueComment[] PR-level conversation comments
---@field loading boolean Loading state
---@field error string? Error message

---@class Nit.State.Indexes
---@field threads_by_file table<Nit.Api.FilePath, Nit.Api.ThreadId[]> Thread IDs by file path

return {}

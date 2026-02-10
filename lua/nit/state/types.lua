---@class Nit.State.PendingComment
---@field id integer Unique identifier
---@field path string File path
---@field line integer Line number
---@field side 'LEFT'|'RIGHT' Diff side
---@field body string Comment body
---@field created_at string ISO 8601 timestamp

---@class Nit.State.Data
---@field pr Nit.Api.PR? Current PR
---@field files_by_path table<string, Nit.Api.File> Files indexed by path
---@field threads_by_id table<string, Nit.Api.Thread> Threads indexed by ID
---@field comments Nit.Api.IssueComment[]? PR-level conversation comments
---@field loading boolean Loading state
---@field error string? Error message

---@class Nit.State.Indexes
---@field threads_by_file table<string, string[]> Thread IDs by file path

return {}

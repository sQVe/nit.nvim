---@class Nit.Api.Result<T>
---@field ok boolean
---@field data? T
---@field error? string

---@class Nit.Api.User
---@field login string
---@field name? string

---@class Nit.Api.PR
---@field number integer
---@field title string
---@field state 'open'|'closed'|'merged'
---@field author Nit.Api.User
---@field body? string
---@field createdAt string ISO 8601 timestamp
---@field updatedAt string ISO 8601 timestamp
---@field mergeable 'clean'|'dirty'|'unknown'
---@field isDraft boolean

---@class Nit.Api.File
---@field filename string
---@field status 'added'|'modified'|'removed'|'renamed'
---@field additions integer
---@field deletions integer

---@class Nit.Api.Comment
---@field id integer
---@field author Nit.Api.User
---@field body string
---@field createdAt string ISO 8601 timestamp
---@field path string?
---@field line integer?
---@field side 'LEFT'|'RIGHT'?

---@class Nit.Api.Thread
---@field id integer
---@field comments Nit.Api.Comment[]
---@field isResolved boolean
---@field path string?
---@field line integer?
---@field side 'LEFT'|'RIGHT'?

---@class Nit.Api.RequestOpts
---@field timeout? integer Timeout in milliseconds (default: 10000)
---@field retry? integer Number of retry attempts (default: 2)

return {}

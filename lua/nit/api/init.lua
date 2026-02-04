local M = {}

local pr = require('nit.api.pr')
local files = require('nit.api.files')
local comments = require('nit.api.comments')
local parallel = require('nit.api.parallel')
local tracker = require('nit.api.tracker')

M.fetch_pr = pr.fetch_pr
M.fetch_files = files.fetch_files
M.fetch_diff = files.fetch_diff
M.fetch_comments = comments.fetch_comments
M.parallel = parallel.parallel
M.cancel_all = tracker.cancel_all

return M

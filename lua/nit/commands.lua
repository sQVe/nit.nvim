local M = {}

---@class Nit.Subcommand
---@field impl fun(args: string[], opts: table)
---@field complete? fun(subcmd_arg_lead: string): string[]

---@type table<string, Nit.Subcommand>
local subcommands = {
  healthcheck = {
    impl = function(_args, _opts)
      vim.cmd('checkhealth nit')
    end,
  },
}

---@param opts table Command options from nvim_create_user_command
function M.dispatch(opts)
  local fargs = opts.fargs
  local subcmd_key = fargs[1]

  if not subcmd_key then
    local keys = vim.tbl_keys(subcommands)
    table.sort(keys)
    vim.notify('Nit subcommands: ' .. table.concat(keys, ', '), vim.log.levels.INFO)
    return
  end

  local args = vim.list_slice(fargs, 2)
  local subcmd = subcommands[subcmd_key]
  if subcmd then
    subcmd.impl(args, opts)
  else
    vim.notify('Unknown subcommand: ' .. subcmd_key, vim.log.levels.ERROR)
  end
end

---@param arg_lead string Current argument being completed
---@param cmdline string Full command line (may have visual range prefix like '<,'>)
---@param _cursor_pos number Cursor position (unused)
---@return string[]
function M.complete(arg_lead, cmdline, _cursor_pos)
  local subcmd_key, subcmd_arg_lead = cmdline:match("^[',<>]*Nit[!]*%s(%S+)%s(.*)$")
  if subcmd_key and subcmd_arg_lead and subcommands[subcmd_key] and subcommands[subcmd_key].complete then
    return subcommands[subcmd_key].complete(subcmd_arg_lead)
  end

  if cmdline:match("^[',<>]*Nit[!]*%s+%w*$") then
    local keys = vim.tbl_keys(subcommands)
    table.sort(keys)
    if arg_lead ~= '' then
      return vim.tbl_filter(function(key)
        return key:find(arg_lead, 1, true) == 1
      end, keys)
    end
    return keys
  end

  return {}
end

return M

local M = {}
local api = vim.api

function M.echo_warning(msg)
  api.nvim_command('echohl WarningMsg')
  api.nvim_command("echom '[SidebarNvim] "..msg:gsub("'", "''").."'")
  api.nvim_command('echohl None')
end

function M.sidebar_nvim_callback(callback_name)
  return string.format(":lua require('sidebar-nvim').on_keypress('%s')<CR>", callback_name)
end

return M

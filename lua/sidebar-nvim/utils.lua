local M = {}
local api = vim.api

function M.echo_warning(msg)
  api.nvim_command('echohl WarningMsg')
  api.nvim_command("echom '[SidebarNvim] "..msg:gsub("'", "''").."'")
  api.nvim_command('echohl None')
end

function M.sidebar_nvim_callback(key)
  -- TODO: we need to escape key
  return string.format(":lua require('sidebar-nvim').on_keypress('%s')<CR>", key)
end

local function get_builtin_section(name)
  local ret, section = pcall(require, "sidebar-nvim.builtin."..name)
  if not ret then
    M.echo_warning("invalid builtin section: "..name)
    return nil
  end

  return section
end

function M.resolve_section(index, section)
  if type(section) == "string" then
    return get_builtin_section(section)
  elseif type(section) == "table" then
    return section
  end

  M.echo_warning("invalid SidebarNvim section at: index=" .. index .. " section=" .. section)
  return nil
end


return M

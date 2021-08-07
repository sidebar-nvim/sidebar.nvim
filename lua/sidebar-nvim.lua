local lib = require('sidebar-nvim.lib')
local colors = require('sidebar-nvim.colors')
local renderer = require('sidebar-nvim.renderer')
local view = require('sidebar-nvim.view')
local updater = require('sidebar-nvim.updater')

local api = vim.api

vim.g.sidebar_nvim_auto_open = vim.g.sidebar_nvim_auto_open or 0
vim.g.sidebar_nvim_auto_resize = vim.g.sidebar_nvim_auto_resize or 0
vim.g.sidebar_nvim_disable_default_keybindings = vim.g.sidebar_nvim_disable_default_keybindings or 0
vim.g.sidebar_nvim_bindings = vim.g.sidebar_nvim_bindings or nil
vim.g.sidebar_nvim_side = vim.g.sidebar_nvim_side or 'left'
vim.g.sidebar_nvim_width = vim.g.sidebar_nvim_width or 50

vim.g.sidebar_nvim_update_interval = vim.g.sidebar_nvim_update_interval or 1000

vim.g.sidebar_nvim_sections = vim.g.sidebar_nvim_sections or {"datetime"}

local M = {}

function M.toggle()
  if view.win_open() then
    view.close()
  else
    lib.open()
  end
end

function M.close()
  if view.win_open() then
    view.close()
    return true
  end
end

function M.open()
  if not view.win_open() then
    lib.open()
  else
    lib.set_target_win()
  end
end

function M.tab_change()
  vim.schedule(function()
    if not view.win_open() and view.win_open({ any_tabpage = true }) then
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname:match("Neogit") ~= nil or bufname:match("--graph") ~= nil then
        return
      end
      view.open({ focus_tree = false })
    end
  end)
end

local keypress_funcs = {
  toggle_help = lib.toggle_help,
  update = lib.update,
  close = function() M.close() end,
}

function M.on_keypress(mode)
  if view.is_help_ui() and mode ~= 'toggle_help' then return end
  local section = lib.get_section_at_cursor()

  if keypress_funcs[mode] then
    return keypress_funcs[mode](section)
  end
end

function M.update()
  lib.update()
end

function M.on_enter()
  local should_open = vim.g.sidebar_nvim_auto_open == 1
  updater.setup()
  lib.init(should_open)
end

function M.resize(size)
  view.View.width = size
  view.resize()
end

function M.on_leave()
  vim.defer_fn(function()
    if not view.win_open() then
      return
    end

    local windows = api.nvim_list_wins()
    local curtab = api.nvim_get_current_tabpage()
    local wins_in_tabpage = vim.tbl_filter(function(w)
      return api.nvim_win_get_tabpage(w) == curtab
    end, windows)
    if #windows == 1 then
      api.nvim_command(':silent qa!')
    elseif #wins_in_tabpage == 1 then
      api.nvim_command(':tabclose')
    end
  end, 50)
end

function M.reset_highlight()
  colors.setup()
  renderer.render_hl(view.View.bufnr)
end

function M.place_cursor_on_section()
  local section = lib.get_section_at_cursor()
  local line = api.nvim_get_current_line()
  local cursor = api.nvim_win_get_cursor(0)
  local idx = vim.fn.stridx(line, section.name)
  api.nvim_win_set_cursor(0, {cursor[1], idx})
end

view.setup()
colors.setup()
vim.defer_fn(M.on_enter, 1)

return M

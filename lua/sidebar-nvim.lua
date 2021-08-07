local luv = vim.loop
local lib = require('sidebar-nvim.lib')
local colors = require('sidebar-nvim.colors')
local renderer = require('sidebar-nvim.renderer')
local utils = require('sidebar-nvim.utils')
local view = require('sidebar-nvim.view')

local api = vim.api

local M = {}

function M.toggle()
  if view.win_open() then
    view.close()
  else
    if vim.g.sidebar_nvim_follow == 1 then
      M.find_file(true)
    end
    if not view.win_open() then
      lib.open()
    end
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
  refresh = lib.refresh,
  close = function() M.close() end,
}

function M.on_keypress(mode)
  if view.is_help_ui() and mode ~= 'toggle_help' then return end
  local section = lib.get_section_at_cursor()

  if keypress_funcs[mode] then
    return keypress_funcs[mode](section)
  end
end

function M.refresh()
  lib.refresh()
end

function M.on_enter()
  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)
  local buftype = api.nvim_buf_get_option(bufnr, 'filetype')
  local ft_ignore = vim.g.sidebar_nvim_auto_ignore_ft or {}

  local should_open = vim.g.sidebar_nvim_auto_open == 1 and not vim.tbl_contains(ft_ignore, buftype)
  lib.init(should_open, should_open)
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

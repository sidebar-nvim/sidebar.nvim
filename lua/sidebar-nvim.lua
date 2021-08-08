local lib = require('sidebar-nvim.lib')
local colors = require('sidebar-nvim.colors')
local renderer = require('sidebar-nvim.renderer')
local view = require('sidebar-nvim.view')
local updater = require('sidebar-nvim.updater')
local config = require("sidebar-nvim.config")

local api = vim.api

local M = {}

local open_after_session = false

vim.g.sidebar_nvim_sections = vim.g.sidebar_nvim_sections or {
  "datetime",
  "git-status",
  "lsp-diagnostics",
}

function M.setup(opts)
  opts = opts or {}

  for key, value in pairs(opts) do
    config[key] = value
  end

  view._wipe_rogue_buffer()

  colors.setup()
  view.setup()

  updater.setup()
  lib.init()
end

function M._session_post()
  view._wipe_rogue_buffer()

  if open_after_session then
    open_after_session = false
    M._internal_open()
  end
end

function M._vim_leave()
  lib.destroy()
end

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

function M._internal_open(opts)
  if not view.win_open() then
    lib.open(opts)
  end
end

function M.open()
  open_after_session = true

  -- open with whatever finishes first, this timeout or session post au
  vim.defer_fn(function()
    M._internal_open()
  end, 200)
end

function M.tab_change()
  vim.schedule(function()
    if not view.win_open() and view.win_open({ any_tabpage = true }) then
      local bufname = vim.api.nvim_buf_get_name(0)
      if bufname:match("Neogit") ~= nil or bufname:match("--graph") ~= nil then
        return
      end
      view.open({ focus = false })
    end
  end)
end

local keypress_funcs = {
  update = lib.update,
  close = function() M.close() end,
}

function M.on_keypress(mode)
  -- TODO: get_section_at_cursor not implemented
  --local section = lib.get_section_at_cursor()

  if keypress_funcs[mode] then
    return keypress_funcs[mode]()
  end
end

function M.update()
  lib.update()
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




return M

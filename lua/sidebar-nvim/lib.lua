local api = vim.api
local luv = vim.loop

local renderer = require('sidebar-nvim.renderer')
local view = require('sidebar-nvim.view')
local events = require('sidebar-nvim.events')
local updater = require('sidebar-nvim.updater')

local first_init_done = false

local M = {}

M.State = {}

M.timer = nil

local function _redraw()
  if vim.v.exiting ~= vim.NIL then return end

  if view.win_open() then
    renderer.draw(updater.sections_data)
  end
end

local function loop()
  updater.update()
  _redraw()
end

local function _start_timer(should_delay)
  M.timer = luv.new_timer()

  local delay = 100
  if should_delay then
    delay = vim.g.sidebar_nvim_update_interval
  end

  -- wait `delay`ms and then repeats every `vim.g.sidebar_nvim_update_interval`ms
  M.timer:start(delay, vim.g.sidebar_nvim_update_interval, vim.schedule_wrap(function()
    loop()
  end))
end

function M.init(should_open)
  if should_open then
    M.open()
  end

  _redraw()

  _start_timer(false)

  if not first_init_done then
    events._dispatch_ready()
    first_init_done = true
  end
end

function M.update()
  M.timer:stop()
  M.timer = nil

  loop()

  _start_timer(true)
end

local function get_section_at_line(line)
  -- TODO: not implemented
  return nil
end

function M.get_section_at_cursor()
  local cursor = api.nvim_win_get_cursor(view.get_winnr())
  local line = cursor[1]
  if view.is_help_ui() then
    local help_lines, _ = renderer.draw_help()
    local help_text = get_section_at_line(line+1)(help_lines)
    return {name = help_text}
  else
    -- TODO: sections!
    return nil
  end
end

function M.open()
  view.open()
end

function M.toggle_help()
  view.toggle_help()
  return _redraw()
end

return M

local luv = vim.loop
local api = vim.api

local renderer = require('sidebar-nvim.renderer')
local view = require('sidebar-nvim.view')
local events = require('sidebar-nvim.events')
local updater = require('sidebar-nvim.updater')
local config = require('sidebar-nvim.config')

local first_init_done = false

local M = {}

M.State = {
  section_line_indexes = {}
}

M.timer = nil

local function _redraw()
  if vim.v.exiting ~= vim.NIL then return end

  if view.win_open() then
    M.State.section_line_indexes = renderer.draw(updater.sections_data)
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
    delay = config.update_interval
  end

  -- wait `delay`ms and then repeats every `config.update_interval`ms
  M.timer:start(delay, config.update_interval, vim.schedule_wrap(function()
    loop()
  end))
end

function M.init()
  _redraw()

  _start_timer(false)

  if not first_init_done then
    events._dispatch_ready()
    first_init_done = true
  end
end

function M.update()
  if M.timer ~= nil then
    M.timer:stop()
    M.timer:close()
    M.timer = nil
  end

  loop()

  _start_timer(true)
end

function M.open(opts)
  view.open(opts or { focus = false })
end

function M.destroy()
  view.close()

  M.timer:stop()
  M.timer:close()
  M.timer = nil

  view._wipe_rogue_buffer()
end

function M.get_section_at_cursor()
  local cursor = api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]

  for section_index, section_line_index in ipairs(M.State.section_line_indexes) do
    -- check if the start of this section is after the cursor line
    if cursor_line < section_line_index then
      return config.sections[section_index - 1]
    end
  end

  return nil
end

return M

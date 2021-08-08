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
  if M.timer ~= nil then
    M.timer:stop()
    M.timer:close()
    M.timer = nil
  end

  loop()

  _start_timer(true)
end

function M.open()
  view.open()
end

return M

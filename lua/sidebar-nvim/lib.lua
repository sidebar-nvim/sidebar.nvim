local luv = vim.loop
local api = vim.api

local renderer = require('sidebar-nvim.renderer')
local view = require('sidebar-nvim.view')
local events = require('sidebar-nvim.events')
local updater = require('sidebar-nvim.updater')
local config = require('sidebar-nvim.config')
local bindings = require('sidebar-nvim.bindings')
local utils = require('sidebar-nvim.utils')

local first_init_done = false

local M = {}

M.State = {
  section_line_indexes = {},
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

function M.setup()
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

local function get_start_line(content_only, indexes)
  if content_only then
    return indexes.content_start
  end

  return indexes.section_start
end

local function get_end_line(content_only, indexes)
  if content_only then
    return indexes.content_start + indexes.content_length
  end

  return indexes.section_start + indexes.section_length - 1
end

-- @param opts: table
-- @param opts.content_only: boolean = whether the it should only check if the cursor is hovering the contents of the section
-- @return table{section_index = number, section_content_current_line = number, cursor_col = number, cursor_line = number)
function M.find_section_at_cursor(opts)
  opts = opts or {content_only = true}

  local cursor = api.nvim_win_get_cursor(0)
  local cursor_line = cursor[1]
  local cursor_col = cursor[2]

  for section_index, section_line_index in ipairs(M.State.section_line_indexes) do
    local start_line = get_start_line(opts.content_only, section_line_index)
    local end_line = get_end_line(opts.content_only, section_line_index)
    -- check if the start of this section is after the cursor line

    if cursor_line >= start_line and cursor_line <= end_line then
      return {
        section_index = section_index,
        section_content_current_line = cursor_line - section_line_index.content_start,
        cursor_line = cursor_line,
        cursor_col= cursor_col,
      }
    end
  end

  return nil
end

function M.on_keypress(key)
  local section_match = M.find_section_at_cursor()
  bindings.on_keypress(utils.unescape_keycode(key), section_match)
end

return M

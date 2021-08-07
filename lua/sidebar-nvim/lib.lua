local api = vim.api
local luv = vim.loop

local renderer = require'sidebar-nvim.renderer'
local utils = require'sidebar-nvim.utils'
local view = require'sidebar-nvim.view'
local events = require'sidebar-nvim.events'

local first_init_done = false

local M = {}

M.State = {
  sections = {},
  loaded = false,
}

function M.init(with_open, with_reload)
  if with_open then
    M.open()
  elseif view.win_open() then
    M.refresh()
  end

  if with_reload then
    M.redraw()
    M.State.loaded = true
  end

  if not first_init_done then
    events._dispatch_ready()
    first_init_done = true
  end
end

function M.redraw()
  renderer.draw(M.State, true)
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

-- this variable is used to bufferize the refresh actions
-- so only one happens every second at most
local refreshing = false

function M.refresh()
  if refreshing or vim.v.exiting ~= vim.NIL then return end
  refreshing = true

  -- TODO: update sections

  if view.win_open() then
    renderer.draw(M.State, true)
  else
    M.State.loaded = false
  end

  vim.defer_fn(function() refreshing = false end, 1000)
end

function M.open()
  view.open()

  renderer.draw(M.State, not M.State.loaded)
  M.State.loaded = true
end

function M.toggle_help()
  view.toggle_help()
  return M.refresh()
end

return M

local view = require('sidebar-nvim.view')

local api = vim.api

local lines = {}
local hl = {}
local namespace_id = api.nvim_create_namespace('SidebarNvimHighlights')

local M = {}

local function expand_section_lines(section_lines)
  if type(section_lines) == "string" then
    return {section_lines}
  end

  return section_lines
end

local function build_section_title(title, section)
  return "# "..title
end

local function build_section_separator(title, section)
  return "-----"
end

local function get_lines_and_hl(sections_data)
  lines = {}
  hl = {}

  for section_name, section_lines in pairs(sections_data) do
    local section_title = build_section_title(section_name, section_lines)

    table.insert(hl, {'SidebarNvimSectionTitle', #lines, 0, #section_title})

    table.insert(lines, section_title)
    for _, line in ipairs(expand_section_lines(section_lines)) do
      table.insert(lines, line)
    end

    local separator = build_section_separator(title, section_lines)

    table.insert(hl, {"SidebarNvimSectionSeperator", #lines+1, 0, #separator})
    table.insert(lines, "")
    table.insert(lines, separator)
    table.insert(lines, "")
  end

  return lines, hl
end

function M.draw(sections_data)
  if not api.nvim_buf_is_loaded(view.View.bufnr) then return end

  local cursor
  if view.win_open() then
    cursor = api.nvim_win_get_cursor(view.get_winnr())
  end

  lines, hl = get_lines_and_hl(sections_data)

  api.nvim_buf_set_option(view.View.bufnr, 'modifiable', true)
  api.nvim_buf_set_lines(view.View.bufnr, 0, -1, false, lines)
  M.render_hl(view.View.bufnr)
  api.nvim_buf_set_option(view.View.bufnr, 'modifiable', false)

  if cursor and #lines >= cursor[1] then
    api.nvim_win_set_cursor(view.get_winnr(), cursor)
  end
  if cursor then
    api.nvim_win_set_option(view.get_winnr(), 'wrap', false)
  end
end

function M.render_hl(bufnr)
  if not api.nvim_buf_is_loaded(bufnr) then return end
  api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
  for _, data in ipairs(hl) do
    api.nvim_buf_add_highlight(bufnr, namespace_id, data[1], data[2], data[3], data[4])
  end
end

return M

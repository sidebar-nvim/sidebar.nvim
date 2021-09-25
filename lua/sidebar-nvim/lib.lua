local luv = vim.loop
local api = vim.api

local renderer = require("sidebar-nvim.renderer")
local view = require("sidebar-nvim.view")
local events = require("sidebar-nvim.events")
local updater = require("sidebar-nvim.updater")
local config = require("sidebar-nvim.config")
local bindings = require("sidebar-nvim.bindings")
local utils = require("sidebar-nvim.utils")

local first_init_done = false

local M = {}

M.State = { section_line_indexes = {} }

M.timer = nil

local function _redraw()
    if vim.v.exiting ~= vim.NIL then
        return
    end

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
    M.timer:start(
        delay,
        config.update_interval,
        vim.schedule_wrap(function()
            loop()
        end)
    )
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
    opts = opts or { content_only = true }

    local cursor = opts.cursor or api.nvim_win_get_cursor(0)
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
                cursor_col = cursor_col,
                line_index = section_line_index,
            }
        end
    end

    return nil
end

function M.on_keypress(key)
    local section_match = M.find_section_at_cursor()
    bindings.on_keypress(utils.unescape_keycode(key), section_match)
end

function M.on_cursor_move(direction)
    local cursor = api.nvim_win_get_cursor(0)
    local line = cursor[1]

    local current_section = M.find_section_at_cursor({ content_only = false })

    if not current_section then
        current_section = M.find_section_at_cursor({ content_only = false, cursor = { 1, 1 } })
    end

    local current_section_index = current_section.section_index
    local current_line_index = current_section.line_index

    local next_line = line + 1
    if direction == "up" then
        next_line = line - 1
    end

    if direction == "down" then
        if next_line > current_line_index.section_start and next_line < current_line_index.content_start then
            next_line = current_line_index.content_start
        elseif next_line >= current_line_index.content_start + current_line_index.content_length then
            local next_section = M.State.section_line_indexes[current_section_index + 1]
            if not next_section then
                return
            end
            next_line = next_section.section_start
        end
    else
        if next_line < current_line_index.section_start then
            local next_section = M.State.section_line_indexes[current_section_index - 1]
            if not next_section then
                return
            end
            next_line = next_section.content_start + next_section.content_length - 1
        elseif next_line < current_line_index.content_start and next_line > current_line_index.section_start then
            next_line = current_line_index.section_start
        end
    end

    api.nvim_win_set_cursor(0, { next_line, 1 })
end

return M

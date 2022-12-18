local logger = require("sidebar-nvim.logger")
local view = require("sidebar-nvim.view")
local config = require("sidebar-nvim.config")
local profile = require("sidebar-nvim.profile")
local pasync = require("sidebar-nvim.lib.async")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local state = require("sidebar-nvim.state")

local api = pasync.api

local M = {
    hl_namespace_id = nil,
    extmarks_namespace_id = nil,
    -- these are also extmarks, but used for storing location of each callback
    keybindings_namespace_id = nil,

    -- tab -> key -> extmarks id -> cb
    -- TODO: continue here
    keybindings_map = {},
}

function M.setup()
    M.hl_namespace_id = api.nvim_create_namespace("SidebarNvimHighlights")
    M.extmarks_namespace_id = api.nvim_create_namespace("SidebarNvimExtmarks")
    M.keybindings_namespace_id = api.nvim_create_namespace("SidebarNvimExtmarksKeybindings")
end

function M.clear()
    -- TODO: delete extmarks?
end

-- @private
local function get_extmark_by_id(id)
    local mark = api.nvim_buf_get_extmark_by_id(view.View.bufnr, M.extmarks_namespace_id, id, { details = true })
    local row, col, details = mark[1], mark[2], mark[3]

    if details then
        details.start_row = row
        details.start_col = col
    end

    return details
end

-- @private
local function get_last_extmark(tab_name)
    local id = nil

    for i, section in ipairs(state.tabs[tab_name] or {}) do
        if section.state.extmark_id then
            id = section.state.extmark_id
            break
        end
    end

    if not id then
        return nil
    end

    return get_extmark_by_id(id)
end

function M.draw_section(changes, max_width, tab_name, section_index, section, data)
    -- TODO: we're passing section index everywhere, maybe it's time for a log span thing (tracing)
    logger:debug("drawing section", { tab_name = tab_name, section_index = section_index })

    local start_row = 0

    if section.state.extmark_id then
        local extmark = get_extmark_by_id(section.state.extmark_id)
        if extmark then
            start_row = extmark.start_row
        else
            logger:error("error trying to find extmark", {
                namespace_id = M.extmarks_namespace_id,
                extmark = "not found",
                section_index = section_index,
                id = section.state.extmark_id or "invalid section extmark id",
                start_row = start_row,
            })
        end
    -- get the last known position in the buffer
    else
        local last_extmark = get_last_extmark(tab_name)
        if last_extmark then
            start_row = last_extmark.end_row
        end
    end

    local end_row = start_row + #data

    local lines = {}
    local hls = {}
    local keybindings = {}

    for _, line in ipairs(data) do
        local current_line, current_hl = LineBuilder.build_from_table(line, max_width)

        table.insert(lines, current_line)
        table.insert(hls, current_hl)
        table.insert(keybindings, line.keybindings)
    end

    local change = {
        start_row = start_row,
        end_row = end_row,
        lines = lines,
        hls = hls,
        section = section,
        keybindings = keybindings,
    }
    table.insert(changes, change)
end

function M.draw(tab_name, section_index, section, data)
    return profile.run("view.render", function()
        if not api.nvim_buf_is_loaded(view.View.bufnr) then
            return
        end

        local cursor
        if view.is_win_open() then
            cursor = api.nvim_win_get_cursor(view.get_winnr())
        end

        local max_width = view.get_width()

        local changes = {}

        M.draw_section(changes, max_width, tab_name, section_index, section, data)

        api.nvim_buf_set_option(view.View.bufnr, "modifiable", true)
        for _, change in ipairs(changes) do
            api.nvim_buf_set_lines(view.View.bufnr, change.start_row, change.end_row, false, change.lines)

            section.state.extmark_id =
                api.nvim_buf_set_extmark(view.View.bufnr, M.extmarks_namespace_id, change.start_row, 0, {
                    id = section.state.extmark_id,
                    end_row = change.end_row,
                    end_col = 0,
                    ephemeral = false,
                })

            M.render_hl(view.View.bufnr, change.hls, change.start_row, change.end_row)
            M.attach_keybindings(change.section, view.View.bufnr, change.keybindings, change.start_row, change.end_row)
        end
        api.nvim_buf_set_option(view.View.bufnr, "modifiable", false)

        if view.is_win_open() then
            -- TODO: do we still need this?
            -- if cursor and #lines >= cursor[1] then
            --     api.nvim_win_set_cursor(view.get_winnr(), cursor)
            -- end
            if cursor then
                api.nvim_win_set_option(view.get_winnr(), "wrap", false)
            end

            if config.hide_statusline then
                api.nvim_win_set_option(view.get_winnr(), "statusline", "%#NonText#")
            end
        end

        M.invalidated = false
    end)
end

function M.render_hl(bufnr, hls, start_row, end_row)
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end
    api.nvim_buf_clear_namespace(bufnr, M.hl_namespace_id, start_row, end_row)

    for line_offset, line_hls in ipairs(hls) do
        for _, hl in ipairs(line_hls) do
            api.nvim_buf_add_highlight(
                bufnr,
                M.hl_namespace_id,
                hl.group,
                start_row + line_offset - 1,
                hl.start_col,
                hl.start_col + hl.length
            )
        end
    end
end

function M.attach_keybindings(section, bufnr, keybindings, start_row, end_row)
    if not api.nvim_buf_is_loaded(bufnr) then
        return
    end
    api.nvim_buf_clear_namespace(bufnr, M.keybindings_namespace_id, start_row, end_row)

    section.state.keybinding_extmark_map = {}

    for line_offset, line_kbs in ipairs(keybindings) do
        for key, cb in ipairs(line_kbs) do
            local line_index = start_row + line_offset - 1
            local extmark_id = api.nvim_buf_set_extmark(view.View.bufnr, M.keybindings_namespace_id, line_index, 0, {})

            section.state.keybinding_extmark_map[extmark_id] = cb

            vim.keymap.set("n", key, function()
                -- TODO: get all extmarks under cursor using extmarks_namespace_id
                -- TODO: iterate over the list of sections and see
            end, { buffer = view.View.bufnr, silent = true, nowait = true })
        end
    end
end

return M

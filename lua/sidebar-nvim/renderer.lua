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
    keymaps_namespace_id = nil,

    -- tab -> section_extmark_id -> key -> extmarks id -> cb
    keymaps_map = {},
}

function M.setup()
    M.hl_namespace_id = api.nvim_create_namespace("SidebarNvimHighlights")
    M.extmarks_namespace_id = api.nvim_create_namespace("SidebarNvimExtmarks")
    M.keymaps_namespace_id = api.nvim_create_namespace("SidebarNvimExtmarksKeymaps")

    M.keymaps_map = {}
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
    local ids = vim.tbl_map(function(section)
        return section._internal_state.extmark_id
    end, state.tabs[tab_name])

    local id = #ids > 0 and ids[#ids] or nil

    if not id then
        return nil
    end

    return get_extmark_by_id(id)
end

function M.draw_section(max_width, tab_name, section_index, section, data)
    -- TODO: we're passing section index everywhere, maybe it's time for a log span thing (tracing)
    logger:debug("drawing section", { tab_name = tab_name, section_index = section_index })

    local start_row = 0
    -- we need this to make proper replacements and make neovim move things correctly
    -- otherwise it will just replace the next sections
    local previous_end_row = nil

    if section._internal_state.extmark_id then
        local extmark = get_extmark_by_id(section._internal_state.extmark_id)
        if extmark then
            start_row = extmark.start_row
            previous_end_row = extmark.end_row
        else
            logger:error("error trying to find extmark", {
                namespace_id = M.extmarks_namespace_id,
                extmark = "not found",
                section_index = section_index,
                id = section._internal_state.extmark_id or "invalid section extmark id",
                start_row = start_row,
            })
        end
    -- get the last known position in the buffer
    else
        local last_extmark = get_last_extmark(tab_name)
        if last_extmark then
            start_row = last_extmark.end_row + 1
        end

        -- since we don't have the old end_row yet, we calculate the initial end_row based on the length
        previous_end_row = start_row + #data - 1
    end

    local lines = {}
    local hls = {}
    local keymaps = {}

    for _, line in ipairs(data) do
        local current_line, current_hl = LineBuilder.build_from_table(line, max_width)

        table.insert(lines, current_line)
        table.insert(hls, current_hl)

        local current_keymaps = {}
        for key, cb in pairs(line.keymaps or {}) do
            table.insert(current_keymaps, { key = key, cb = cb, start_col = 0, length = #current_line })
        end

        table.insert(keymaps, current_keymaps)
    end

    local change = {
        start_row = start_row,
        previous_end_row = previous_end_row,
        end_row = start_row + #data - 1,
        lines = lines,
        hls = hls,
        keymaps = keymaps,
    }

    api.nvim_buf_set_option(view.View.bufnr, "modifiable", true)

    api.nvim_buf_set_lines(view.View.bufnr, change.start_row, change.previous_end_row + 1, false, change.lines)

    section._internal_state.extmark_id =
        api.nvim_buf_set_extmark(view.View.bufnr, M.extmarks_namespace_id, change.start_row, 0, {
            id = section._internal_state.extmark_id,
            end_row = change.end_row,
            end_col = 0,
            ephemeral = false,
        })

    M.render_hl(view.View.bufnr, change.hls, change.start_row, change.end_row)

    api.nvim_buf_clear_namespace(view.View.bufnr, M.keymaps_namespace_id, change.start_row, change.end_row)
    M.keymaps_map[tab_name] = M.keymaps_map[tab_name] or {}
    M.keymaps_map[tab_name][section._internal_state.extmark_id] = {}
    M.attach_change_keymaps(tab_name, section, view.View.bufnr, change.keymaps, change.start_row, change.end_row)
    M.attach_section_keymaps(tab_name, section, view.View.bufnr, change.start_row, change.end_row, 0, 0)

    api.nvim_buf_set_option(view.View.bufnr, "modifiable", false)
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

        M.draw_section(max_width, tab_name, section_index, section, data)

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

local function update_keymaps_map(tab_name, section, extmark_id, key, cb)
    M.keymaps_map[tab_name] = M.keymaps_map[tab_name] or {}
    M.keymaps_map[tab_name][section._internal_state.extmark_id] = M.keymaps_map[tab_name][section._internal_state.extmark_id]
        or {}
    M.keymaps_map[tab_name][section._internal_state.extmark_id][key] = M.keymaps_map[tab_name][section._internal_state.extmark_id][key]
        or {}

    M.keymaps_map[tab_name][section._internal_state.extmark_id][key][extmark_id] = { cb = cb, section = section }

    vim.keymap.set("n", key, function()
        local cursor = vim.api.nvim_win_get_cursor(0)

        local cursor_row = cursor[1]
        local cursor_col = cursor[2]

        -- NOTE: active_tab prob is not what we want here, we want the tab the cursor is currently on
        -- in fact not even sure we want the active_tab thing
        local section_extmark_ids = M.keymaps_map[state.active_tab][key]

        for _, known_ids in pairs(section_extmark_ids) do
            for id, kb in pairs(known_ids) do
                local extmark =
                    vim.api.nvim_buf_get_extmark_by_id(view.View.bufnr, M.keymaps_namespace_id, id, { details = true })

                -- remove old extmarks that no longer exists
                if extmark[1] == nil then
                    known_ids[id] = nil
                    goto continue
                end

                local start_row = extmark[1]
                local end_row = extmark[3].end_row or extmark[1]
                local start_col = extmark[2]
                local end_col = extmark[3].end_col or extmark[2]

                if
                    cursor_row >= start_row
                    and cursor_row <= end_row
                    and cursor_col >= start_col
                    and cursor_col <= end_col
                then
                    print(vim.inspect({
                        found = true,
                        cursor_row = cursor_row,
                        cursor_col = cursor_col,
                        start_row = start_row,
                        end_row = end_row,
                        start_col = start_col,
                        end_col = end_col,
                    }))

                    pasync.run(function()
                        kb.cb()
                        kb.section:invalidate()
                    end)
                end

                ::continue::
            end
        end
    end, { buffer = view.View.bufnr, silent = true, nowait = true, desc = "SidebarNvim section keybinding" })
end

function M.attach_change_keymaps(tab_name, section, bufnr, keymaps, start_row, end_row)
    for line_offset, line_kbs in ipairs(keymaps) do
        for _, kb in ipairs(line_kbs) do
            local line_index = start_row + line_offset - 1

            local extmark_id = api.nvim_buf_set_extmark(
                bufnr,
                M.keymaps_namespace_id,
                line_index,
                kb.start_col,
                -- NOTE: end_col = length?
                { end_col = kb.end_col, end_row = line_index }
            )

            update_keymaps_map(tab_name, section, extmark_id, kb.key, kb.cb)
        end
    end
end

function M.attach_section_keymaps(tab_name, section, bufnr, start_row, end_row, start_col, end_col)
    local keymaps = section:get_default_keymaps() or {}

    local extmark_id = api.nvim_buf_set_extmark(
        bufnr,
        M.keymaps_namespace_id,
        start_row,
        start_col,
        { end_col = end_col, end_row = end_row }
    )

    for key, cb in pairs(keymaps) do
        update_keymaps_map(tab_name, section, extmark_id, key, cb)
    end
end

return M

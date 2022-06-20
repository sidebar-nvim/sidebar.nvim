local utils = require("sidebar-nvim.utils")
local view = require("sidebar-nvim.view")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local loclist = Loclist:new({ omit_single_group = true })
local loclist_items = {}

local function get_fileicon(filename)
    if has_devicons and devicons.has_loaded() then
        local extension = filename:match("^.+%.(.+)$")

        local fileicon = ""
        local icon, _ = devicons.get_icon_color(filename, extension)
        if icon then
            fileicon = icon
        end

        local highlight = "SidebarNvimNormal"

        if extension then
            highlight = "DevIcon" .. extension
        end
        return { text = "  " .. fileicon .. " ", hl = highlight }
    else
        return { text = "   " }
    end
end

local function get_buffers(ctx)
    local lines = {}
    local hl = {}
    local current_buffer = vim.api.nvim_get_current_buf()
    loclist_items = {}

    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        if buffer ~= view.View.bufnr then
            local ignored = false
            local bufname = vim.api.nvim_buf_get_name(buffer)

            for _, ignored_buffer in ipairs(config.buffers.ignored_buffers or {}) do
                if string.match(bufname, ignored_buffer) then
                    ignored = true
                end
            end

            if bufname == "" then
                ignored = true
            end

            if config.buffers.ignore_not_loaded and not vim.api.nvim_buf_is_loaded(buffer) then
                ignored = true
            end

            -- NOTE: should we be more specific?
            if vim.api.nvim_buf_get_option(buffer, "bufhidden") ~= "" then
                ignored = true
            end

            -- always ignore terminals
            if config.buffers.ignore_terminal and string.match(bufname, "term://.*") then
                ignored = true
            end

            if not ignored then
                local name_hl = "SidebarNvimNormal"
                local modified = ""

                if buffer == current_buffer then
                    name_hl = "SidebarNvimBuffersActive"
                end

                if vim.api.nvim_buf_get_option(buffer, "modified") then
                    modified = " *"
                end

                -- sorting = "id"
                local order = buffer
                if config["buffers"].sorting == "name" then
                    order = bufname
                end

                local numbers_text = {}
                if config.buffers.show_numbers then
                    numbers_text = { text = buffer .. " ", hl = "SidebarNvimBuffersNumber" }
                end

                loclist_items[#loclist_items + 1] = {
                    group = "buffers",
                    left = {
                        get_fileicon(bufname),
                        numbers_text,
                        { text = utils.filename(bufname) .. modified, hl = name_hl },
                    },
                    data = { buffer = buffer, filepath = bufname },
                    order = order,
                }
            end
        end
    end

    loclist:set_items(loclist_items, { remove_groups = false })
    loclist:draw(ctx, lines, hl)

    if lines == nil or #lines == 0 then
        return "<no buffers>"
    else
        return { lines = lines, hl = hl }
    end
end

return {
    title = "Buffers",
    icon = config["buffers"].icon,
    draw = function(ctx)
        return get_buffers(ctx)
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimBuffersActive = "SidebarNvimSectionTitle",
            SidebarNvimBuffersNumber = "SIdebarnvimLineNr",
        },
    },
    bindings = {
        ["d"] = function(line)
            local location = loclist:get_location_at(line)

            if location == nil then
                return
            end

            local buffer = location.data.buffer
            local is_modified = vim.api.nvim_buf_get_option(buffer, "modified")

            if is_modified then
                local action = vim.fn.input(
                    'file "' .. location.data.filepath .. '" has been modified. [w]rite/[d]iscard/[c]ancel: '
                )

                if action == "w" then
                    vim.api.nvim_buf_call(buffer, function()
                        vim.cmd("silent! w")
                    end)
                    vim.api.nvim_buf_delete(buffer, { force = true })
                elseif action == "d" then
                    vim.api.nvim_buf_delete(buffer, { force = true })
                end
            else
                vim.api.nvim_buf_delete(buffer, { force = true })
            end
        end,
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            vim.cmd("wincmd p")
            vim.cmd("e " .. location.data.filepath)
        end,
        ["w"] = function(line)
            local location = loclist:get_location_at(line)

            if location == nil then
                return
            end

            vim.api.nvim_buf_call(location.data.buffer, function()
                vim.cmd("silent! w")
            end)
        end,
    },
}

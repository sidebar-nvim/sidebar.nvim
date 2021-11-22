local utils = require("sidebar-nvim.utils")
local view = require("sidebar-nvim.view")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local loclist = Loclist:new({ ommit_single_group = true })
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
        return { text = "  " .. fileicon, hl = highlight }
    else
        return { text = "  " }
    end
end

local function get_buffers(ctx)
    local lines = {}
    local hl = {}
    local current_buffer = vim.api.nvim_get_current_buf()
    loclist_items = {}

    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
        -- if buffer ~= view.View.bufnr and vim.api.nvim_buf_is_loaded(buffer) then
        if buffer ~= view.View.bufnr then
            local bufname = vim.api.nvim_buf_get_name(buffer)
            local name_hl = "SidebarNvimNormal"

            if buffer == current_buffer then
                name_hl = "SidebarNvimBuffersActive"
            end

            if bufname ~= "" and vim.api.nvim_buf_is_loaded(buffer) then
                loclist_items[#loclist_items + 1] = {
                    group = "buffers",
                    left = {
                        get_fileicon(bufname),
                        { text = " " .. utils.filename(bufname), hl = name_hl },
                    },
                    data = { filepath = bufname },
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
        },
    },
    bindings = {
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            vim.cmd("wincmd p")
            vim.cmd("e " .. location.data.filepath)
        end,
    },
}

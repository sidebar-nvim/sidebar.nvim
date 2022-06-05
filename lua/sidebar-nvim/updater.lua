local utils = require("sidebar-nvim.utils")
local utils_sections = require("sidebar-nvim.utils_sections")
local view = require("sidebar-nvim.view")
local config = require("sidebar-nvim.config")
local profile = require("sidebar-nvim.profile")
local colors = require("sidebar-nvim.colors")

local M = {}

-- list of sections rendered
-- { { lines = lines..., section = <table> }, { lines =  lines..., section = <table> } }
M.sections_data = {}

function M.setup()
    if config.sections == nil then
        return
    end

    local ctx = { width = view.get_width() }

    for section_index, section in utils_sections.section_iterator() do
        ctx.section_index = section_index
        if section then
            local hl_def = section.highlights or {}

            for hl_group, hl_group_data in pairs(hl_def.groups or {}) do
                colors.def_hl_group(hl_group, hl_group_data.gui, hl_group_data.fg, hl_group_data.bg)
            end

            for hl_group, hl_group_link_to in pairs(hl_def.links or {}) do
                colors.def_hl_link(hl_group, hl_group_link_to)
            end

            if section.setup then
                section.setup(ctx)
            end
        end
    end
end

function M.update()
    return profile.run("update.sections.total", function()
        if vim.v.exiting ~= vim.NIL then
            return
        end

        local ctx = { width = view.View.width }

        for section_index, section_data in pairs(config.sections) do
            local section = utils.resolve_section(section_index, section_data)

            if section ~= nil and section.update ~= nil then
                profile.run("update.sections." .. section_index, section.update, ctx)
            end
        end
    end)
end

function M.draw()
    return profile.run("draw.sections.total", function()
        if vim.v.exiting ~= vim.NIL then
            return
        end

        M.sections_data = {}

        local draw_ctx = { width = view.View.width }

        for section_index, section in utils_sections.section_iterator() do
            if section ~= nil then
                local section_lines = profile.run("draw.sections." .. section_index, section.draw, draw_ctx)
                local data = { lines = section_lines, section = section }
                table.insert(M.sections_data, data)
            end
        end
    end)
end

return M

local pasync = require("sidebar-nvim.lib.async")
local logger = require("sidebar-nvim.logger")
local utils = require("sidebar-nvim.utils")
local view = require("sidebar-nvim.view")
local config = require("sidebar-nvim.config")
local colors = require("sidebar-nvim.colors")
local state = require("sidebar-nvim.state")
local renderer = require("sidebar-nvim.renderer")

local api = pasync.api

local M = {
    _updates_listener_tx = nil,
}

-- @private
local function section_draw(tab_name, section_index, section, data)
    logger:debug("drawing section", { tab_name = tab_name, index = section_index })

    renderer.draw(tab_name, section_index, section, data)
end

-- @private
local function section_update(tab_name, section_index, section, logger_props, is_sync)
    local ctx = { width = view.get_width() }

    local ok, data = pcall(section.draw, section, ctx)
    if not ok then
        logger:error(
            data,
            vim.tbl_deep_extend("force", { tab_name = tab_name, section_index = section_index }, logger_props or {})
        )
        return
    end

    data = data or {}

    if is_sync then
        section_draw(tab_name, section_index, section, data)
    else
        M._updates_listener_tx.send({
            tab_name = tab_name,
            section_index = section_index,
            data = data,
            section = section,
        })
    end

    logger:debug("section update done", { tab_name = tab_name, section_index = section_index })
end

function M.setup()
    if config.sections == nil then
        return
    end

    logger:debug("starting all sections")

    local group_id = api.nvim_create_augroup("SidebarNvimSectionsReloaders", { clear = true })

    state.tabs = {}

    for tab_name, sections in pairs(config.sections) do
        local tab = {}
        state.tabs[tab_name] = tab
        for section_index, section_data in ipairs(sections) do
            local ok, section_or_err = pcall(utils.resolve_section, section_data)
            if not ok then
                error(section_or_err .. " " .. " index: " .. section_index .. " tab_name: " .. tab_name)
            end

            local section = section_or_err
            assert(section)

            local reloaders = section.reloaders or {}

            logger:debug(
                "starting section",
                { tab_name = tab_name, index = section_index, reloaders_count = #reloaders }
            )

            local hl_def = section.highlights or {}

            for hl_group, hl_group_data in pairs(hl_def.groups or {}) do
                colors.def_hl_group(hl_group, hl_group_data.gui, hl_group_data.fg, hl_group_data.bg)
            end

            for hl_group, hl_group_link_to in pairs(hl_def.links or {}) do
                colors.def_hl_link(hl_group, hl_group_link_to)
            end

            for _, reloader in ipairs(reloaders) do
                local cb = function()
                    pasync.run(function()
                        section_update(tab_name, section_index, section, { reloader = reloader })
                    end)
                end
                reloader(group_id, cb)
            end

            section.state.invalidate_cb = function()
                pasync.run(function()
                    section_update(tab_name, section_index, section, { requester = "user-invalidate" })
                end)
            end

            table.insert(tab, section)
        end
    end

    -- initial update
    M.update()

    M._start_updates_listener()
end

function M.update()
    if vim.v.exiting ~= vim.NIL then
        return
    end

    pasync.run(function()
        for tab_name, sections in pairs(state.tabs) do
            for section_index, section in ipairs(sections) do
                section_update(tab_name, section_index, section, {}, true)
            end
        end
    end)
end

function M._start_updates_listener()
    pasync.run(function()
        logger:debug("updates listener starting")
        local tx, rx = pasync.control.channel.mpsc()

        M._updates_listener_tx = tx

        while true do
            local ret = rx.recv()
            local tab_name = ret.tab_name
            local section_index = ret.section_index
            local data = ret.data
            local section = ret.section

            section_draw(tab_name, section_index, section, data)
        end
    end)
end

return M

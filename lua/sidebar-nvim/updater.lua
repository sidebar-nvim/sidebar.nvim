local pasync = require("plenary.async")
local logger = require("sidebar-nvim.logger")
local utils = require("sidebar-nvim.utils")
local view = require("sidebar-nvim.view")
local config = require("sidebar-nvim.config")
local colors = require("sidebar-nvim.colors")
local state = require("sidebar-nvim.state")

local M = {}

-- list of sections rendered
-- { { lines = lines..., section = <table> }, { lines =  lines..., section = <table> } }
M.sections_data = {}

M._updates_listener_tx = nil

local function section_update(tab_name, section_index, section, logger_props)
    local ctx = { width = view.get_width() }

    local ok, data = pcall(section.update, ctx)
    if not ok then
        logger:error(
            data,
            vim.tbl_deep_extend("force", { tab_name = tab_name, section_index = section_index }, logger_props or {})
        )
        return
    end

    data = data or {}

    M._updates_listener_tx.send({ tab_name = tab_name, data = data })
    logger:debug("section update done", { tab_name = tab_name, section_index = section_index })
end

function M.setup()
    if config.sections == nil then
        return
    end

    logger:debug("starting all sources", { source_count = #M.config.sources })

    local group_id = vim.api.nvim_create_augroup("SidebarNvimSectionsReloaders", { clear = true })

    for tab_name, sections in pairs(config.sections) do
        local tab = {}
        state.tabs[tab_name] = tab
        for section_index, section_data in ipairs(sections) do
            local ok, section_or_err = pcall(utils.resolve_section, section_data)
            if not ok then
                error(section_or_err .. " " .. " index: " .. section_index .. " tab_name: " .. tab_name)
            end

            local section = section_or_err

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
                local autocmd = vim.tbl_extend("force", reloader, {
                    group = group_id,
                    callback = function()
                        pasync.run(function()
                            section_update(tab_name, section_index, section, { reloader = reloader })
                        end)
                    end,
                })
                autocmd["event_name"] = nil
                vim.api.nvim_create_autocmd(reloader.event_name, autocmd)
            end

            table.insert(tab, section)
        end
    end

    M._start_updates_listener()
end

function M.update()
    if vim.v.exiting ~= vim.NIL then
        return
    end

    for tab_name, sections in pairs(state.tabs) do
        for section_index, section in ipairs(sections) do
            pasync.run(function()
                section_update(tab_name, section_index, section, {})
            end)
        end
    end
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

            logger:debug("updating section data", { tab_name = tab_name, index = section_index })

            M.sections_data[tab_name][section_index] = data
        end
    end)
end

return M

local async = require("sidebar-nvim.lib.async")
local colors = require("sidebar-nvim.colors")
local View = require("sidebar-nvim.lib.view")
local config = require("sidebar-nvim.config")
local logger = require("sidebar-nvim.logger")

local api = async.api

local M = {
    views = {},
}

function M.setup(opts)
    opts = opts or {}

    for key, value in pairs(opts) do
        config[key] = value
    end

    logger:setup(config.logger)

    colors.setup()

    async.run(function()
        for view_name, view_opts in pairs(config.views or {}) do
            M.views[view_name] = View:new(view_opts.sections, view_opts)
        end
    end)

    M.create_autocommands()
    M.create_user_commands()
end

function M.get_view(name)
    return M.views[name or "default"]
end

function M.open(view_name, opts)
    local view = M.get_view(view_name)
    if view then
        view:open(opts)
    end
end

function M.close(view_name)
    local view = M.get_view(view_name)
    if view then
        view:close()
    end
end

function M.toggle(view_name)
    local view = M.get_view(view_name)
    if view then
        view:toggle()
    end
end

function M.on_tab_change()
    async.run(function()
        for _, view in pairs(M.views) do
            -- check if the view is not open in the current tab, but open in any other tab so we can also open in the current tab
            -- feels like the view has "moved" to this tab
            if not view:is_open() and view:is_open({ any_tabpage = true }) then
                view:open()
            end
        end
    end)
end

function M.on_win_closed()
    async.run(function()
        local opened_views = {}

        for _, view in pairs(M.views) do
            if view:is_open() then
                table.insert(opened_views, view)
            end
        end

        if #opened_views == 0 then
            return
        end

        local windows = api.nvim_list_wins()
        local curtab = api.nvim_get_current_tabpage()
        local wins_in_tabpage = vim.tbl_filter(function(w)
            return api.nvim_win_get_tabpage(w) == curtab
        end, windows)
        if #windows - #opened_views == 1 then
            for _, view in ipairs(opened_views) do
                -- detach from the WinClosed event
                vim.defer_fn(function()
                    async.run(function()
                        view:close()
                    end)
                end, 100)
            end
        elseif #wins_in_tabpage - #opened_views == 1 then
            api.nvim_command(":tabclose")
        end
    end)
end

function M.create_user_commands()
    vim.api.nvim_create_user_command("SidebarNvimOpen", function(opts)
        M.open(opts.args, { focus = opts.bang })
    end, {
        bang = true,
        nargs = "?",
        desc = "Open a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'. Use ! to also focus",
        complete = function()
            return vim.tbl_keys(M.views)
        end,
    })

    vim.api.nvim_create_user_command("SidebarNvimClose", function(opts)
        M.close(opts.args)
    end, {
        nargs = "?",
        desc = "Close a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'",
        complete = function()
            return vim.tbl_keys(M.views)
        end,
    })

    vim.api.nvim_create_user_command("SidebarNvimToggle", function(opts)
        M.toggle(opts.args)
    end, {
        nargs = "?",
        desc = "Toggle a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'",
        complete = function()
            return vim.tbl_keys(M.views)
        end,
    })
end

function M.create_autocommands()
    local group_id = vim.api.nvim_create_augroup("SidebarNvimGeneral", { clear = true })

    vim.api.nvim_create_autocmd("TabEnter", {
        group = group_id,
        callback = function()
            M.on_tab_change()
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group_id,
        callback = function()
            M.on_win_closed()
        end,
    })
end

return M

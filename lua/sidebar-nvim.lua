local pasync = require("sidebar-nvim.lib.async")
local colors = require("sidebar-nvim.colors")
local View = require("sidebar-nvim.lib.view")
local config = require("sidebar-nvim.config")
local logger = require("sidebar-nvim.logger")

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

    pasync.run(function()
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
    -- TODO: not implemented
end

function M.on_win_leave()
    -- TODO: not implemented
end

function M.create_user_commands()
    vim.api.nvim_create_user_command("SidebarNvimOpen", function(opts)
        require("sidebar-nvim").open(opts.args, { focus = opts.bang })
    end, {
        bang = true,
        nargs = "?",
        desc = "Open a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'. Use ! to also focus",
        complete = function()
            local views = require("sidebar-nvim").views
            return vim.tbl_keys(views)
        end,
    })

    vim.api.nvim_create_user_command("SidebarNvimClose", function(opts)
        require("sidebar-nvim").close(opts.args)
    end, {
        nargs = "?",
        desc = "Close a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'",
        complete = function()
            local views = require("sidebar-nvim").views
            return vim.tbl_keys(views)
        end,
    })

    vim.api.nvim_create_user_command("SidebarNvimToggle", function(opts)
        require("sidebar-nvim").toggle(opts.args)
    end, {
        nargs = "?",
        desc = "Toggle a SidebarNvim view. If no view name is passed, it defaults to the default view named 'default'",
        complete = function()
            local views = require("sidebar-nvim").views
            return vim.tbl_keys(views)
        end,
    })
end

function M.create_autocommands()
    local group_id = vim.api.nvim_create_augroup("SidebarNvimGeneral", { clear = true })

    vim.api.nvim_create_autocmd("TabEnter", {
        group = group_id,
        callback = function()
            require("sidebar-nvim").on_tab_change()
        end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
        group = group_id,
        callback = function()
            require("sidebar-nvim").on_win_leave()
        end,
    })
end

return M

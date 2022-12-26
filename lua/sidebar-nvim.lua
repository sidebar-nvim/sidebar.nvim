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
end

function M.get_view(name)
    return M.views[name or "default"]
end

function M.open(view_name)
    local view = M.views[view_name or "default"]
    if view then
        view:open()
    end
end

function M._vim_enter()
    -- pasync.run(function()
    --     M.get_view().open()
    -- end)
end

return M

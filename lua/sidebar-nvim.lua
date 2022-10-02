local colors = require("sidebar-nvim.colors")
local view = require("sidebar-nvim.view")
local updater = require("sidebar-nvim.updater")
local config = require("sidebar-nvim.config")

local M = {}

function M.setup(opts)
    opts = opts or {}

    for key, value in pairs(opts) do
        config[key] = value
    end

    colors.setup()
    view.setup()
    updater.setup()
end

return M

local pasync = require("sidebar-nvim.lib.async")
local colors = require("sidebar-nvim.colors")
local view = require("sidebar-nvim.view")
local updater = require("sidebar-nvim.updater")
local config = require("sidebar-nvim.config")
local renderer = require("sidebar-nvim.renderer")

local M = {}

function M.setup(opts)
    opts = opts or {}

    for key, value in pairs(opts) do
        config[key] = value
    end

    colors.setup()

    pasync.run(function()
        view.setup()
        renderer.setup()
        updater.setup()
    end)
end

function M._vim_enter()
    pasync.run(function()
        view.open()
    end)
end

function M._session_load_post()
    pasync.run(function()
        view._wipe_rogue_buffer()
    end)
end

return M

local lib = require("sidebar-nvim.lib")
local colors = require("sidebar-nvim.colors")
local renderer = require("sidebar-nvim.renderer")
local view = require("sidebar-nvim.view")
local updater = require("sidebar-nvim.updater")
local config = require("sidebar-nvim.config")
local bindings = require("sidebar-nvim.bindings")
local profile = require("sidebar-nvim.profile")
local utils = require("sidebar-nvim.utils")

local M = { open_on_start = false, setup_called = false, vim_enter_called = false }

function M.setup(opts)
    opts = opts or {}

    for key, value in pairs(opts) do
        if key == "open" then
            M.open_on_start = value
        else
            if type(value) ~= "table" or key == "sections" then
                config[key] = value
            else
                if type(config[key]) == "table" then
                    config[key] = vim.tbl_deep_extend("force", config[key], value)
                else
                    config[key] = value
                end
            end
        end
    end

    M.setup_called = true
    -- check if vim enter has already been called, if so, do initialize
    if M.vim_enter_called then
        M._internal_setup()
    end
end

function M._internal_setup()
    view._wipe_rogue_buffer()

    colors.setup()
    bindings.setup()
    view.setup()

    updater.setup()
    lib.setup()

    if M.open_on_start then
        M._internal_open()
    end
end

function M._vim_enter()
    M.vim_enter_called = true

    if M.setup_called then
        M._internal_setup()
    end
end

-- toggle the sidebar
-- @param (table) opts (optional)
-- |- boolean opts.focus whether it should focus once open or not
function M.toggle(opts)
    lib.toggle(opts)
end

function M.close()
    lib.close()
end

function M._internal_open(opts)
    if not lib.is_open() then
        lib.open(opts)
    end
end

function M.open()
    M._internal_open()
end

-- Force immediate update
function M.update()
    lib.update()
end

-- Resize the sidebar to the requested size
-- @param size number
function M.resize(size)
    lib.resize(size)
end

--- Returns the window width for sidebar-nvim within the tabpage specified
---@param tabpage number: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number
function M.get_width(tabpage)
    return lib.get_width(tabpage)
end

-- Focus or open the sidebar
function M.focus()
    lib.focus()
end

function M.reset_highlight()
    colors.setup()
    renderer.render_hl(view.View.bufnr, {})
end

function M._on_cursor_move(direction)
    lib.on_cursor_move(direction)
end

function M.print_profile_summary()
    if not config.enable_profile then
        utils.echo_warning("Profile not enabled")
        return
    end

    profile.print_summary()
end

return M

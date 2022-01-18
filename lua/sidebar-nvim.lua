local lib = require("sidebar-nvim.lib")
local colors = require("sidebar-nvim.colors")
local renderer = require("sidebar-nvim.renderer")
local view = require("sidebar-nvim.view")
local updater = require("sidebar-nvim.updater")
local config = require("sidebar-nvim.config")
local bindings = require("sidebar-nvim.bindings")
local profile = require("sidebar-nvim.profile")
local utils = require("sidebar-nvim.utils")

local M = { open_on_start = false, setup_called = false }

local deprecated_config_map = { docker = "containers" }
local function check_deprecated_field(key)
    if not vim.tbl_contains(vim.tbl_keys(deprecated_config_map), key) then
        return
    end

    local new_key = deprecated_config_map[key]
    utils.echo_warning("config '" .. key .. "' is deprecated. Please use '" .. new_key .. "' instead")
end

function M.setup(opts)
    opts = opts or {}

    for key, value in pairs(opts) do
        check_deprecated_field(key)

        if key == "open" then
            M.open_on_start = value
        else
            if type(value) ~= "table" or key == "sections" or key == "section_separator" then
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
    -- docs for `vim.v.vim_did_enter`: https://neovim.io/doc/user/autocmd.html#VimEnter
    if vim.v.vim_did_enter == 1 then
        M._internal_setup()
    end
end

function M._internal_setup()
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
    lib.update()
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

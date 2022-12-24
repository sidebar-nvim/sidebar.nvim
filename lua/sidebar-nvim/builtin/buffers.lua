local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Loclist = require("sidebar-nvim.lib.loclist")
local utils = require("sidebar-nvim.utils")
local view = require("sidebar-nvim.view")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local api = async.api

local buffers = Section:new({
    title = "Buffers",
    icon = "",
    ignored_buffers = {},
    sorting = "id",
    show_numbers = true,
    ignore_not_loaded = false,
    ignore_terminal = true,

    reloaders = { reloaders.autocmd({ "BufAdd", "BufDelete", "BufEnter", "BufLeave" }, "*") },

    highlights = {
        groups = {},
        links = {
            SidebarNvimBuffersActive = "SidebarNvimSectionTitle",
            SidebarNvimBuffersNumber = "SIdebarnvimLineNr",
        },
    },

    keymaps = {
        delete_buffer = "d",
        edit_buffer = "e",
        write_buffer = "w",
    },
})

local function get_fileicon(filename)
    if has_devicons and devicons.has_loaded() then
        local extension = filename:match("^.+%.(.+)$")

        local fileicon = ""
        local icon, highlight = devicons.get_icon(filename, extension)
        if icon then
            fileicon = icon
        end

        if not highlight then
            highlight = "SidebarNvimNormal"
        end

        return "  " .. fileicon .. " ", highlight
    end

    return "   ", ""
end

function buffers:delete_buffer(bufnr, bufname)
    local is_modified = vim.api.nvim_buf_get_option(bufnr, "modified")

    if is_modified then
        vim.ui.input(
            { prompt = 'file "' .. bufname .. '" has been modified. [w]rite/[d]iscard/[c]ancel: ' },
            function(action)
                if action == "w" then
                    vim.api.nvim_buf_call(bufnr, function()
                        vim.cmd("silent! w")
                    end)
                    vim.api.nvim_buf_delete(bufnr, { force = true })
                elseif action == "d" then
                    vim.api.nvim_buf_delete(bufnr, { force = true })
                end
            end
        )
        return
    end

    vim.api.nvim_buf_delete(bufnr, { force = true })
end

function buffers:edit_buffer(_, bufname)
    vim.cmd("wincmd p")
    vim.cmd("e " .. bufname)
end

function buffers:write_buffer(bufnr)
    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent! w")
    end)
end

function buffers:draw_content()
    local current_buffer = api.nvim_get_current_buf()

    local loclist_items = {}

    for _, buffer in ipairs(api.nvim_list_bufs()) do
        if buffer ~= view.View.bufnr then
            local ignored = false
            local bufname = api.nvim_buf_get_name(buffer)

            for _, ignored_buffer in ipairs(self.ignored_buffers or {}) do
                if string.match(bufname, ignored_buffer) then
                    ignored = true
                end
            end

            if bufname == "" then
                ignored = true
            end

            if self.ignore_not_loaded and not api.nvim_buf_is_loaded(buffer) then
                ignored = true
            end

            -- NOTE: should we be more specific?
            if api.nvim_buf_get_option(buffer, "bufhidden") ~= "" then
                ignored = true
            end

            -- always ignore terminals
            if self.ignore_terminal and string.match(bufname, "term://.*") then
                ignored = true
            end

            if not ignored then
                local name_hl = "SidebarNvimNormal"
                local modified = ""

                if buffer == current_buffer then
                    name_hl = "SidebarNvimBuffersActive"
                end

                if api.nvim_buf_get_option(buffer, "modified") then
                    modified = " *"
                end

                local icon, icon_hl = get_fileicon(bufname)
                local line = LineBuilder:new({ keymaps = self:bind_keymaps({ buffer, bufname }) }):left(icon, icon_hl)

                if self.show_numbers then
                    line = line:left(buffer .. " ", "SidebarNvimBuffersNumber")
                end

                line = line:left(utils.filename(bufname) .. modified, name_hl)

                table.insert(loclist_items, {
                    bufnr = buffer,
                    bufname = bufname,
                    line = line,
                })
            end
        end
    end

    -- sorting = "id"
    local cmp_fn = function(a, b)
        return a.bufnr < b.bufnr
    end
    if self.sorting == "name" then
        cmp_fn = function(a, b)
            return a.bufname < b.bufname
        end
    end

    table.sort(loclist_items, cmp_fn)

    local items = vim.tbl_map(function(item)
        return item.line
    end, loclist_items)

    local loclist = Loclist:new({ buffers = { items = items } }, { omit_single_group = true })
    return loclist:draw()
end

return buffers

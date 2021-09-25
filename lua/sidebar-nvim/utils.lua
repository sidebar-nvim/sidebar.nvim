local M = {}
local api = vim.api

function M.echo_warning(msg)
    api.nvim_command("echohl WarningMsg")
    api.nvim_command("echom '[SidebarNvim] " .. msg:gsub("'", "''") .. "'")
    api.nvim_command("echohl None")
end

function M.escape_keycode(key)
    return key:gsub("<", "["):gsub(">", "]")
end

function M.unescape_keycode(key)
    return key:gsub("%[", "<"):gsub("%]", ">")
end

function M.sidebar_nvim_callback(key)
    return string.format(":lua require('sidebar-nvim').on_keypress('%s')<CR>", M.escape_keycode(key))
end

function M.sidebar_nvim_cursor_move_callback(direction)
    return string.format(":lua require('sidebar-nvim')._on_cursor_move('%s')<CR>", direction)
end

local function get_builtin_section(name)
    local ret, section = pcall(require, "sidebar-nvim.builtin." .. name)
    if not ret then
        M.echo_warning("error trying to load section: " .. name)
        return nil
    end

    return section
end

function M.resolve_section(index, section)
    if type(section) == "string" then
        return get_builtin_section(section)
    elseif type(section) == "table" then
        return section
    end

    M.echo_warning("invalid SidebarNvim section at: index=" .. index .. " section=" .. section)
    return nil
end

function M.is_instance(o, class)
    while o do
        o = getmetatable(o)
        if class == o then
            return true
        end
    end
    return false
end

-- Reference: https://github.com/hoob3rt/lualine.nvim/blob/master/lua/lualine/components/filename.lua#L9

local function count(base, pattern)
    return select(2, string.gsub(base, pattern, ""))
end

function M.shorten_path(path, min_len)
    if #path <= min_len then
        return path
    end

    local sep = package.config:sub(1, 1)

    for _ = 0, count(path, sep) do
        if #path <= min_len then
            return path
        end

        -- ('([^/])[^/]+%/', '%1/', 1)
        path = path:gsub(string.format("([^%s])[^%s]+%%%s", sep, sep, sep), "%1" .. sep, 1)
    end

    return path
end

return M

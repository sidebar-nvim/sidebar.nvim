local M = {}
local api = vim.api
local luv = vim.loop

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
    return string.format(":lua require('sidebar-nvim.lib').on_keypress('%s')<CR>", M.escape_keycode(key))
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

function M.shortest_path(path)
    local sep = package.config:sub(1, 1)

    for _ = 0, count(path, sep) do
        -- ('([^/])[^/]+%/', '%1/', 1)
        path = path:gsub(string.format("([^%s])[^%s]+%%%s", sep, sep, sep), "%1" .. sep, 1)
    end

    return path
end

function M.dir(path)
    return path:match("^(.+/)")
end

function M.filename(path)
    local split = vim.split(path, "/")
    return split[#split]
end

function M.file_exist(path)
    local _, err = luv.fs_stat(path)
    return err == nil
end

function M.truncate(s, size)
    local length = #s

    if length <= size then
        return s
    else
        return s:sub(1, size) .. ".."
    end
end

function M.async_cmd(cmd, args, callback)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)
    local handle

    handle = luv.spawn(cmd, { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() }, function()
        if callback then
            callback()
        end

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    luv.read_start(stdout, function(err, _)
        if err ~= nil then
            vim.schedule(function()
                M.echo_warning(err)
            end)
        end
    end)

    luv.read_start(stderr, function(err, data)
        if data ~= nil then
            vim.schedule(function()
                M.echo_warning(data)
            end)
        end

        if err ~= nil then
            vim.schedule(function()
                M.echo_warning(err)
            end)
        end
    end)
end

-- @param opts table
-- @param opts.modified boolean filter buffers by modified or not
function M.get_existing_buffers(opts)
    return vim.tbl_filter(function(buf)
        local modified_filter = true
        if opts and opts.modified ~= nil then
            local is_ok, is_modified = pcall(api.nvim_buf_get_option, buf, "modified")

            if is_ok then
                modified_filter = is_modified == opts.modified
            end
        end

        return api.nvim_buf_is_valid(buf) and vim.fn.buflisted(buf) == 1 and modified_filter
    end, api.nvim_list_bufs())
end

return M

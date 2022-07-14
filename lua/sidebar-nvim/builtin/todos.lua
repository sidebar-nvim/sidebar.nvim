local utils = require("sidebar-nvim.utils")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")

local loclist = Loclist:new({
    groups_initially_closed = config.todos.initially_closed,
    show_empty_groups = false,
    indent = " ",
    truncate = "right",
    truncate_minimum = 10,
})

-- Make sure all groups exist
loclist:add_group("TODO")
loclist:add_group("HACK")
loclist:add_group("WARN")
loclist:add_group("PERF")
loclist:add_group("NOTE")
loclist:add_group("FIX")

local icons = {
    TODO = { text = "", hl = "SidebarNvimTodoIconTodo" },
    HACK = { text = "", hl = "SidebarNvimTodoIconHack" },
    WARN = { text = "", hl = "SidebarNvimTodoIconWarn" },
    PERF = { text = "", hl = "SidebarNvimTodoIconPerf" },
    NOTE = { text = "", hl = "SidebarNvimTodoIconNote" },
    FIX  = { text = "", hl = "SidebarNvimTodoIconFix" },
}

local current_path_ignored_cache = false

local function is_current_path_ignored()
    local cwd = vim.loop.cwd()
    for _, path in pairs(config.todos.ignored_paths or {}) do
        if vim.fn.expand(path) == cwd then
            return true
        end
    end

    return false
end

local function async_update()
    current_path_ignored_cache = is_current_path_ignored()
    if current_path_ignored_cache then
        return
    end

    local todos = {}

    local cmd
    local args
    local keywords_regex = "(TODO|NOTE|FIX|PERF|HACK|WARN)"

    -- Use ripgrep by default, if it's installed
    if vim.fn.executable("rg") == 1 then
        cmd = "rg"
        args = {
            "--no-hidden",
            "--column",
            "--only-matching",
            keywords_regex .. ":.*",
        }
    else
        cmd = "git"
        args = { "grep", "-no", "--column", "-EI", keywords_regex .. ":.*" }
    end


    utils.async_cmd(cmd, args, function(chunks)
        for _, chunk in ipairs(chunks) do
            for _, line in ipairs(vim.split(chunk, "\n")) do
                if line ~= "" then
                    local filepath, lnum, col, tag, text = line:match("^(.+):(%d+):(%d+):(%w+):(.*)$")

                    if filepath and tag then
                        if not todos[tag] then
                            todos[tag] = {}
                        end

                        local category_tbl = todos[tag]

                        category_tbl[#category_tbl + 1] = {
                            filepath = filepath,
                            lnum = lnum,
                            col = col,
                            tag = tag,
                            text = text,
                        }
                    end
                end
            end
        end

        local loclist_items = {}
        for _, items in pairs(todos) do
            for _, item in ipairs(items) do
                table.insert(loclist_items, {
                    group = item.tag,
                    left = {
                        icons[item.tag],
                        " ",
                        -- { text = " " .. item.lnum, hl = "SidebarNvimTodoLineNumber" },
                        { text = item.text },
                    },
                    right = {
                        {
                            text = utils.filename(item.filepath),
                            hl = "SidebarNvimLineNr",
                        },
                    },
                    filepath = item.filepath,
                    order = item.filepath,
                    lnum = item.lnum,
                    col = item.col,
                })
            end
        end

        loclist:set_items(loclist_items, { remove_groups = false })
    end)
end

return {
    title = "TODOs",
    icon = config.todos.icon,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        if current_path_ignored_cache then
            lines = { utils.empty_message("<path ignored>") }
        end

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            return utils.empty_message("<no TODOs>")
        end

        return { lines = lines, hl = hl }
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimTodoFilename = "SidebarNvimLineNr",
            SidebarNvimTodoLineNumber = "SidebarNvimLineNr",
            SidebarNvimTodoColNumber = "SidebarNvimLineNr",
            SidebarNvimTodoIconTodo = "DiagnosticInfo",
            SidebarNvimTodoIconHack = "DiagnosticWarning",
            SidebarNvimTodoIconWarn = "DiagnosticWarning",
            SidebarNvimTodoIconPerf = "DiagnosticError",
            SidebarNvimTodoIconNote = "DiagnosticHint",
            SidebarNvimTodoIconFix = "DiagnosticError",
        },
    },
    bindings = {
        ["t"] = function(line)
            loclist:toggle_group_at(line)
        end,
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if not location then
                return
            end
            vim.cmd("wincmd p")
            vim.cmd("e " .. location.filepath)
            vim.fn.cursor(location.lnum, location.col)
        end,
    },
    setup = async_update,
    update = async_update,
    toggle_all = function()
        loclist:toggle_all_groups()
    end,
    close_all = function()
        loclist:close_all_groups()
    end,
    open_all = function()
        loclist:open_all_groups()
    end,
    open = function(group)
        loclist:open_group(group)
    end,
    close = function(group)
        loclist:close_group(group)
    end,
    toggle = function(group)
        loclist:toggle_group(group)
    end,
}

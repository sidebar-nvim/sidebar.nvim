local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local pasync = require("sidebar-nvim.lib.async")
local Job = require("sidebar-nvim.lib.async.job")
local Loclist = require("sidebar-nvim.lib.loclist")
local utils = require("sidebar-nvim.utils")
local luv = vim.loop

local todos = Section:new({
    title = "TODOs",
    icon = "",
    ignored_paths = { "~" },
    initially_closed = false,

    state = {},

    icons = {
        TODO = { text = "", hl = "SidebarNvimTodoIconTodo" },
        HACK = { text = "", hl = "SidebarNvimTodoIconHack" },
        WARN = { text = "", hl = "SidebarNvimTodoIconWarn" },
        PERF = { text = "", hl = "SidebarNvimTodoIconPerf" },
        NOTE = { text = "", hl = "SidebarNvimTodoIconNote" },
        FIX = { text = "", hl = "SidebarNvimTodoIconFix" },
    },

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
})

function todos:draw_content()
    local groups = {
        TODO = {},
        HACK = {},
        WARN = {},
        PERF = {},
        NOTE = {},
        FIX = {},
    }

    local loclist = Loclist:new(groups, {
        show_empty_groups = false,
    })

    return loclist:draw()
end

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

local function async_update(ctx)
    current_path_ignored_cache = is_current_path_ignored()
    if current_path_ignored_cache then
        return
    end

    local todos = {}

    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)
    local handle
    local cmd
    local args
    local keywords_regex = [[(TODO|NOTE|FIX|PERF|HACK|WARN)]]
    local regex_end = [[\s*(\(.*\))?:.*]]

    -- Use ripgrep by default, if it's installed
    if vim.fn.executable("rg") == 1 then
        cmd = "rg"
        args = {
            "--no-hidden",
            "--column",
            "--only-matching",
            keywords_regex .. regex_end,
        }
    else
        cmd = "git"
        args = { "grep", "-no", "--column", "-EI", keywords_regex .. regex_end }
    end

    handle = luv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
        cmd = luv.cwd(),
    }, function()
        local loclist_items = {}
        for _, items in pairs(todos) do
            for _, item in ipairs(items) do
                table.insert(loclist_items, {
                    group = item.tag,
                    left = {
                        icons[item.tag],
                        { text = " " .. item.lnum, hl = "SidebarNvimTodoLineNumber" },
                        { text = ":" },
                        { text = item.col, hl = "SidebarNvimTodoColNumber" },
                        { text = utils.truncate(item.text, ctx.width / 2) },
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

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    luv.read_start(stdout, function(err, data)
        if data == nil then
            return
        end

        for _, line in ipairs(vim.split(data, "\n")) do
            if line ~= "" then
                local filepath, lnum, col, tag, text = line:match("^(.+):(%d+):(%d+):([%w%(%)]+):(.*)$")

                if filepath and tag then
                    local tag_with_scope = { tag:match("(%w+)%(.*%)") }
                    if #tag_with_scope > 0 then
                        tag = tag_with_scope[1]
                    end

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

        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)

    luv.read_start(stderr, function(err, data)
        if data == nil then
            return
        end

        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)
end

return {
    title = "TODOs",
    icon = config.todos.icon,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        if current_path_ignored_cache then
            lines = { "<path ignored>" }
        end

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            lines = { "<no TODOs>" }
        end

        return { lines = lines, hl = hl }
    end,
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
    setup = function(ctx)
        async_update(ctx)
    end,
    update = function(ctx)
        async_update(ctx)
    end,
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

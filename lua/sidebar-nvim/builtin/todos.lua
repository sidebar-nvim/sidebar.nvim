local utils = require("sidebar-nvim.utils")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local luv = vim.loop

local loclist = Loclist:new({
    groups_initially_closed = config.todos.initially_closed,
})

local todos = {}

local function async_update(_)
    loclist:clear()
    todos = {}

    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)
    local handle

    -- PERF: Use rg instead of git grep when it's installed
    handle = luv.spawn("git", {
        args = { "grep", "-no", "--column", "-EI", "(TODO|NOTE|FIXME|PERF|HACK) *:.*" },
        stdio = { nil, stdout, stderr },
        cmd = luv.cwd(),
    }, function()
        for _, items in pairs(todos) do
            for _, item in ipairs(items) do
                loclist:add_item({
                    group = item.tag,
                    left = {
                        { text = item.lnum, hl = "SidebarNvimTodoLineNumber" },
                        { text = ":" },
                        { text = item.col .. " ", hl = "SidebarNvimTodoColNumber" },
                        {
                            text = utils.shortest_path(item.filepath),
                            -- text = vim.fn.fnamemodify(item.filepath, ":t"),
                        },
                    },
                    filepath = item.filepath,
                    lnum = item.lnum,
                    col = item.col,
                })
            end
        end

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
                local split_line = vim.split(line, ":")
                local filepath, lnum, col, tag, text =
                    split_line[1], split_line[2], split_line[3], split_line[4], split_line[5]

                if tag and text then
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

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            lines = { "<no TODOs>" }
        end

        return { lines = lines, hl = hl }
    end,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {
            SidebarNvimTodoTag = "SidebarNvimLabel",
            SidebarNvimTodoTotalNumber = "SidebarNvimNormal",
            SidebarNvimTodoFilename = "SidebarNvimNormal",
            SidebarNvimTodoLineNumber = "SidebarNvimLineNr",
            SidebarNvimTodoColNumber = "SidebarNvimLineNr",
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
    setup = function()
        async_update()
    end,
    update = function()
        async_update()
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

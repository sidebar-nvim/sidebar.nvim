local has_todos, todos = pcall(require, "todo-comments.search")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")

local loclist = Loclist:new({
    highlights = {
        group = "SidebarNvimTodoTag",
        group_count = "SidebarNvimTodoTotalNumber",
        item_text = "SidebarNvimTodoFilename",
        item_lnum = "SidebarNvimTodoLineNumber",
        item_col = "SidebarNvimTodoColNumber",
    },
})

local search_controller = {}

-- todo-comments config is async, so we need to wait for it to be ready in order to use its functions
function search_controller.wait_for_todo_config()
    local timer = vim.loop.new_timer()

    timer:start(200, 0, function()
        vim.schedule(function()
            search_controller.do_search()
        end)
        timer:close()
    end)
end

local is_searching = false

function search_controller.do_search()
    if not has_todos then
        return
    end

    if search_controller.is_current_path_ignored() then
        return
    end

    local _, todo_config = pcall(require, "todo-comments.config")
    if not todo_config.loaded then
        search_controller.wait_for_todo_config()
        return
    end

    if is_searching then
        return
    end
    is_searching = true

    local opts = { disable_not_found_warnings = true }
    todos.search(function(results)
        table.sort(results, function(a, b)
            return a.tag < b.tag
        end)

        table.sort(results, function(a, b)
            return a.filename < b.filename
        end)

        table.sort(results, function(a, b)
            return a.lnum < b.lnum
        end)

        loclist:clear()

        for _, item in pairs(results) do
            loclist:add_item({
                group = item.tag,
                lnum = item.lnum,
                col = item.col,
                text = vim.fn.fnamemodify(item.filename, ":t"),
                filepath = item.filename,
            })
        end
        is_searching = false
    end, opts)
end

function search_controller.is_current_path_ignored()
    local cwd = vim.loop.cwd()
    for _, path in pairs(config.todos.ignored_paths or {}) do
        if vim.fn.expand(path) == cwd then
            return true
        end
    end

    return false
end

return {
    title = "TODOs",
    icon = "📄",
    draw = function(ctx)
        if not has_todos then
            local lines = { "provider 'todo-comments' not installed" }
            return { lines = lines, hl = {} }
        end

        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            lines = { "<no TODOs>" }
        end

        if search_controller.is_current_path_ignored() then
            lines = { "<path ignored>" }
        end

        return { lines = lines, hl = hl }
    end,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {
            SidebarNvimTodoTag = "Label",
            SidebarNvimTodoTotalNumber = "Normal",
            SidebarNvimTodoFilename = "Normal",
            SidebarNvimTodoLineNumber = "LineNr",
            SidebarNvimTodoColNumber = "LineNr",
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
            vim.cmd("e " .. location.filename)
            vim.fn.cursor(location.lnum, location.col)
        end,
    },
    setup = function()
        search_controller.do_search()
    end,
    update = function()
        search_controller.do_search()
    end,
}

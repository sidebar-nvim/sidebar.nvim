local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Job = require("plenary.job")
local Loclist = require("sidebar-nvim.lib.loclist")
local logger = require("sidebar-nvim.logger")

local todos = Section:new({
    title = "TODOs",
    icon = "",
    ignored_paths = { "~" },
    initially_closed = false,

    icons = {
        TODO = { text = "", hl = "SidebarNvimTodoIconTodo" },
        HACK = { text = "", hl = "SidebarNvimTodoIconHack" },
        WARN = { text = "", hl = "SidebarNvimTodoIconWarn" },
        PERF = { text = "", hl = "SidebarNvimTodoIconPerf" },
        NOTE = { text = "", hl = "SidebarNvimTodoIconNote" },
        FIX = { text = "", hl = "SidebarNvimTodoIconFix" },
    },

    closed_groups = {},

    reloaders = {
        reloaders.autocmd({ "BufWritePost" }, "*"),
        reloaders.autocmd({ "ShellCmdPost" }, "*"),
        reloaders.autocmd({ "DirChanged" }, "*"),
    },

    keymaps = {
        group_toggle = "t",
        file_edit = "e",
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

function todos:group_toggle(group_name)
    if self.closed_groups[group_name] then
        self.closed_groups[group_name] = false
    else
        self.closed_groups[group_name] = true
    end
end

function todos:file_edit(item)
    vim.cmd("wincmd p")
    vim.cmd("e " .. item.filepath)
    vim.api.nvim_win_set_cursor(0, { item.lnum, item.col })
end

function todos:is_current_path_ignored()
    local cwd = vim.loop.cwd()
    for _, path in pairs(self.ignored_paths or {}) do
        if vim.fn.expand(path) == cwd then
            return true
        end
    end

    return false
end

function todos:run_search()
    local keywords_regex = [[(TODO|NOTE|FIX|PERF|HACK|WARN)]]
    local regex_end = [[\s*(\(.*\))?:.*]]
    local cmd
    local args

    -- Use ripgrep by default, if it's installed
    if async.fn.executable("rg") == 1 then
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

    local output, code = Job:new({
        command = cmd,
        args = args,
        env = vim.env,
        cwd = vim.loop.cwd(),
        interactive = false,
    }):sync()
    if code ~= 0 then
        logger:error(
            string.format("error trying to run '%s'", cmd),
            { command = cmd, args = args, code = code, output = output }
        )
        return {}
    end

    output = output or {}

    local current_todos = {}

    for _, line in ipairs(output) do
        if line ~= "" then
            local filepath, lnum, col, tag, text = line:match("^(.+):(%d+):(%d+):([%w%(%)]+):(.*)$")

            if filepath and tag then
                local tag_with_scope = { tag:match("(%w+)%(.*%)") }
                if #tag_with_scope > 0 then
                    tag = tag_with_scope[1]
                end

                if not current_todos[tag] then
                    current_todos[tag] = {}
                end

                local category_tbl = current_todos[tag]

                table.insert(category_tbl, {
                    filepath = filepath,
                    lnum = tonumber(lnum),
                    col = tonumber(col),
                    tag = tag,
                    text = vim.trim(text),
                })
            end
        end
    end

    return current_todos
end

function todos:draw_content()
    if self:is_current_path_ignored() then
        return { LineBuilder:new():left("<path ignored>") }
    end

    local current_todos = self:run_search()

    local groups = {}

    for _, group_name in ipairs(vim.tbl_keys(current_todos)) do
        local is_closed = self.closed_groups[group_name] ~= nil and self.closed_groups[group_name]
            or self.initially_closed

        groups[group_name] = {
            keymaps = self:bind_keymaps({ group_name }, { filter = { "group_toggle" } }),
            is_closed = is_closed,
            items = vim.tbl_map(function(item)
                local icon = self.icons[group_name]
                return LineBuilder:new({ keymaps = self:bind_keymaps({ item }, { filter = { "file_edit" } }) })
                    :left(icon.text, icon.hl)
                    :left(" " .. item.lnum, "SidebarNvimTodoLineNumber")
                    :left(":")
                    :left(item.col, "SidebarNvimTodoColNumber")
                    :left(" " .. item.text)
                    :right(vim.fs.basename(item.filepath), "SidebarNvimLineNr")
            end, current_todos[group_name]),
        }
    end

    local loclist = Loclist:new(groups, {
        show_empty_groups = false,
    })

    return loclist:draw()
end

return todos

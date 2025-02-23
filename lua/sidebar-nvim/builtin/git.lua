local utils = require("sidebar-nvim.utils")
local sidebar = require("sidebar-nvim")
local Loclist = require("sidebar-nvim.components.loclist")
local Debouncer = require("sidebar-nvim.debouncer")
local config = require("sidebar-nvim.config")
local luv = vim.loop
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local loclist = Loclist:new({})

-- Make sure all groups exist
loclist:add_group("Staged")
loclist:add_group("Unstaged")
loclist:add_group("Unmerged")
loclist:add_group("Untracked")

local loclist_items = {}
local finished = 0
local expected_job_count = 4

-- parse line from git diff --numstat into a loclist item
local function parse_git_diff(group, line)
    local t = vim.split(line, "\t")
    local added, removed, filepath = t[1], t[2], t[3]
    local extension = filepath:match("^.+%.(.+)$")
    local fileicon = ""
    local filehighlight = "SidebarNvimGitStatusFileIcon"

    if has_devicons and devicons.has_loaded() then
        local icon, highlight = devicons.get_icon(filepath, extension)

        if icon then
            fileicon = icon
            filehighlight = highlight
        end
    end

    if filepath ~= "" then
        loclist:open_group(group)

        table.insert(loclist_items, {
            group = group,
            left = {
                {
                    text = fileicon .. " ",
                    hl = filehighlight,
                },
                {
                    text = utils.shortest_path(filepath) .. " ",
                    hl = "SidebarNvimGitStatusFileName",
                },
                {
                    text = added,
                    hl = "SidebarNvimGitStatusDiffAdded",
                },
                {
                    text = ", ",
                },
                {
                    text = removed,
                    hl = "SidebarNvimGitStatusDiffRemoved",
                },
            },
            filepath = filepath,
        })
    end
end

-- parse line from git status --porcelain into a loclist item
local function parse_git_status(group, line)
    local striped = line:match("^%s*(.-)%s*$")
    local status = striped:sub(0, 2)
    local filepath = striped:sub(3, -1):match("^%s*(.-)%s*$")
    local extension = filepath:match("^.+%.(.+)$")

    if status == "??" then
        local fileicon = ""

        if has_devicons and devicons.has_loaded() then
            local icon = vim.schedule_wrap(function()
                return devicons.get_icon_color(filepath, extension)
            end)()
            if icon then
                fileicon = icon
            end
        end

        loclist:open_group(group)

        table.insert(loclist_items, {
            group = group,
            left = {
                {
                    text = fileicon .. " ",
                    hl = "SidebarNvimGitStatusFileIcon",
                },
                {
                    text = utils.shortest_path(filepath),
                    hl = "SidebarNvimGitStatusFileName",
                },
            },
            filepath = filepath,
        })
    end
end

-- execute async command and parse result into loclist items
local function async_cmd(group, command, args, parse_fn)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)

    local handle
    handle = luv.spawn(command, { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() }, function()
        finished = finished + 1

        if finished == expected_job_count then
            loclist:set_items(loclist_items, { remove_groups = false })
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
                parse_fn(group, line)
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

local function async_update(_)
    loclist_items = {}
    finished = 0

    -- if add a new job, please update `expected_job_count` at the top
    -- TODO: investigate using coroutines to wait for all jobs and then update the loclist
    async_cmd("Staged", "git", { "diff", "--numstat", "--staged", "--diff-filter=u" }, parse_git_diff)
    async_cmd("Unstaged", "git", { "diff", "--numstat", "--diff-filter=u" }, parse_git_diff)
    async_cmd("Unmerged", "git", { "diff", "--numstat", "--diff-filter=U" }, parse_git_diff)
    async_cmd("Untracked", "git", { "status", "--porcelain" }, parse_git_status)
end

local async_update_debounced = Debouncer:new(async_update, 1000)

return {
    title = "Git Status",
    icon = config["git"].icon,
    setup = function(ctx)
        -- ShellCmdPost triggered after ":!<cmd>"
        -- BufLeave triggered only after leaving terminal buffers
        vim.api.nvim_exec(
            [[
          augroup sidebar_nvim_git_status_update
              autocmd!
              autocmd ShellCmdPost * lua require'sidebar-nvim.builtin.git'.update()
              autocmd BufLeave term://* lua require'sidebar-nvim.builtin.git'.update()
          augroup END
          ]],
            false
        )
        async_update_debounced:call(ctx)
    end,
    update = function(ctx)
        if not ctx then
            ---@diagnostic disable-next-line: missing-parameter
            ctx = { width = sidebar.get_width() }
        end
        async_update_debounced:call(ctx)
    end,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            lines = { "<no changes>" }
        end

        return { lines = lines, hl = hl }
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimGitStatusFileName = "SidebarNvimNormal",
            SidebarNvimGitStatusFileIcon = "SidebarNvimSectionTitle",
            SidebarNvimGitStatusDiffAdded = "DiffAdded",
            SidebarNvimGitStatusDiffRemoved = "DiffRemoved",
        },
    },
    bindings = {
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            vim.cmd("wincmd p")
            vim.cmd("e " .. location.filepath)
        end,
        -- stage files
        ["s"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            utils.async_cmd("git", { "add", location.filepath }, function()
                async_update_debounced:call()
            end)
        end,
        -- unstage files
        ["u"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            utils.async_cmd("git", { "restore", "--staged", location.filepath }, function()
                async_update_debounced:call()
            end)
        end,
    },
}

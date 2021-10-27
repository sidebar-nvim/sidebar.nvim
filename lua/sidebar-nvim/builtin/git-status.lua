local utils = require("sidebar-nvim.utils")
local sidebar = require("sidebar-nvim")
local Loclist = require("sidebar-nvim.components.loclist")
local Debouncer = require("sidebar-nvim.debouncer")
local config = require("sidebar-nvim.config")
local luv = vim.loop
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local loclist = Loclist:new({
    show_location = false,
    -- ommit_single_group = true,
    highlights = { item_text = "SidebarNvimGitStatusFileName" },
})

local function async_cmd(group, args)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)
    local status_tmp = ""

    local handle
    handle = luv.spawn("git", { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() }, function()
        if status_tmp ~= "" then
            for _, line in ipairs(vim.split(status_tmp, "\n")) do
                if line ~= "" then
                    local t = vim.split(line, "\t")
                    local added, removed, filename = t[1], t[2], t[3]
                    local extension = filename:match("^.+%.(.+)$")
                    local fileicon

                    if has_devicons and devicons.has_loaded() then
                        fileicon, _ = devicons.get_icon_color(filename, extension)
                    end

                    if filename ~= "" then
                        loclist:add_item({
                            group = group,
                            left = {
                                {
                                    text = fileicon .. " ",
                                    hl = "SidebarNvimGitStatusFileIcon",
                                },
                                {
                                    text = utils.shortest_path(filename) .. " ",
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
                            right = {},
                        })
                    end
                end
            end
        end

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    status_tmp = ""

    luv.read_start(stdout, function(err, data)
        if data == nil then
            return
        end

        status_tmp = status_tmp .. data

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

        -- vim.schedule(function()
        -- utils.echo_warning(data)
        -- end)
    end)
end

local function async_update(ctx)
    loclist:clear()

    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)

    local handle
    handle = luv.spawn(
        "git",
        { args = { "status", "--porcelain" }, stdio = { nil, stdout, stderr }, cwd = luv.cwd() },
        function()
            luv.read_stop(stdout)
            stdout:close()
            handle:close()

            async_cmd("Unstaged", { "diff", "--numstat" })
            async_cmd("Staged", { "diff", "--numstat", "--staged" })
        end
    )

    luv.read_start(stdout, function(err, data)
        if data == nil then
            return
        end

        for _, line in ipairs(vim.split(data, "\n")) do
            local striped = line:match("^%s*(.-)%s*$")
            local status = striped:sub(0, 2)
            local filename = striped:sub(3, -1):match("^%s*(.-)%s*$")
            local extension = filename:match("^.+%.(.+)$")

            if status ~= "??" then
                file_status[filename] = status
            else
                local fileicon

                if has_devicons and devicons.has_loaded() then
                    fileicon, _ = devicons.get_icon_color(filename, extension)
                end
                loclist:add_item({
                    group = "Untracked",
                    left = {
                        {
                            text = fileicon .. " ",
                            hl = "SidebarNvimGitStatusFileIcon",
                        },
                        {
                            text = utils.shortest_path(filename),
                            hl = "SidebarNvimGitStatusFileName",
                        },
                    },
                })
            end
        end
    end)
end

local async_update_debounced = Debouncer:new(async_update, 1000)

return {
    title = "Git Status",
    icon = config["git-status"].icon,
    setup = function(ctx)
        -- ShellCmdPost triggered after ":!<cmd>"
        -- BufLeave triggered only after leaving terminal buffers
        vim.api.nvim_exec(
            [[
          augroup sidebar_nvim_todos_update
              autocmd!
              autocmd ShellCmdPost * lua require'sidebar-nvim.builtin.git-status'.update()
              autocmd BufLeave term://* lua require'sidebar-nvim.builtin.git-status'.update()
          augroup END
          ]],
            false
        )
        async_update_debounced:call(ctx)
    end,
    update = function(ctx)
        if not ctx then
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
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {
            SidebarNvimGitStatusState = "SidebarNvimKeyword",
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
            vim.cmd("e " .. location)
        end,
    },
}

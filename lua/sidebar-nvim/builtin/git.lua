local utils = require("sidebar-nvim.utils")
local groups = require("sidebar-nvim.groups")
local sidebar = require("sidebar-nvim")
local Loclist = require("sidebar-nvim.components.loclist")
local Debouncer = require("sidebar-nvim.debouncer")
local config = require("sidebar-nvim.config")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local loclist = Loclist:new({
  show_empty_groups = false,
})

-- Make sure all groups exist
loclist:add_group("Staged")
loclist:add_group("Unstaged")
loclist:add_group("Unmerged")
loclist:add_group("Untracked")

local loclist_items = {}
local finished = 0
local expected_job_count = 4
local current_branch = nil
local is_git_repo = true

local function parse_git_branch(_, line)
    if line == "" then return end
    current_branch = line
    is_git_repo = not vim.startswith(current_branch, 'fatal')
end

-- parse line from git diff --numstat into a loclist item
local function parse_git_diff(group, line)
    local t = vim.split(line, "\t")
    local added, removed, filepath = tonumber(t[1]), tonumber(t[2]), t[3]
    local extension = filepath:match("^.+%.(.+)$")
    local fileicon = ""

    if has_devicons and devicons.has_loaded() then
        local icon, _ = devicons.get_icon_color(filepath, extension)

        if icon then
            fileicon = icon
        end
    end

    if filepath ~= "" then
        loclist:open_group(group)

        local right = {}
        if added > 0 then
            groups.append(right,
                { text = tostring(added), hl = "SidebarNvimGitStatusDiffAdded" })
        end
        if removed > 0 then
            groups.append(right,
                { text = tostring(removed), hl = "SidebarNvimGitStatusDiffRemoved" })
        end
        right = groups.append(
            utils.intersperse(right, { text = " " }), { text = " " })

        table.insert(loclist_items, {
            group = group,
            left = {
                {
                    text = fileicon .. " ",
                    hl = "SidebarNvimGitStatusFileIcon",
                },
                {
                    text = utils.shortest_path(filepath) .. " ",
                    hl = "SidebarNvimGitStatusFileName",
                },
            },
            right = right,
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
            local icon = devicons.get_icon_color(filepath, extension)
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
    utils.async_cmd(command, args, function(chunks)
        for _, chunk in ipairs(chunks) do
            for _, line in ipairs(vim.split(chunk, "\n")) do
                if line ~= "" then
                    parse_fn(group, line)
                end
            end
        end

        finished = finished + 1

        if finished == expected_job_count then
            loclist:set_items(loclist_items, { remove_groups = false })
        end
    end)
end

local function async_update(_)
    loclist_items = {}
    finished = 0

    -- if add a new job, please update `expected_job_count` at the top
    -- TODO: investigate using coroutines to wait for all jobs and then update the loclist
    async_cmd("Branch", "git", { "branch", "--show-current" }, parse_git_branch)
    async_cmd("Staged", "git", { "diff", "--numstat", "--staged", "--diff-filter=u" }, parse_git_diff)
    async_cmd("Unstaged", "git", { "diff", "--numstat", "--diff-filter=u" }, parse_git_diff)
    async_cmd("Unmerged", "git", { "diff", "--numstat", "--diff-filter=U" }, parse_git_diff)
    async_cmd("Untracked", "git", { "status", "--porcelain" }, parse_git_status)
end

local async_update_debounced = Debouncer:new(async_update, 1000)

return {
    title = function()
        if current_branch == nil or not is_git_repo then
            return "Git"
        end
        return "Git (" .. current_branch .. ")"
    end,
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
        if not is_git_repo then
            return utils.empty_message("Not in a git repository")
        end

        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then
            return utils.empty_message("Up to date")
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

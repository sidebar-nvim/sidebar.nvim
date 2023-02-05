local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Job = require("plenary.job")
local Loclist = require("sidebar-nvim.lib.loclist")
local utils = require("sidebar-nvim.utils")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local logger = require("sidebar-nvim.logger")

local git = Section:new({
    title = "Git Status",
    icon = "",

    reloaders = {
        reloaders.autocmd({ "BufLeave" }, "term://*"),
        reloaders.autocmd({ "ShellCmdPost" }, "*"),
        reloaders.autocmd({ "DirChanged" }, "*"),
    },

    keymaps = {
        file_edit = "e",
        file_stage = "s",
        file_unstage = "u",
    },

    highlights = {
        groups = {},
        links = {
            SidebarNvimGitStatusFileName = "SidebarNvimNormal",
            SidebarNvimGitStatusFileIcon = "SidebarNvimSectionTitle",
            SidebarNvimGitStatusDiffAdded = "DiffAdded",
            SidebarNvimGitStatusDiffRemoved = "DiffRemoved",
        },
    },
})

function git:run(args)
    return Job:new({
        command = "git",
        args = args,
        cwd = vim.loop.cwd(),
    }):sync()
end

function git:file_edit(filepath)
    vim.cmd("wincmd p")
    vim.cmd("e " .. filepath)
end

function git:file_stage(filepath)
    local output, code = self:run({ "add", filepath })
    if code ~= 0 then
        logger:error("error trying to stage file", { output = output, filepath = filepath, code = code })
    end
end

function git:file_unstage(filepath)
    local output, code = self:run({ "restore", "--staged", filepath })
    if code ~= 0 then
        logger:error("error trying to unstage file", { output = output, filepath = filepath, code = code })
    end
end

-- parse line from git diff --numstat into a loclist item
function git:parse_git_diff(lines)
    local items = vim.tbl_map(function(line)
        local t = vim.split(line, "\t", {})
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

        if filepath == "" then
            return nil
        end

        return LineBuilder:new({ keymaps = self:bind_keymaps({ filepath }, {}) })
            :left(fileicon .. " ", filehighlight)
            :left(utils.shortest_path(filepath) .. " ", "SidebarNvimGitStatusFileName")
            :left(added, "SidebarNvimGitStatusDiffAdded")
            :left(", ")
            :left(removed, "SidebarNvimGitStatusDiffRemoved")
    end, lines)

    return vim.tbl_filter(function(line)
        return line ~= nil
    end, items)
end

-- parse line from git status --porcelain into a loclist item
function git:parse_git_status(lines)
    return vim.tbl_map(function(line)
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

            return LineBuilder:new({ keymaps = self:bind_keymaps({ filepath }) })
                :left(fileicon .. " ", "SidebarNvimGitStatusFileIcon")
                :left(utils.shortest_path(filepath), "SidebarNvimGitStatusFileName")
        end
    end, lines)
end

function git:process_output(cmd_args, parser_fn)
    local output, code = self:run(cmd_args)
    if code ~= 0 then
        logger:error("error trying to execute git", { args = cmd_args, code = code, output = output })
    end

    local lines = vim.split(output or "", "\n", {})

    return {
        items = parser_fn(self, lines),
    }
end

function git:draw_content(ctx)
    local has_git_subfolder = async.fn.isdirectory(".git") == 1

    local groups = {
        Staged = {},
        Unstaged = {},
        Unmerged = {},
        Untracked = {},
    }

    if has_git_subfolder then
        groups = {
            Staged = self:process_output({ "diff", "--numstat", "--staged", "--diff-filter=u" }, self.parse_git_diff),
            Unstaged = self:process_output({ "diff", "--numstat", "--diff-filter=u" }, self.parse_git_diff),
            Unmerged = self:process_output({ "diff", "--numstat", "--diff-filter=U" }, self.parse_git_diff),
            Untracked = self:process_output({ "status", "--porcelain" }, self.parse_git_status),
        }
    end

    local loclist = Loclist:new(groups)

    return loclist:draw()
end

return git

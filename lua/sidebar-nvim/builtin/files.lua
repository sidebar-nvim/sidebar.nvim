local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local async = require("sidebar-nvim.lib.async")
local Loclist = require("sidebar-nvim.lib.loclist")
local utils = require("sidebar-nvim.utils")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")

local api = async.api

local files = Section:new({
    title = "Files",
    icon = "",
    show_hidden = false,
    ignored_paths = { "%.git$" },

    tree_icons = {
        directory_closed = "",
        directory_open = "",
        file = "",
        closed = "",
        opened = "",
    },

    yanked_files = {},
    cut_files = {},
    open_directories = {},

    history = { position = 0, groups = {} },
    trash_dir = vim.loop.os_homedir() .. "/.local/share/Trash/files/",

    reloaders = {
        reloaders.autocmd({ "BufLeave" }, "*"),
        reloaders.autocmd({ "ShellCmdPost" }, "term://*"),
    },

    highlights = {
        groups = {},
        links = {
            SidebarNvimFilesDirectory = "SidebarNvimSectionTitle",
            SidebarNvimFilesYanked = "SidebarNvimLabel",
            SidebarNvimFilesCut = "DiagnosticError",
        },
    },
})

function files:get_fileicon(filename)
    if has_devicons and devicons.has_loaded() then
        local extension = filename:match("^.+%.(.+)$")
        local fileicon, highlight = devicons.get_icon(filename, extension)

        if not highlight then
            highlight = "SidebarNvimNormal"
        end
        return { text = fileicon or self.tree_icons["file"], hl = highlight }
    end
    return { text = self.tree_icons["file"] .. " " }
end

-- scan directory recursively
function files:scan_dir(directory)
    if not self.open_directories[directory] then
        return
    end

    local show_hidden = self.show_hidden
    local children = {}
    local children_directories = {}
    local children_files = {}

    for filename, filetype in vim.fs.dir(directory) do
        local path = directory .. "/" .. filename
        local ignored = false

        for _, ignored_path in ipairs(self.ignored_paths or {}) do
            if string.match(path, ignored_path) then
                ignored = true
            end
        end

        if not ignored then
            if show_hidden or filename:sub(1, 1) ~= "." then
                if filetype == "file" then
                    table.insert(children_files, {
                        name = filename,
                        type = "file",
                        path = path,
                        parent = directory,
                    })
                elseif filetype == "directory" then
                    table.insert(children_directories, {
                        name = filename,
                        type = "directory",
                        path = path,
                        parent = directory,
                        children = self:scan_dir(directory .. "/" .. filename),
                    })
                end
            end
        end
    end

    table.sort(children_directories, function(a, b)
        return a.name < b.name
    end)
    vim.list_extend(children, children_directories)

    table.sort(children_files, function(a, b)
        return a.name < b.name
    end)
    vim.list_extend(children, children_files)

    return children
end

function files:build_loclist(directory, level)
    local items = {}

    if directory.children then
        for _, node in ipairs(directory.children) do
            if node.type == "file" then
                local icon = self:get_fileicon(node.name)
                local selected = { text = "" }

                if yanked_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesYanked" }
                elseif cut_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesCut" }
                end

                table.insert(
                    items,
                    LineBuilder:new(self:create_keymaps(node))
                        :left(string.rep("  ", level) .. icon.text .. " ", icon.hl)
                        :left(node.name)
                        :left(selected.text, selected.hl)
                )
            elseif node.type == "directory" then
                local icon
                if self.open_directories[node.path] then
                    icon = self.tree_icons["directory_open"]
                else
                    icon = self.tree_icons["directory_closed"]
                end

                local selected = { text = "" }

                if self.yanked_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesYanked" }
                elseif cut_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesCut" }
                end

                table.insert(
                    items,
                    LineBuilder:new(self:create_keymaps(node))
                        :left(string.rep("  ", level) .. icon .. " " .. node.name, "SidebarNvimFilesDirectory")
                        :left(selected.text, selected.hl)
                )
            end

            if node.type == "directory" and self.open_directories[node.path] then
                vim.list_extend(items, self:build_loclist(node, level + 1))
            end
        end
    end
    return items
end

local function exec(group)
    for _, op in ipairs(group.operations) do
        op.exec()
    end

    group.executed = true
end

-- undo the operation
local function undo(group)
    for _, op in ipairs(group.operations) do
        op.undo()
    end
end

local function copy_file(src, dest, confirm_overwrite)
    if confirm_overwrite and luv.fs_access(dest, "r") ~= false then
        local overwrite = vim.fn.input('file "' .. dest .. '" already exists. Overwrite? y/n: ')

        if overwrite ~= "y" then
            return
        end
    end

    luv.fs_copyfile(src, dest, function(err, _)
        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)
end

local function create_file(dest)
    if luv.fs_access(dest, "r") ~= false then
        vim.schedule(function()
            utils.echo_warning('file "' .. dest .. '" already exists.')
        end)
        return
    end

    local is_file = not dest:match("/$")
    local parent_folders = vim.fn.fnamemodify(dest, ":h")

    if not utils.file_exist(parent_folders) then
        local success = vim.fn.mkdir(parent_folders, "p")
        if not success then
            utils.echo_warning("Could not create directory " .. parent_folders)
        end
    end

    if is_file then
        luv.fs_open(dest, "w", 420, function(err, file)
            if err ~= nil then
                vim.schedule(function()
                    utils.echo_warning(err)
                end)
            else
                luv.fs_close(file)
            end
        end)
    end
end

local function delete_file(src, trash, confirm_deletion)
    if confirm_deletion then
        local delete = vim.fn.input('delete file "' .. src .. '"? y/n: ')

        if delete ~= "y" then
            return
        end
    end

    luv.fs_rename(src, trash, function(err, _)
        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)
end

local function move_file(src, dest, confirm_overwrite)
    if confirm_overwrite and luv.fs_access(dest, "r") ~= false then
        local overwrite = vim.fn.input('file "' .. dest .. '" already exists. Overwrite? y/n: ')

        if overwrite ~= "y" then
            return
        end
    end

    luv.fs_rename(src, dest, function(err, _)
        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)
end

function files:create_keymaps(node)
    local keymaps = {
        -- delete
        ["d"] = function()
            local operation
            operation = {
                exec = function()
                    delete_file(operation.src, operation.dest, true)
                end,
                undo = function()
                    move_file(operation.dest, operation.src, true)
                end,
                src = node.path,
                dest = self.trash_dir .. node.name,
            }
            local group = { executed = false, operations = { operation } }

            self.history.position = self.history.position + 1
            self.history.groups = vim.list_slice(self.history.groups, 1, self.history.position)
            self.history.groups[self.history.position] = group

            exec(group)
        end,
        -- yank
        ["y"] = function()
            self.yanked_files[node.path] = true
            self.cut_files = {}
        end,
        -- cut
        ["x"] = function()
            self.cut_files[node.path] = true
            self.yanked_files = {}
        end,
        -- paste
        ["p"] = function()
            local dest_dir

            if node.type == "directory" then
                dest_dir = node.path
            else
                dest_dir = node.parent
            end

            self.open_directories[dest_dir] = true

            local group = { executed = false, operations = {} }

            for path, _ in pairs(self.yanked_files) do
                local operation
                operation = {
                    exec = function()
                        copy_file(operation.src, operation.dest, true)
                    end,
                    undo = function()
                        delete_file(operation.dest, self.trash_dir .. utils.filename(operation.src), true)
                    end,
                    src = path,
                    dest = dest_dir .. "/" .. utils.filename(path),
                }
                table.insert(group.operations, operation)
            end

            for path, _ in pairs(self.cut_files) do
                local operation
                operation = {
                    exec = function()
                        move_file(operation.src, operation.dest, true)
                    end,
                    undo = function()
                        move_file(operation.dest, operation.src, true)
                    end,
                    src = path,
                    dest = dest_dir .. "/" .. utils.filename(path),
                }
                table.insert(group.operations, operation)
            end
            self.history.position = self.history.position + 1
            self.history.groups = vim.list_slice(self.history.groups, 1, self.history.position)
            self.history.groups[self.history.position] = group

            self.yanked_files = {}
            self.cut_files = {}

            exec(group)
        end,
        -- create
        ["c"] = function()
            local parent

            if node.type == "directory" then
                parent = node.path
            else
                parent = node.parent
            end

            self.open_directories[parent] = true

            local name = vim.fn.input("file name: ")

            if string.len(vim.trim(name)) == 0 then
                return
            end

            local operation

            operation = {
                success = true,
                exec = function()
                    create_file(operation.dest)
                end,
                undo = function()
                    delete_file(operation.dest, self.trash_dir .. name, true)
                end,
                src = nil,
                dest = parent .. "/" .. name,
            }

            local group = { executed = false, operations = { operation } }

            self.history.position = self.history.position + 1
            self.history.groups = vim.list_slice(self.history.groups, 1, self.history.position)
            self.history.groups[self.history.position] = group

            exec(group)
        end,
        -- open current file
        ["e"] = function()
            if node.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. node.path)
            else
                if self.open_directories[node.path] == nil then
                    self.open_directories[node.path] = true
                else
                    self.open_directories[node.path] = nil
                end
            end
        end,
        -- rename
        ["r"] = function()
            local new_name = vim.fn.input('rename file "' .. node.name .. '" to: ')
            local operation

            operation = {
                exec = function()
                    move_file(operation.src, operation.dest, true)
                end,
                undo = function()
                    move_file(operation.dest, operation.src, true)
                end,
                src = node.path,
                dest = node.parent .. "/" .. new_name,
            }

            local group = { executed = false, operations = { operation } }

            self.history.position = self.history.position + 1
            self.history.groups = vim.list_slice(self.history.groups, 1, self.history.position)
            self.history.groups[self.history.position] = group

            exec(group)
        end,
        -- undo
        ["u"] = function(_)
            if self.history.position > 0 then
                undo(self.history.groups[self.history.position])
                self.history.position = self.history.position - 1
            end
        end,
        -- redo
        ["<C-r>"] = function(_)
            if self.history.position < #self.history.groups then
                self.history.position = self.history.position + 1
                exec(self.history.groups[self.history.position])
            end
        end,
        ["<CR>"] = function()
            if node.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. node.path)
            else
                if self.open_directories[node.path] == nil then
                    self.open_directories[node.path] = true
                else
                    self.open_directories[node.path] = nil
                end
            end
        end,
    }

    return keymaps
end

function files:draw_content()
    local cwd = api.fn.getcwd()
    local group_name = utils.shortest_path(cwd)

    self.open_directories[cwd] = true

    local node = { path = cwd, children = self:scan_dir(cwd) }

    local groups = {
        [group_name] = { items = self:build_loclist(node, 0), is_closed = not self.open_directories[cwd] },
    }

    local loclist = Loclist:new(groups, { omit_single_group = false, show_group_count = false })
    return loclist:draw()
end

return files

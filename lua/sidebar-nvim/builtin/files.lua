local utils = require("sidebar-nvim.utils")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local luv = vim.loop

local loclist = Loclist:new({ omit_single_group = false, show_group_count = false })

local icons = {
    directory_closed = "",
    directory_open = "",
    file = "",
    closed = "",
    opened = "",
}

local yanked_files = {}
local cut_files = {}
local open_directories = {}

local history = { position = 0, groups = {} }
local trash_dir = luv.os_homedir() .. "/.local/share/Trash/files/"

local function get_fileicon(filename)
    if has_devicons and devicons.has_loaded() then
        local extension = filename:match("^.+%.(.+)$")
        local fileicon, _ = devicons.get_icon_color(filename, extension)
        local highlight = "SidebarNvimNormal"

        if extension then
            highlight = "DevIcon" .. extension
        end
        return { text = fileicon or icons["file"], hl = highlight }
    end
    return { text = icons["file"] .. " " }
end

-- scan directory recursively
local function scan_dir(directory)
    if not open_directories[directory] then
        return
    end

    local show_hidden = config.files.show_hidden
    local handle = luv.fs_scandir(directory)
    local children = {}
    local children_directories = {}
    local children_files = {}

    while handle do
        local filename, filetype = luv.fs_scandir_next(handle)

        if not filename then
            break
        end

        local path = directory .. "/" .. filename
        local ignored = false

        for _, ignored_path in ipairs(config.files.ignored_paths or {}) do
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
                        children = scan_dir(directory .. "/" .. filename),
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

local function build_loclist(group, directory, level)
    local loclist_items = {}

    if directory.children then
        for _, node in ipairs(directory.children) do
            if node.type == "file" then
                local icon = get_fileicon(node.name)
                local selected = { text = "" }

                if yanked_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesYanked" }
                elseif cut_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesCut" }
                end

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        { text = string.rep("  ", level) .. icon.text .. " ", hl = icon.hl },
                        { text = node.name },
                        selected,
                    },
                    name = node.name,
                    path = node.path,
                    type = node.type,
                    parent = node.parent,
                    node = node,
                }
            elseif node.type == "directory" then
                local icon
                if open_directories[node.path] then
                    icon = icons["directory_open"]
                else
                    icon = icons["directory_closed"]
                end

                local selected = { text = "" }

                if yanked_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesYanked" }
                elseif cut_files[node.path] then
                    selected = { text = " *", hl = "SidebarNvimFilesCut" }
                end

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        {
                            text = string.rep("  ", level) .. icon .. " " .. node.name,
                            hl = "SidebarNvimFilesDirectory",
                        },
                        selected,
                    },
                    name = node.name,
                    path = node.path,
                    type = node.type,
                    parent = node.parent,
                    node = node,
                }
            end

            if node.type == "directory" and open_directories[node.path] then
                vim.list_extend(loclist_items, build_loclist(group, node, level + 1))
            end
        end
    end
    return loclist_items
end

local function update(group, directory)
    local node = { path = directory, children = scan_dir(directory) }

    loclist:set_items(build_loclist(group, node, 0), { remove_groups = true })
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

local function get_length(iter)
    local length = 0
    for _ in iter do
        length = length + 1
    end
    return length
end

local function create_file(dest)
    if luv.fs_access(dest, "r") ~= false then
        vim.schedule(function()
            utils.echo_warning('file "' .. dest .. '" already exists.')
        end)
        return
    end
    local is_file = not dest:match("/" .. "$")
    local last_path_length = get_length(utils.path_split(dest))
    local now_length = 0
    local now_check_path = ""

    for path in utils.path_split(dest) do
        now_length = now_length + 1
        now_check_path = now_check_path .. path
        if is_file and now_length == last_path_length then
            luv.fs_open(dest, "w", 420, function(err, file)
                if err ~= nil then
                    vim.schedule(function()
                        utils.echo_warning(err)
                    end)
                else
                    luv.fs_close(file)
                end
            end)
        else if not utils.file_exist(now_check_path) then
                local success = luv.fs_mkdir(now_check_path, 493)
                if not success then
                    utils.echo_warning('Could not create directory "' .. now_check_path)
                end
            end
        end
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

return {
    title = "Files",
    icon = config["files"].icon,
    setup = function(_)
        vim.api.nvim_exec(
            [[
          augroup sidebar_nvim_files_update
              autocmd!
              autocmd ShellCmdPost * lua require'sidebar-nvim.builtin.files'.update()
              autocmd BufLeave term://* lua require'sidebar-nvim.builtin.files'.update()
          augroup END
          ]] ,
            false
        )
    end,
    update = function(_)
        local cwd = vim.fn.getcwd()
        local group = utils.shortest_path(cwd)

        open_directories[cwd] = true

        update(group, cwd)
    end,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        return { lines = lines, hl = hl }
    end,

    highlights = {
        groups = {},
        links = {
            SidebarNvimFilesDirectory = "SidebarNvimSectionTitle",
            SidebarNvimFilesYanked = "SidebarNvimLabel",
            SidebarNvimFilesCut = "DiagnosticError",
        },
    },

    bindings = {
        -- delete
        ["d"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            local operation
            operation = {
                exec = function()
                    delete_file(operation.src, operation.dest, true)
                end,
                undo = function()
                    move_file(operation.dest, operation.src, true)
                end,
                src = location.node.path,
                dest = trash_dir .. location.node.name,
            }
            local group = { executed = false, operations = { operation } }

            history.position = history.position + 1
            history.groups = vim.list_slice(history.groups, 1, history.position)
            history.groups[history.position] = group

            exec(group)
        end,
        -- yank
        ["y"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            yanked_files[location.node.path] = true
            cut_files = {}
        end,
        -- cut
        ["x"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            cut_files[location.node.path] = true
            yanked_files = {}
        end,
        -- paste
        ["p"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            local dest_dir

            if location.node.type == "directory" then
                dest_dir = location.node.path
            else
                dest_dir = location.node.parent
            end

            open_directories[dest_dir] = true

            local group = { executed = false, operations = {} }

            for path, _ in pairs(yanked_files) do
                local operation
                operation = {
                    exec = function()
                        copy_file(operation.src, operation.dest, true)
                    end,
                    undo = function()
                        delete_file(operation.dest, trash_dir .. utils.filename(operation.src), true)
                    end,
                    src = path,
                    dest = dest_dir .. "/" .. utils.filename(path),
                }
                table.insert(group.operations, operation)
            end

            for path, _ in pairs(cut_files) do
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
            history.position = history.position + 1
            history.groups = vim.list_slice(history.groups, 1, history.position)
            history.groups[history.position] = group

            yanked_files = {}
            cut_files = {}

            exec(group)
        end,
        -- create
        ["c"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            local parent

            if location.type == "directory" then
                parent = location.path
            else
                parent = location.parent
            end

            open_directories[parent] = true

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
                    delete_file(operation.dest, trash_dir .. name, true)
                end,
                src = nil,
                dest = parent .. "/" .. name,
            }

            local group = { executed = false, operations = { operation } }

            history.position = history.position + 1
            history.groups = vim.list_slice(history.groups, 1, history.position)
            history.groups[history.position] = group

            exec(group)
        end,
        -- open current file
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            if location.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. location.node.path)
            else
                if open_directories[location.node.path] == nil then
                    open_directories[location.node.path] = true
                else
                    open_directories[location.node.path] = nil
                end
            end
        end,
        -- rename
        ["r"] = function(line)
            local location = loclist:get_location_at(line)

            if location == nil then
                return
            end

            local new_name = vim.fn.input('rename file "' .. location.node.name .. '" to: ')
            local operation

            operation = {
                exec = function()
                    move_file(operation.src, operation.dest, true)
                end,
                undo = function()
                    move_file(operation.dest, operation.src, true)
                end,
                src = location.node.path,
                dest = location.node.parent .. "/" .. new_name,
            }

            local group = { executed = false, operations = { operation } }

            history.position = history.position + 1
            history.groups = vim.list_slice(history.groups, 1, history.position)
            history.groups[history.position] = group

            exec(group)
        end,
        -- undo
        ["u"] = function(_)
            if history.position > 0 then
                undo(history.groups[history.position])
                history.position = history.position - 1
            end
        end,
        -- redo
        ["<C-r>"] = function(_)
            if history.position < #history.groups then
                history.position = history.position + 1
                exec(history.groups[history.position])
            end
        end,
        ["<CR>"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            if location.node.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. location.node.path)
            else
                if open_directories[location.node.path] == nil then
                    open_directories[location.node.path] = true
                else
                    open_directories[location.node.path] = nil
                end
            end
        end,
    },
}

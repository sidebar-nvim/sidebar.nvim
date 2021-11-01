local utils = require("sidebar-nvim.utils")
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local Debouncer = require("sidebar-nvim.debouncer")
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local luv = vim.loop

local loclist = Loclist:new({ ommit_single_group = false, show_group_count = false })

local icons = {
    directory_closed = "",
    directory_open = "",
    file = "",
    closed = "",
    opened = "",
}

local file_status = {}
local current_cmd = {}
local trash_dir = luv.os_homedir() .. "/.local/share/Trash/files/"

local function get_fileicon(filename)
    if has_devicons and devicons.has_loaded() then
        local extension = filename:match("^.+%.(.+)$")
        local fileicon, _ = devicons.get_icon_color(filename, extension)
        local highlight = "SidebarNvimNormal"

        if extension then
            highlight = "DevIcon" .. extension
        end
        return { text = fileicon, hl = highlight }
    else
        return { text = icons["file"] .. " " }
    end
end

-- scan directory recursively
local function scan_dir(directory)
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
        local status

        if not file_status[path] then
            file_status[path] = { open = false, selected = false }
            status = file_status[path]
        else
            status = file_status[path]
        end

        if show_hidden or filename:sub(1, 1) ~= "." then
            if filetype == "file" then
                table.insert(children_files, {
                    name = filename,
                    type = "file",
                    status = status,
                    path = directory .. "/" .. filename,
                    parent = directory,
                })
            elseif filetype == "directory" then
                table.insert(children_directories, {
                    name = filename,
                    type = "directory",
                    status = status,
                    path = directory .. "/" .. filename,
                    parent = directory,
                    children = scan_dir(directory .. "/" .. filename),
                })
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
                local selected = ""

                if node.status.selected then
                    selected = " *"
                end

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        { text = string.rep("  ", level) .. icon.text .. " ", hl = icon.hl },
                        { text = node.name },
                        { text = selected, hl = "SidebarNvimFilesSelected" },
                    },
                    name = node.name,
                    path = node.path,
                    type = node.type,
                    parent = node.parent,
                    status = node.status,
                    node = node,
                }
            elseif node.type == "directory" then
                local icon
                if node.open then
                    icon = icons["directory_open"]
                else
                    icon = icons["directory_closed"]
                end

                local selected = ""

                if node.status.selected then
                    selected = " *"
                end

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        {
                            text = string.rep("  ", level) .. icon .. " " .. node.name,
                            hl = "SidebarNvimFilesDirectory",
                        },
                        { text = selected, hl = "SidebarNvimFilesSelected" },
                    },
                    name = node.name,
                    path = node.path,
                    type = node.type,
                    parent = node.parent,
                    status = node.status,
                    node = node,
                }
            end

            if node.type == "directory" and node.status.open then
                vim.list_extend(loclist_items, build_loclist(group, node, level + 1))
            end
        end
    end
    return loclist_items
end

local function update(group, directory)
    local cwd = { path = directory, children = scan_dir(directory) }

    loclist:set_items(build_loclist(group, cwd, 0), { remove_groups = true })
end

local function exec(cmd, args)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)
    local handle

    handle = luv.spawn(cmd, { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() }, function()
        vim.schedule(function()
            local cwd = vim.fn.getcwd()
            local group = utils.shortest_path(cwd)

            update(group, cwd)
        end)

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    luv.read_start(stdout, function(err, data)
        if err ~= nil then
            vim.schedule(function()
                utils.echo_warning(err)
            end)
        end
    end)

    luv.read_start(stderr, function(err, data)
        if data ~= nil then
            vim.schedule(function()
                utils.echo_warning(data)
            end)
        end

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
          ]],
            false
        )
    end,
    update = function(_)
        local cwd = vim.fn.getcwd()
        local group = utils.shortest_path(cwd)

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
            SidebarNvimFilesSelected = "SidebarNvimLabel",
        },
    },

    bindings = {
        ["t"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            if location.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. location.path)
            else
                location.status.open = not location.status.open
            end
        end,
        ["d"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            exec("mv", { location.node.path, trash_dir })
        end,
        ["y"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            location.status.selected = true

            if current_cmd.cmd ~= "cp" then
                current_cmd.cmd = "cp"
                current_cmd.args = { "-r", location.node.path }
            else
                current_cmd.args[#current_cmd.args + 1] = location.node.path
            end
        end,
        ["x"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            location.status.selected = true

            if current_cmd.cmd ~= "mv" then
                current_cmd.cmd = "mv"
                current_cmd.args = { location.node.path }
            else
                current_cmd.args[#current_cmd.args + 1] = location.node.path
            end
        end,
        ["p"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end

            local dest

            if location.type == "directory" then
                dest = location.path
            else
                dest = location.parent
            end

            if file_status[dest] then
                file_status[dest].open = true
            end

            current_cmd.args[#current_cmd.args + 1] = dest
            exec(current_cmd.cmd, current_cmd.args)

            for _, path in ipairs(current_cmd.args) do
                if file_status[path] then
                    file_status[path].selected = false
                end
            end
            current_cmd = {}
        end,
        ["e"] = function(line)
            --TODO: create
        end,
        ["r"] = function(line)
            --TODO: rename
        end,
        ["u"] = function(line)
            -- TODO: undo
        end,
    },
}

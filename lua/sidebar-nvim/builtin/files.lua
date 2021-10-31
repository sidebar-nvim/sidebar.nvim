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

local root = nil

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

    while true do
        local filename, filetype = luv.fs_scandir_next(handle)

        if not filename then
            break
        end

        if show_hidden or filename:sub(1, 1) ~= "." then
            if filetype == "file" then
                table.insert(
                    children_files,
                    { name = filename, type = "file", open = false, path = directory .. "/" .. filename }
                )
            elseif filetype == "directory" then
                table.insert(children_directories, {
                    name = filename,
                    type = "directory",
                    open = false,
                    path = directory .. "/" .. filename,
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

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        { text = string.rep("  ", level) .. icon.text .. " ", hl = icon.hl },
                        { text = node.name },
                    },
                    node = node,
                }
            elseif node.type == "directory" then
                local icon
                if node.open then
                    icon = icons["directory_open"]
                else
                    icon = icons["directory_closed"]
                end

                loclist_items[#loclist_items + 1] = {
                    group = group,
                    left = {
                        {
                            text = string.rep("  ", level) .. icon .. " " .. node.name,
                            hl = "SidebarNvimFilesDirectory",
                        },
                    },
                    node = node,
                }
            end

            if node.type == "directory" and node.open then
                vim.list_extend(loclist_items, build_loclist(group, node, level + 1))
            end
        end
    end
    return loclist_items
end

local function update(group, directory)
    if not root then
        root = { path = directory, children = scan_dir(directory) }
    end

    loclist:set_items(build_loclist(group, root, 0), { remove_groups = true })
end

-- local async_update_debounced = Debouncer:new(get_files, 1000)

return {
    title = "Files",
    icon = config["files"].icon,
    setup = function(ctx)
        -- get_files(ctx)
    end,
    update = function(ctx)
        local cwd = vim.fn.getcwd()
        update(utils.shortest_path(cwd), cwd)
        -- async_update_debounced:call(ctx)
        -- update_files()
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
        },
    },

    bindings = {
        ["t"] = function(line)
            loclist:toggle_group_at(line)
        end,
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then
                return
            end
            if location.node.type == "file" then
                vim.cmd("wincmd p")
                vim.cmd("e " .. location.node.path)
            else
                location.node.open = not location.node.open
            end
        end,
    },
}

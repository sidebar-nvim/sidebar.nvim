local Component = require("sidebar-nvim.components.basic")

local Loclist = {}

Loclist.DEFAULT_OPTIONS = {
    groups = {},
    group_icon = { closed = "", opened = "" },
    -- badge showing the number of items in each group
    show_group_count = true,
    -- line and col numbers
    show_location = true,
    -- if there's a single group, skip rendering the group controls
    ommit_single_group = false,
    -- initial state of the groups
    groups_initially_closed = false,
    highlights = {
        group = "SidebarNvimLabel",
        group_count = "SidebarNvimNormal",
        item_icon = "SidebarNvimNormal",
        item_lnum = "SidebarNvimLineNr",
        item_col = "SidebarNvimLineNr",
        item_text = "SidebarNvimNormal",
    },
}

setmetatable(Loclist, { __index = Component })

-- creates a new loclist component
-- @param (table) o
-- |- (table) o.groups list of groups containing (table) items. See Loclist:add_item
-- |- (boolean) o.show_group_count show a badge after the group name with the count of items contained in the group
-- |- (boolean) o.ommit_single_group whether this component should draw the group line if there's only one group present
function Loclist:new(o)
    o = vim.tbl_deep_extend("force", vim.deepcopy(Loclist.DEFAULT_OPTIONS), o or {}, {
        -- table(line_number -> group ref)
        _group_indexes = {},
        -- table(line__number -> item ref)
        _location_indexes = {},
        -- used to keep the group list stable
        _group_keys = {},
    })

    o._group_keys = vim.tbl_keys(o.groups or {})

    setmetatable(o, self)
    self.__index = self
    return o
end

-- adds a new item to the loclist
-- @param (table) item
-- |- (string) item.group the group name that this item will live
-- |- (number) item.lnum the line number of this item
-- |- (number) item.col the col number of this item
-- |- (string) item.text
-- |- (table) item.icon
-- |--|- (string) item.icon.text
-- |--|- (string) item.icon.hl override the default icon highlight group
-- |- (number) item.order items are sorted based on order within each group
function Loclist:add_item(item)
    if not self.groups[item.group] then
        self.groups[item.group] = { is_closed = self.groups_initially_closed or false }
    end

    if not vim.tbl_contains(self._group_keys, item.group) then
        table.insert(self._group_keys, item.group)
    end

    item.lnum = item.lnum or 0
    item.col = item.col or 0
    item.order = item.order or 0

    table.insert(self.groups[item.group], item)
    table.sort(self.groups[item.group], function(a, b)
        return a.order < b.order
    end)
end

-- replace all the items with the new list
-- @param (table) list of items
-- |- items[...]
-- |-- (string) item.group the group name that this item will live
-- |-- (number) item.lnum the line number of this item
-- |-- (number) item.col the col number of this item
-- |-- (string) item.text
-- |-- (string) item.icon
-- |- clear_opts (table) see Loclist:clear
function Loclist:set_items(items, clear_opts)
    self:clear(clear_opts)

    for _, item in pairs(items) do
        self:add_item(item)
    end
    self._group_keys = vim.tbl_keys(self.groups)
end

-- clear all the groups
-- @param opts (table)
-- |- opts.remove_groups (boolean) also remove groups from the list, otherwise only items will be removed, removing groups from the list also means that the state of groups will be cleared
function Loclist:clear(opts)
    opts = opts or {}

    if opts.remove_groups then
        self.groups = {}
        self._group_keys = {}
        return
    end

    for _, key in ipairs(self._group_keys) do
        self.groups[key] = { is_closed = self.groups[key].is_closed }
    end
end

function Loclist:draw_group(ctx, group_name, with_label, section_lines, section_hl)
    local group = self.groups[group_name]

    if with_label then
        local icon = self.group_icon.opened
        if group.is_closed then
            icon = self.group_icon.closed
        end

        local group_title = icon .. " " .. group_name

        local line = group_title

        if line:len() > ctx.width - 1 then
            line = line:sub(1, ctx.width - 5) .. "..."
        end

        local offset = ctx.width - #line - 2
        line = line .. string.rep(" ", offset)

        table.insert(section_hl, { self.highlights.group, #section_lines, 0, #line - offset })

        if self.show_group_count then
            table.insert(section_hl, { self.highlights.group_count, #section_lines, #line, -1 })
            local total = #group
            if total > 99 then
                total = "++"
            end
            line = line .. total
        end

        self._group_indexes[#section_lines] = group
        table.insert(section_lines, line)
    end

    if group.is_closed then
        return
    end

    for _, item in ipairs(group) do
        self._location_indexes[#section_lines] = item
        local line = ""

        if with_label then
            line = "│ "
        end

        if item.icon then
            table.insert(
                section_hl,
                { item.icon.hl or self.highlights.item_icon, #section_lines, #line, #line + #item.icon.text }
            )
            line = line .. item.icon.text .. " "
        end

        if self.show_location then
            local lnum = "" .. item.lnum
            table.insert(section_hl, { self.highlights.item_lnum, #section_lines, #line + 1, #line + #lnum + 1 })
            line = line .. " " .. lnum .. ":"

            local col = "" .. item.col
            table.insert(section_hl, { self.highlights.item_col, #section_lines, #line, #line + #col })
            line = line .. col .. " "
        end

        table.insert(section_hl, { self.highlights.item_text, #section_lines, #line, -1 })
        line = line .. item.text

        table.insert(section_lines, line)
    end
end

-- convert the current data structure into a list of lines + highlight groups
-- @return (table) list of lines (strings)
-- @return (table) list of hl groups
function Loclist:draw(ctx, section_lines, section_hl)
    self._group_indexes = {}
    self._location_indexes = {}

    if #self._group_keys == 1 and self.ommit_single_group then
        self:draw_group(ctx, self._group_keys[1], false, section_lines, section_hl)
        return
    end

    for _, group_name in ipairs(self._group_keys) do
        self:draw_group(ctx, group_name, true, section_lines, section_hl)
    end
end

-- returns the location specified in the location printed on line `line`
-- if the line does not have a location rendered, return nil
-- @param (number) line
function Loclist:get_location_at(line)
    local location = self._location_indexes[line]
    return location
end

-- toggles the group open/close that is printed on line `line`
-- if there is no group at `line`, then do nothing
-- @param (number) line
function Loclist:toggle_group_at(line)
    local group = self._group_indexes[line]
    if not group then
        return
    end

    group.is_closed = not group.is_closed
end

-- Toggle group with name `group_name`
-- @param group_name string: the name of group to toggle
function Loclist:toggle_group(group_name)
    local group = self.groups[group_name]
    if not group then
        return
    end

    group.is_closed = not group.is_closed
end

-- Open group with name `group_name`
-- @param group_name string: the name of group to open
function Loclist:open_group(group_name)
    local group = self.groups[group_name]
    if not group then
        return
    end

    group.is_closed = false
end

-- Close group with name `group_name`
-- @param group_name string: the name of group to close
function Loclist:close_group(group_name)
    local group = self.groups[group_name]
    if not group then
        return
    end

    group.is_closed = true
end

-- toggle all groups
function Loclist:toggle_all_groups()
    for _, group in pairs(self.groups) do
        group.is_closed = not group.is_closed
    end
end

-- opens all groups
function Loclist:open_all_groups()
    for _, group in pairs(self.groups) do
        group.is_closed = false
    end
end

-- closes all groups
function Loclist:close_all_groups()
    for _, group in pairs(self.groups) do
        group.is_closed = true
    end
end

return Loclist

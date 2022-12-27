local LineBuilder = require("sidebar-nvim.lib.line_builder")

local LocListProps = {
    group_icon_set = { closed = "", opened = "" },

    -- badge showing the number of items in each group
    show_group_count = true,
    -- if empty groups should be displayed
    show_empty_groups = true,
    -- if there's a single group, skip rendering the group controls
    omit_single_group = false,
    -- highlight groups for each control element
    highlights = {
        group_name = "SidebarNvimLabel",
        group_icon = "SidebarNvimLabel",
        group_count = "SidebarNvimSectionTitle",
    },
}

local LocList = {}

LocList.__index = LocList

function LocList:new(groups, opts)
    local obj = vim.tbl_extend("force", {}, LocListProps, opts or {})

    obj.groups = groups or {}

    obj = setmetatable(obj, self)

    return obj
end

function LocList:draw_group(ctx, name, with_name)
    local group = vim.tbl_extend("force", { items = {} }, self.groups[name])

    if #group.items == 0 and not self.show_empty_groups then
        return {}
    end

    local ret = {}

    local group_is_closed = group.is_closed

    if with_name then
        local icon = self.group_icon_set.opened
        if #group.items == 0 or group_is_closed then
            icon = self.group_icon_set.closed
        end

        local icon_hl = self.highlights.group_icon

        if group.icon then
            icon = group.icon.text or icon
            icon_hl = group.icon.hl or icon_hl
        end

        local line = LineBuilder:new({
            keymaps = group.keymaps,
        })
            :left(icon, icon_hl)
            :left(" ")
            :left(name, group.hl or self.highlights.group_name)

        if self.show_group_count then
            local total = #group.items
            if total > 99 then
                total = "++"
            end
            line = line:left(string.format(" (%s)", total), group.count_hl or self.highlights.group_count)
        end

        table.insert(ret, line)
    end

    if group_is_closed then
        return ret
    end

    for _, item in ipairs(group.items) do
        table.insert(ret, item)
    end

    return ret
end

function LocList:draw(ctx)
    local group_keys = vim.tbl_keys(self.groups)

    if #group_keys == 1 and self.omit_single_group then
        return self:draw_group(ctx, group_keys[1], false)
    end

    local ret = {}

    for _, name in ipairs(group_keys) do
        for _, line in ipairs(self:draw_group(ctx, name, true)) do
            table.insert(ret, line)
        end
    end

    return ret
end

return LocList

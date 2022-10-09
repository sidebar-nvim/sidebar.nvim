local LineBuilder = require("sidebar-nvim.lib.line_builder")

local SectionProps = {
    title = "",
    icon = "",
    reloaders = {},
    highlights = {
        groups = {},
        links = {},
    },
    state = {
        extmark_id = nil,
    },
}

local Section = {}

Section.__index = Section

function Section:new(opts)
    opts = vim.tbl_extend(
        "force",
        vim.deepcopy(SectionProps),
        self,
        opts or {},
        { state = vim.deepcopy(SectionProps.state) }
    )

    local obj = setmetatable(opts, self)

    return obj
end

function Section:with(opts_overrides)
    return self:new(opts_overrides)
end

function Section:get_title()
    return self.title
end

function Section:get_icon()
    return self.icon
end

function Section:get_header()
    return LineBuilder:new():left(self:get_icon() .. " " .. self:get_title())
end

-- @param ctx table
function Section:update(ctx)
    return {}
end

function Section:draw(ctx)
    local ret = {
        self:get_header(),
    }

    for _, line in ipairs(self:update(ctx)) do
        table.insert(ret, line)
    end

    return ret
end

return Section

local LineBuilder = require("sidebar-nvim.lib.line_builder")

local SectionProps = {
    title = "",
    icon = "",
    reloaders = {},
    highlights = {
        groups = {},
        links = {},
    },
    _internal_state = {
        extmark_id = nil,
        invalidate_cb = nil,
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
        { _internal_state = vim.deepcopy(SectionProps._internal_state) }
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
    return { LineBuilder:new():left(self:get_icon() .. " " .. self:get_title()), LineBuilder:empty() }
end

function Section:get_footer()
    return { LineBuilder:empty() }
end

-- @param ctx table
function Section:draw_content(ctx)
    return {}
end

function Section:draw(ctx)
    local ret = self:get_header()

    for _, line in ipairs(self:draw_content(ctx)) do
        table.insert(ret, line)
    end

    for _, line in ipairs(self:get_footer()) do
        table.insert(ret, line)
    end

    return ret
end

function Section:invalidate()
    if self._internal_state.invalidate_cb then
        self._internal_state.invalidate_cb()
    end
end

return Section

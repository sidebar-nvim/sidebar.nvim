local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local logger = require("sidebar-nvim.logger")
local has_luatz, luatz = pcall(require, "luatz")
local _, timetable = pcall(require, "luatz.timetable")

local function get_clock_value_using_luatz(clock, format)
    local dt = luatz.time()

    local tzinfo = luatz.get_tz(clock.tz)
    if tzinfo then
        dt = tzinfo:localise(dt)
    else
        logger:warn(string.format("tz '%s' not found", clock.tz))
    end

    return luatz.strftime.strftime(format, timetable.new_from_timestamp(dt))
end

local datetime = Section:new({
    title = "Current datetime",
    icon = "",
    format = "%a %b %d, %H:%M",
    clocks = { { name = "local" } },

    reloaders = { reloaders.interval(1000) },

    highlights = {
        groups = {},
        links = {
            SidebarNvimDatetimeClockName = "SidebarNvimComment",
            SidebarNvimDatetimeClockValue = "SidebarNvimNormal",
        },
    },
})

function datetime:validate_config()
    if not self.clocks or #self.clocks == 0 then
        return true, {}
    end

    for _, clock in ipairs(self.clocks) do
        if clock.tz then
            if not has_luatz then
                P({ has_luatz = has_luatz, luatz = luatz })
                logger:warn("luatz not installed. Cannot use 'tz' option without luatz")
                local config_error_messages = { "luatz not installed.", "Cannot use 'tz' option without luatz" }
                return false, config_error_messages
            end
        end
    end

    return true, {}
end

function datetime:draw_content()
    local lines = {}

    local is_config_valid, config_error_messages = self:validate_config()

    if not is_config_valid then
        for _, msg in ipairs(config_error_messages) do
            local line = LineBuilder:new():left(msg)
            table.insert(lines, line)
        end
        return lines
    end

    if not self.clocks or #self.clocks == 0 then
        table.insert(lines, LineBuilder:new():left("<no clocks>"))
        return lines
    end

    local clocks_num = #self.clocks
    for i, clock in ipairs(self.clocks) do
        local format = clock.format or self.format

        local clock_value
        if has_luatz then
            clock_value = get_clock_value_using_luatz(clock, format)
        else
            local offset = clock.offset or 0
            clock_value = os.date(format, os.time() + offset * 60 * 60)
        end

        table.insert(
            lines,
            LineBuilder:new():left("# " .. (clock.name or clock.offset or clock.tz), "SidebarNvimDatetimeClockName")
        )

        table.insert(lines, LineBuilder:new():left(clock_value, "SidebarNvimDatetimeClockValue"))

        if i < clocks_num then
            table.insert(lines, LineBuilder:empty())
        end
    end

    return lines
end

return datetime

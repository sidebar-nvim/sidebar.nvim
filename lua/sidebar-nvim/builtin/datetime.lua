local config = require("sidebar-nvim.config")
local utils = require("sidebar-nvim.utils")
local has_luatz, luatz = pcall(require, "luatz")
local _, timetable = pcall(require, "luatz.timetable")

local is_config_valid = false
local config_error_messages = ""

local function get_clock_value_using_luatz(clock, format)
    local dt = luatz.time()

    local tzinfo = luatz.get_tz(clock.tz)
    if tzinfo then
        dt = tzinfo:localise(dt)
    else
        utils.echo_warning(string.format("tz '%s' not found", clock.tz))
    end

    return luatz.strftime.strftime(format, timetable.new_from_timestamp(dt))
end

local function validate_config()
    if not config.datetime or not config.datetime.clocks or #config.datetime.clocks == 0 then
        is_config_valid = true
        return
    end

    for i, clock in ipairs(config.datetime.clocks) do
        if clock.tz then
            if not has_luatz then
                utils.echo_warning("luatz not installed. Cannot use 'tz' option without luatz")
                config_error_messages = { "luatz not installed.", "Cannot use 'tz' option without luatz" }
                is_config_valid = false
                return
            end
        end
    end

    is_config_valid = true
end

return {
    title = "Current datetime",
    icon = config.datetime.icon,
    setup = function()
        validate_config()
    end,
    draw = function()
        local lines = {}
        local hl = {}

        if not is_config_valid then
            for _, msg in ipairs(config_error_messages) do
                table.insert(lines, msg)
            end
            return { lines = lines, hl = hl }
        end

        if not config.datetime or not config.datetime.clocks or #config.datetime.clocks == 0 then
            table.insert(lines, "<no clocks>")
            return { lines = lines, hl = hl }
        end

        local clocks_num = #config.datetime.clocks
        for i, clock in ipairs(config.datetime.clocks) do
            local format = clock.format or config.datetime.format

            local clock_value
            if has_luatz then
                clock_value = get_clock_value_using_luatz(clock, format)
            else
                local offset = clock.offset or 0
                clock_value = os.date(format, os.time() + offset * 60 * 60)
            end

            table.insert(hl, { "SidebarNvimDatetimeClockName", #lines, 0, -1 })
            table.insert(lines, "# " .. (clock.name or clock.offset or clock.tz))

            table.insert(hl, { "SidebarNvimDatetimeClockValue", #lines, 0, -1 })
            table.insert(lines, clock_value)

            if i < clocks_num then
                table.insert(lines, "")
            end
        end

        return { lines = lines, hl = hl }
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimDatetimeClockName = "SidebarNvimComment",
            SidebarNvimDatetimeClockValue = "SidebarNvimNormal",
        },
    },
}

local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")

local test_section = Section:new({
    title = "test interval",
    icon = "#",

    reloaders = { reloaders.interval(1000) },

    format = "value: %d",
    value = 0,
})

function test_section:draw_content()
    self.value = self.value + 1
    return {
        LineBuilder:new({
            keymaps = {
                u = function()
                    self.value = self.value + 1
                end,
            },
        }):left(string.format(self.format, self.value)),
    }
end

return test_section

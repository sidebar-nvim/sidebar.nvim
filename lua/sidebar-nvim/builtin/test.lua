local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")

local test_section = Section:new({
    title = "test",
    icon = "#",

    reloaders = {},

    value = 0,
})

function test_section:draw_content()
    return {
        LineBuilder:new({
            keymaps = {
                u = function()
                    self.value = self.value + 1
                end,
            },
        }):left(string.format("value: %d", self.value)),
    }
end

return test_section

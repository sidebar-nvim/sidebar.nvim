local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")

local test_section = Section:new({
    title = "test",
    icon = "#",

    reloaders = { reloaders.file_changed("test.txt") },

    format = "value: %d",
    value = 0,

    keymaps = {
        increment_value = "u",
        increment_value_2 = "c",
    },
})

function test_section:increment_value()
    self.value = self.value + 1
end

function test_section:increment_value_2()
    print("hello world")
end

function test_section:get_default_keymaps()
    return self:bind_keymaps({}, { filter = { "increment_value_2" } })
end

function test_section:draw_content()
    return {
        LineBuilder:new({
            keymaps = self:bind_keymaps({}, { filter = { "increment_value" } }),
        }):left(string.format(self.format, self.value)),
    }
end

return test_section

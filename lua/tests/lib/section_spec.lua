local LineBuilder = require("sidebar-nvim.lib.line_builder")
local Section = require("sidebar-nvim.lib.section")

local eq = assert.are.same

describe("Section", function()
    it("get title", function()
        local section = Section:new({ title = "test" })
        eq("test", section:get_title())
    end)

    it("get icon", function()
        local section = Section:new({ title = "test", icon = "#" })
        eq("#", section:get_icon())
    end)

    it("get header", function()
        local section = Section:new({ title = "test", icon = "#" })
        eq(LineBuilder:new():left("# test"), section:get_header())
    end)

    it("override", function()
        local section1 = Section:new({ title = "test", icon = "#" })
        local section2 = section1:with({ title = "test2" })
        eq(LineBuilder:new():left("# test"), section1:get_header())
        eq(LineBuilder:new():left("# test2"), section2:get_header())
    end)

    it("overrides highlights", function()
        local section1 = Section:new({
            title = "test",
            icon = "#",
            highlights = {
                links = { TestTest1 = "Normal" },
            },
        })
        eq({
            links = { TestTest1 = "Normal" },
        }, section1.highlights)

        local section2 = section1:with({ title = "test2" })
        eq({
            links = { TestTest1 = "Normal" },
        }, section2.highlights)

        local section3 = section2:with({
            title = "test2",
            highlights = {
                links = { TestTest2 = "Normal" },
            },
        })
        eq({
            links = { TestTest2 = "Normal" },
        }, section3.highlights)
    end)

    it("reset state on override", function()
        local section1 = Section:new({
            title = "test",
            icon = "#",
        })

        section1.state.extmark_id = 1
        eq({ extmark_id = 1 }, section1.state)

        local section2 = section1:with({ title = "test2" })
        eq({ extmark_id = nil }, section2.state)

        section2.state.extmark_id = 2
        eq({ extmark_id = 2 }, section2.state)
        eq({ extmark_id = 1 }, section1.state)
    end)
end)

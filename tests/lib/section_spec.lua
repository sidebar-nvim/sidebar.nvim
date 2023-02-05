local LineBuilder = require("sidebar-nvim.lib.line_builder")
local Section = require("sidebar-nvim.lib.section")

local eq = assert.are.same
local spy = require("luassert.spy")

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
        eq({ LineBuilder:new():left("# test", "SidebarNvimSectionTitle"), LineBuilder:empty() }, section:draw_header())
    end)

    it("get footer", function()
        local section = Section:new({ title = "test", icon = "#" })
        eq({ LineBuilder:empty() }, section:draw_footer())
    end)

    it("override", function()
        local section1 = Section:new({ title = "test", icon = "#" })
        local section2 = section1:with({ title = "test2" })
        eq({ LineBuilder:new():left("# test", "SidebarNvimSectionTitle"), LineBuilder:empty() }, section1:draw_header())
        eq(
            { LineBuilder:new():left("# test2", "SidebarNvimSectionTitle"), LineBuilder:empty() },
            section2:draw_header()
        )
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

    it("reset internal state on override", function()
        local section1 = Section:new({
            title = "test",
            icon = "#",
        })

        section1._internal_state.extmark_id = 1
        eq({ extmark_id = 1 }, section1._internal_state)

        local section2 = section1:with({ title = "test2" })
        eq({ extmark_id = nil }, section2._internal_state)

        section2._internal_state.extmark_id = 2
        eq({ extmark_id = 2 }, section2._internal_state)
        eq({ extmark_id = 1 }, section1._internal_state)
    end)

    it("binds keymaps", function()
        local section = Section:new({
            title = "test",
            icon = "#",

            keymaps = {
                my_action_1 = "a",
                my_action_2 = "b",
                my_action_3 = "<CR>",
            },
        })

        section.my_action_1 = spy.new(function() end)
        section.my_action_2 = spy.new(function() end)
        section.my_action_3 = spy.new(function() end)

        local ret = section:bind_keymaps({ "value1", 42, true })
        eq(#vim.tbl_keys(ret), 3)

        ret.a()
        assert.spy(section.my_action_1).was.called(1)
        assert.spy(section.my_action_2).was.called(0)
        assert.spy(section.my_action_3).was.called(0)
        assert.spy(section.my_action_1).was.called_with(section, "value1", 42, true)

        ret.b()
        assert.spy(section.my_action_1).was.called(1)
        assert.spy(section.my_action_2).was.called(1)
        assert.spy(section.my_action_3).was.called(0)
        assert.spy(section.my_action_2).was.called_with(section, "value1", 42, true)

        ret["<CR>"]()
        assert.spy(section.my_action_1).was.called(1)
        assert.spy(section.my_action_2).was.called(1)
        assert.spy(section.my_action_3).was.called(1)
        assert.spy(section.my_action_3).was.called_with(section, "value1", 42, true)
    end)
end)

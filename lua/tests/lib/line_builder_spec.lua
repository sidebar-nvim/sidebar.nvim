local LineBuilder = require("sidebar-nvim.lib.line_builder")

local eq = assert.are.same

describe("LineBuilder", function()
    it("creates a new line", function()
        local line = LineBuilder:new():left("test1", "SidebarNvimTest")

        local text, hl = line:build(120)

        eq("test1 " .. string.rep(" ", 120 - #"test1" - 1), text)
        eq(1, #hl)
        eq("SidebarNvimTest", hl[1].group)
        eq(0, hl[1].start_col)
        eq(#"test1", hl[1].length)
    end)

    it("creates a new line left and right", function()
        local line = LineBuilder:new():left("test1", "SidebarNvimTest"):right("test2", "SidebarNvimTest2")

        local text, hl = line:build(120)

        eq("test1 " .. string.rep(" ", 120 - #"test1" - 1 - #"test2") .. "test2", text)

        eq(2, #hl)
        eq("SidebarNvimTest", hl[1].group)
        eq(0, hl[1].start_col)
        eq(#"test1", hl[1].length)

        eq("SidebarNvimTest2", hl[2].group)
        eq(120 - #"test2", hl[2].start_col)
        eq(#"test2", hl[1].length)
    end)
end)

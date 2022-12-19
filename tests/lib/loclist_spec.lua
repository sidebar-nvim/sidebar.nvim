local LineBuilder = require("sidebar-nvim.lib.line_builder")
local Loclist = require("sidebar-nvim.lib.loclist")

local assert_lines = Helpers.assert_lines

-- local eq = assert.are.same

describe("LocList", function()
    it("new with groups", function()
        local loclist = Loclist:new({ my_group = { items = { LineBuilder:new():left("test") } } })

        assert_lines({
            LineBuilder:new()
                :left("", "SidebarNvimLabel")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (1)", "SidebarNvimSectionTitle"),
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)

    it("new with groups emtpy groups", function()
        local loclist = Loclist:new({ my_group = { items = {} } })

        assert_lines({
            LineBuilder:new()
                :left("", "SidebarNvimLabel")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (0)", "SidebarNvimSectionTitle"),
        }, loclist:draw())
    end)

    it("new with groups custom icon set", function()
        local test = function(is_closed, icon)
            local loclist = Loclist:new({
                my_group = {
                    items = { LineBuilder:new():left("test") },
                    is_closed = is_closed,
                },
            }, {
                group_icon_set = { closed = "c", opened = "o" },
            })

            local lines = {
                LineBuilder:new()
                    :left(icon, "SidebarNvimLabel")
                    :left(" ")
                    :left("my_group", "SidebarNvimLabel")
                    :left(" (1)", "SidebarNvimSectionTitle"),
            }

            if not is_closed then
                table.insert(lines, LineBuilder:new():left("test"))
            end

            assert_lines(lines, loclist:draw())
        end

        test(false, "o")
        test(true, "c")
    end)

    it("without group count", function()
        local loclist = Loclist:new(
            { my_group = { items = { LineBuilder:new():left("test") } } },
            { show_group_count = false }
        )

        assert_lines({
            LineBuilder:new():left("", "SidebarNvimLabel"):left(" "):left("my_group", "SidebarNvimLabel"),
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)

    it("with omit single group", function()
        local loclist = Loclist:new(
            { my_group = { items = { LineBuilder:new():left("test") } } },
            { omit_single_group = true }
        )

        assert_lines({
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)

    it("override group icon", function()
        local loclist = Loclist:new({
            my_group = { items = { LineBuilder:new():left("test") }, icon = { text = "#", hl = "custom_hl" } },
        })

        assert_lines({
            LineBuilder:new()
                :left("#", "custom_hl")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (1)", "SidebarNvimSectionTitle"),
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)

    it("override group count hl per group", function()
        local loclist = Loclist:new({
            my_group = { items = { LineBuilder:new():left("test") }, count_hl = "custom_count_hl" },
        })

        assert_lines({
            LineBuilder:new()
                :left("", "SidebarNvimLabel")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (1)", "custom_count_hl"),
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)

    it("with more than 99 items", function()
        local items = {}

        for _ = 1, 100 do
            table.insert(items, LineBuilder:empty())
        end

        local loclist = Loclist:new({ my_group = { items = items } })

        local ret = loclist:draw()

        assert.is.equal(101, #ret)

        assert_lines({
            LineBuilder:new()
                :left("", "SidebarNvimLabel")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (++)", "SidebarNvimSectionTitle"),
        }, { ret[1] })
    end)

    it("with keymaps", function()
        local cb = function() end

        local loclist = Loclist:new({
            my_group = {
                items = { LineBuilder:new():left("test") },
                keymaps = { ["<CR>"] = cb },
            },
        })

        assert_lines({
            LineBuilder:new({ keymaps = { ["<CR>"] = cb } })
                :left("", "SidebarNvimLabel")
                :left(" ")
                :left("my_group", "SidebarNvimLabel")
                :left(" (1)", "SidebarNvimSectionTitle"),
            LineBuilder:new():left("test"),
        }, loclist:draw())
    end)
end)

local LineBuilder = require("sidebar-nvim.lib.line_builder")
local View = require("sidebar-nvim.lib.view")
local async = require("sidebar-nvim.lib.async")
local TestSection = require("sidebar-nvim.builtin.test")

local api = async.api

local mock = require("luassert.mock")
local spy = require("luassert.spy")

local eq = assert.are.same

local describe = async.tests.describe
local it = async.tests.it
local it_snapshot = Helpers.it_snapshot_wrapper(it, "view_draw")
local before_each = async.tests.before_each
local after_each = async.tests.after_each

describe("View: Draw", function()
    local view = nil

    before_each(function()
        local sections = {}

        table.insert(sections, TestSection:with({ title = "t1", format = "a1: %d" }))
        table.insert(sections, TestSection:with({ title = "t2", format = "b2: %d" }))
        table.insert(sections, TestSection:with({ title = "t3", format = "c3: %d" }))

        view = View:new(sections)
    end)

    after_each(function() end)

    local function draw(index, section)
        view:draw(index, section, section:draw())
    end

    local function draw_all()
        for i, section in ipairs(view.sections) do
            draw(i, section)
        end
    end

    it("setup", function()
        eq(api.nvim_buf_is_loaded(view._internal_state.bufnr), true)

        for i, section in ipairs(view.sections) do
            eq(section._internal_state.extmark_id, i)
        end
    end)

    it("second draw: with extmarks", function()
        draw_all()
    end)

    it_snapshot("draw: set_lines", function()
        draw_all()

        return view
    end)

    it_snapshot("draw: custom hls", function()
        view.sections[1] = TestSection:with({
            draw_header = function()
                return { LineBuilder:new():left("header", "header_hl"):left("22", "hl22") }
            end,
            draw_footer = function()
                return { LineBuilder:new():left("footer", "footer_hl") }
            end,
            draw_content = function()
                return { LineBuilder:new():left("custom_hl", "hl1"):right("custom_hl_2", "hl2") }
            end,
        })

        draw_all()

        return view
    end)

    it_snapshot("section increasing size should move the next one below", function()
        local section = view.sections[2]

        -- first draw
        draw_all()

        -- increase size
        section.draw_content = function()
            local ret = {}

            for i = 1, 5 do
                table.insert(ret, LineBuilder:new():left(i))
            end

            return ret
        end

        draw(2, section)

        return view
    end)

    it_snapshot("section increasing size should move the next one below: decreasing", function()
        local section = view.sections[2]

        -- first draw
        draw_all()

        -- increase size
        section.draw_content = function()
            local ret = {}

            for i = 1, 5 do
                table.insert(ret, LineBuilder:new():left(i))
            end

            return ret
        end

        draw(2, section)

        -- decrease size
        section.draw_content = function()
            local ret = {}

            table.insert(ret, LineBuilder:new():left(1))

            return ret
        end

        draw(2, section)

        return view
    end)
end)

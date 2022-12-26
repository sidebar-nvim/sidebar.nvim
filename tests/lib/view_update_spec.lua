local LineBuilder = require("sidebar-nvim.lib.line_builder")
local View = require("sidebar-nvim.lib.view")
local async = require("sidebar-nvim.lib.async")
local TestSection = require("sidebar-nvim.builtin.test")

local mock = require("luassert.mock")
local spy = require("luassert.spy")
local match = require("luassert.match")

local eq = assert.are.same

local describe = async.tests.describe
local it = async.tests.it
local before_each = async.tests.before_each
local after_each = async.tests.after_each

describe("View: update", function()
    local total_mocked_sections = 0

    local view = nil

    before_each(function()
        local sections = {}

        for i = 1, 3 do
            local section = TestSection:with({ title = "s: " .. i, _test_data = {}, reloaders = {} })
            table.insert(
                section.reloaders,
                spy.new(function(_, cb)
                    section._test_data.reloader_cb = cb
                end)
            )
            spy.on(section, "draw")
            table.insert(sections, section)
            total_mocked_sections = total_mocked_sections + 1
        end

        -- builtin section
        table.insert(sections, "test")
        table.insert(sections, "test")
        total_mocked_sections = total_mocked_sections + 2

        view = View:new(sections, { winopts = { width = 120, height = 80 } })
    end)

    after_each(function()
        total_mocked_sections = 0
    end)

    it("setup", function()
        eq(#view.sections, 5)

        for i = 1, 3 do
            local section = view.sections[i]
            assert.spy(section.draw).was.called(1)

            assert.spy(section.reloaders[1]).was.called(1)

            eq(type(section._internal_state.invalidate_cb), "function")
            eq(section._internal_state.extmark_id, i)
        end

        assert.are.not_same(view.sections[4]._internal_state, view.sections[5]._internal_state)
    end)

    it("updates from reloaders", function()
        view.sections[1]._test_data.reloader_cb()

        async.util.sleep(500)

        local section = view.sections[1]
        assert.spy(section.draw).was.called(2)
    end)

    it("section invalidate_cb", function()
        view.sections[1]._internal_state.invalidate_cb()

        async.util.sleep(500)

        local section = view.sections[1]
        assert.spy(section.draw).was.called(2)
    end)
end)

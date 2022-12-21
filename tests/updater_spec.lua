local updater = require("sidebar-nvim.updater")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local renderer = require("sidebar-nvim.renderer")
local view = require("sidebar-nvim.view")
local config = require("sidebar-nvim.config")
local state = require("sidebar-nvim.state")
local async = require("sidebar-nvim.lib.async")

local mock = require("luassert.mock")
local spy = require("luassert.spy")

local eq = assert.are.same

local describe = async.tests.describe
local it = async.tests.it
local before_each = async.tests.before_each
local after_each = async.tests.after_each

describe("Updater", function()
    local renderer_mock
    local view_mock

    local total_mocked_sections = 0

    before_each(function()
        view_mock = mock(view, true)
        renderer_mock = mock(renderer, true)

        view_mock.get_width = spy.new(function()
            return 120
        end)

        local sections = {}

        for i = 1, 3 do
            table.insert(sections, Helpers.create_test_section(i))
            total_mocked_sections = total_mocked_sections + 1
        end

        config.sections = { default = sections, test_tab = { Helpers.create_test_section(1) } }
        total_mocked_sections = total_mocked_sections + 1

        updater.setup()
    end)

    after_each(function()
        mock.revert(view_mock, true)
        mock.revert(renderer_mock, true)
        total_mocked_sections = 0
    end)

    it("setup", function()
        eq(#config.sections.default, 3)
        eq(#state.tabs.default, 3)

        eq(#config.sections.test_tab, 1)
        eq(#state.tabs.test_tab, 1)

        for i = 1, 3 do
            local section = state.tabs.default[i]
            assert.spy(section.draw).was.called_with(section, { width = 120 })
            assert.spy(renderer_mock.draw).was.called_with("default", i, section, { LineBuilder:new():left(i) })

            assert.spy(section.reloaders[1]).was.called(1)

            eq(type(section._internal_state.invalidate_cb), "function")
        end

        -- check if update lister is setup
        assert.is.truthy(updater._updates_listener_tx)
    end)

    it("updates listener", function()
        state.tabs.default[1]._test_data.reloader_cb()

        async.util.sleep(500)

        assert.spy(renderer_mock.draw).was.called(total_mocked_sections + 1)
        assert.spy(state.tabs.default[1].draw).was.called(2)
        eq(renderer_mock.draw.calls[#renderer_mock.draw.calls].vals[2], 1)
    end)

    it("section invalidate_cb", function()
        state.tabs.default[1]._internal_state.invalidate_cb()

        async.util.sleep(500)

        assert.spy(renderer_mock.draw).was.called(total_mocked_sections + 1)
        assert.spy(state.tabs.default[1].draw).was.called(2)
        eq(renderer_mock.draw.calls[#renderer_mock.draw.calls].vals[2], 1)
    end)

    it("update", function()
        updater.update()

        assert.spy(renderer_mock.draw).was.called(total_mocked_sections * 2)
    end)
end)

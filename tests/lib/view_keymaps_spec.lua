local LineBuilder = require("sidebar-nvim.lib.line_builder")
local View = require("sidebar-nvim.lib.view")
local async = require("sidebar-nvim.lib.async")
local ns = require("sidebar-nvim.lib.namespaces")
local TestSection = require("sidebar-nvim.builtin.test")
local api = async.api

local mock = require("luassert.mock")
local spy = require("luassert.spy")

local eq = assert.are.same

local describe = async.tests.describe
local it = async.tests.it
local before_each = async.tests.before_each
local after_each = async.tests.after_each

TestSection = TestSection:with({
    keymaps = {},
    get_default_keymaps = function()
        return {}
    end,
})

describe("View: keymaps", function()
    local cb_1 = nil
    local cb_2 = nil
    local cb_3 = nil

    local view = nil

    before_each(function()
        local sections = {}

        cb_1 = spy.new(function() end)
        table.insert(
            sections,
            TestSection:with({
                title = "t1",
                format = "a1: %d",
                draw_content = function()
                    return { LineBuilder:new({ keymaps = { a = cb_1 } }):left("a1") }
                end,
            })
        )

        cb_2 = spy.new(function() end)
        table.insert(
            sections,
            TestSection:with({
                title = "t2",
                format = "b2: %d",
                draw_content = function()
                    return { LineBuilder:new({ keymaps = { b = cb_2 } }):left("b2") }
                end,
            })
        )

        cb_3 = spy.new(function() end)
        table.insert(
            sections,
            TestSection:with({
                title = "t3",
                format = "c3: %d",
                draw_content = function()
                    return { LineBuilder:new({ keymaps = { c = cb_3 } }):left("c3") }
                end,
            })
        )

        view = View:new(sections)
        view:open({ focus = true })
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

    local function send_keymap(key, row, col)
        assert(view:get_winnr(), "could not get winnr")
        assert(vim.api.nvim_get_current_buf() == view._internal_state.bufnr, "wrong buffer")
        api.nvim_win_set_cursor(view:get_winnr(), { row, col })

        key = api.nvim_replace_termcodes(key, true, false, true)
        api.nvim_feedkeys(key, "x", false)
    end

    it("setup", function()
        assert.is.truthy(ns.hl_namespace_id)
        assert.is.truthy(ns.extmarks_namespace_id)
        assert.is.truthy(ns.keymaps_namespace_id)

        eq(api.nvim_buf_is_loaded(view._internal_state.bufnr), true)
    end)

    it("creates the correct keymaps for each line", function()
        draw_all()

        local extmarks =
            api.nvim_buf_get_extmarks(view._internal_state.bufnr, ns.keymaps_namespace_id, 0, -1, { details = true })

        eq(#extmarks, 6)

        -- this is the row in which the line of our test section will end up
        send_keymap("a", 3, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(0)
        assert.spy(cb_3).was.called(0)

        send_keymap("b", 7, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(0)

        send_keymap("c", 11, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(1)
    end)

    it("creates the correct keymaps for each line and default section keymaps", function()
        local cb_s = spy.new(function() end)

        view.sections[2].keymaps = { my_action_1 = "u" }
        view.sections[2].my_action_1 = cb_s
        view.sections[2].get_default_keymaps = function(self)
            return self:bind_keymaps({ 42 })
        end

        draw_all()

        local extmarks =
            api.nvim_buf_get_extmarks(view._internal_state.bufnr, ns.keymaps_namespace_id, 0, -1, { details = true })

        eq(6, #extmarks)

        -- this is the row in which the line of our test section will end up
        send_keymap("a", 3, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(0)
        assert.spy(cb_3).was.called(0)
        assert.spy(cb_s).was.called(0)

        send_keymap("b", 7, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(0)
        assert.spy(cb_s).was.called(0)

        send_keymap("c", 11, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(1)
        assert.spy(cb_s).was.called(0)

        send_keymap("u", 2, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(1)
        assert.spy(cb_s).was.called(0)

        local start_row = 5
        local calls = 0
        for row = start_row, start_row + 2 do
            calls = calls + 1
            send_keymap("u", row, 0)
            assert.spy(cb_1).was.called(1)
            assert.spy(cb_2).was.called(1)
            assert.spy(cb_3).was.called(1)
            assert.spy(cb_s).was.called(calls)
        end
    end)

    it("multiple keypresses with proper cleaning", function()
        draw_all()

        local extmarks =
            api.nvim_buf_get_extmarks(view._internal_state.bufnr, ns.keymaps_namespace_id, 0, -1, { details = true })

        eq(#extmarks, 6)

        for i = 1, 5 do
            -- this is the row in which the line of our test section will end up
            send_keymap("a", 3, 0)
            assert.spy(cb_1).was.called(i)
            async.util.sleep(500)
        end
    end)
end)

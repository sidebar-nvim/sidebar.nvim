local LineBuilder = require("sidebar-nvim.lib.line_builder")
local renderer = require("sidebar-nvim.renderer")
local view = require("sidebar-nvim.view")
local state = require("sidebar-nvim.state")
local async = require("sidebar-nvim.lib.async")
local TestSection = require("sidebar-nvim.builtin.test")

local api = async.api

local mock = require("luassert.mock")
local spy = require("luassert.spy")

local eq = assert.are.same

local describe = async.tests.describe
local it = async.tests.it
local before_each = async.tests.before_each
local after_each = async.tests.after_each

describe("Renderer keymaps", function()
    local cb_1 = nil
    local cb_2 = nil
    local cb_3 = nil

    before_each(function()
        cb_1 = spy.new(function() end)
        table.insert(
            state.tabs.default,
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
            state.tabs.default,
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
            state.tabs.default,
            TestSection:with({
                title = "t3",
                format = "c3: %d",
                draw_content = function()
                    return { LineBuilder:new({ keymaps = { c = cb_3 } }):left("c3") }
                end,
            })
        )

        view.setup()
        view.open()
        view.focus()

        renderer.setup()
    end)

    after_each(function()
        state.tabs.default = {}
        renderer.hl_namespace_id = nil
        renderer.extmarks_namespace_id = nil
        renderer.keymaps_namespace_id = nil
    end)

    local function draw(index, section)
        renderer.draw("default", index, section, section:draw())
    end

    local function draw_all()
        for i, section in ipairs(state.tabs.default) do
            draw(i, section)
        end
    end

    local function send_keymap(key, row, col)
        assert(view.get_winnr(), "could not get winnr")
        assert(vim.api.nvim_get_current_buf() == view.View.bufnr, "wrong buffer")
        api.nvim_win_set_cursor(view.get_winnr(), { row + 1, col + 1 })

        key = api.nvim_replace_termcodes(key, true, false, true)
        api.nvim_feedkeys(key, "x", false)
    end

    it("setup", function()
        assert.is.truthy(renderer.hl_namespace_id)
        assert.is.truthy(renderer.extmarks_namespace_id)
        assert.is.truthy(renderer.keymaps_namespace_id)

        eq(api.nvim_buf_is_loaded(view.View.bufnr), true)
    end)

    it("creates the correct keymaps for each line", function()
        draw_all()

        local extmarks =
            api.nvim_buf_get_extmarks(view.View.bufnr, renderer.keymaps_namespace_id, 0, -1, { details = true })

        eq(#extmarks, 3)

        -- this is the row in which the line of our test section will end up
        send_keymap("a", 2, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(0)
        assert.spy(cb_3).was.called(0)

        send_keymap("b", 6, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(0)

        send_keymap("c", 10, 0)
        assert.spy(cb_1).was.called(1)
        assert.spy(cb_2).was.called(1)
        assert.spy(cb_3).was.called(1)
    end)
end)

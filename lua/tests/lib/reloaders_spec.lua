local pasync = require("sidebar-nvim.lib.async")
local reloaders = require("sidebar-nvim.lib.reloaders")

local eq = assert.are.same

describe("reloaders", function()
    describe("autocmd", function()
        it("creates the correct autocmd", function()
            local reloader = reloaders.autocmd("BufReadPost", "*.lua")
            local group_id = vim.api.nvim_create_augroup("test_group", { clear = true })
            reloader(group_id, function() end)

            local autocmds = vim.api.nvim_get_autocmds({
                group = "test_group",
            })

            eq(1, #autocmds)
            eq("BufReadPost", autocmds[1].event)
            eq("*.lua", autocmds[1].pattern)
        end)
    end)

    describe("file_changed", function()
        it("creates the correct autocmd", function()
            local reloader = reloaders.file_changed("*.lua")
            local group_id = vim.api.nvim_create_augroup("test_group", { clear = true })
            reloader(group_id, function() end)

            local autocmds = vim.api.nvim_get_autocmds({
                group = "test_group",
            })

            eq(1, #autocmds)
            eq("BufWritePost", autocmds[1].event)
            eq("*.lua", autocmds[1].pattern)
        end)
    end)

    describe("interval", function()
        it("triggers at intervals", function()
            local cb_check = false

            local cb = function()
                cb_check = true
            end

            local reloader = reloaders.interval(500)
            local group_id = vim.api.nvim_create_augroup("test_group", { clear = true })
            reloader(group_id, cb)

            pasync.util.block_on(function()
                eq(cb_check, false)

                pasync.util.sleep(600)

                eq(cb_check, true)
            end)
        end)
    end)
end)

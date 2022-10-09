local pasync = require("sidebar-nvim.lib.async")

local eq = assert.are.same

describe("async utilities test", function()
    describe("async.async_vim_wrap", function()
        it("correctly returns from api wrappers", function()
            pasync.util.block_on(function()
                local bufnr = pasync.api.nvim_create_buf(false, false)

                eq(2, bufnr)
            end)
        end)

        it("automatically wraps vim.fn functions", function()
            pasync.util.block_on(function()
                local ret = pasync.fn.filereadable(pasync.fn.expand("lua/sidebar-nvim.lua"))

                eq(1, ret)
            end)
        end)

        it("automatically wraps vim.cmd functions", function()
            local filename = "test_test_test.txt"
            pasync.util.block_on(function()
                pasync.cmd.edit(filename)
            end)

            eq(vim.fn.fnamemodify(filename, ":p"), vim.api.nvim_buf_get_name(0))
        end)
    end)
end)

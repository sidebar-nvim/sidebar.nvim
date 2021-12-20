local utils = require("sidebar-nvim.utils")

local diagnostics = require("sidebar-nvim.builtin.diagnostics")

local deprecated_diagnostics = vim.tbl_deep_extend("force", diagnostics, {
    setup = function(ctx)
        utils.echo_warning("Section 'lsp-diagnostics' is deprecated. Please use 'diagnostics'")

        if diagnostics.setup ~= nil then
            return diagnostics.setup(ctx)
        end
    end,
})

return deprecated_diagnostics

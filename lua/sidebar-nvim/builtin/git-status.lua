local utils = require("sidebar-nvim.utils")

local git = require("sidebar-nvim.builtin.git")

local deprecated_git = vim.tbl_deep_extend("force", git, {
    setup = function(ctx)
        utils.echo_warning("Section 'git-status' is deprecated. Please use 'git'")

        if git.setup ~= nil then
            return git.setup(ctx)
        end
    end,
})

return deprecated_git

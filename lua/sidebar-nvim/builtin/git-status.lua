local utils = require("sidebar-nvim.utils")
local Loclist = require("sidebar-nvim.components.loclist")
local luv = vim.loop

local loclist = Loclist:new({
    show_location = false,
    ommit_single_group = true,
    highlights = {item_text = "SidebarNvimGitStatusFileName"}
})

local status_tmp = ""

local function async_update(ctx)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)

    local handle
    handle = luv.spawn("git", {args = {"status", "--porcelain"}, stdio = {nil, stdout, stderr}, cwd = luv.cwd()},
                       function()

        loclist:clear()
        if status_tmp ~= "" then
            for _, line in ipairs(vim.split(status_tmp, '\n')) do
                local striped_line = line:match("^%s*(.-)%s*$")
                local line_status = striped_line:sub(0, 2)
                local line_filename = striped_line:sub(3, -1):match("^%s*(.-)%s*$")

                if line_filename ~= "" then
                    loclist:add_item({
                        group = "git",
                        text = utils.shorten_path(line_filename, ctx.width - 4),
                        icon = {hl = "SidebarNvimGitStatusState", text = line_status}
                    })
                end

            end
        end

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    status_tmp = ""

    luv.read_start(stdout, function(err, data)
        if data == nil then return end

        status_tmp = status_tmp .. data

        if err ~= nil then vim.schedule(function() utils.echo_warning(err) end) end
    end)

    luv.read_start(stderr, function(err, data)
        if data == nil then return end

        if err ~= nil then vim.schedule(function() utils.echo_warning(err) end) end

        -- vim.schedule(function()
        -- utils.echo_warning(data)
        -- end)
    end)

end

return {
    title = "Git Status",
    icon = "📄",
    draw = function(ctx)
        async_update(ctx)

        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then lines = {"<no changes>"} end

        return {lines = lines, hl = hl}
    end,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {SidebarNvimGitStatusState = "Keyword", SidebarNvimGitStatusFileName = "Normal"}
    },
    bindings = {
        ["e"] = function(line)
            local location = loclist:get_location_at(line)
            if location == nil then return end
            vim.cmd("wincmd p")
            vim.cmd("e " .. location)
        end
    }
}

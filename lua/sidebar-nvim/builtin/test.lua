local Loclist = require("sidebar-nvim.components.loclist")

local loclist = Loclist:new()
loclist:add_item({group = "test", lnum = 1, col = 2, text = "test.lua"})
loclist:add_item({group = "test2", lnum = 2, col = 3, text = "hello_world.lua"})

local function draw(ctx)
    local lines = {}
    local hl = {}

    loclist:draw(ctx, lines, hl)

    return {lines = lines, hl = hl}
end

return {
    title = "Test",
    icon = "📄",
    draw = draw,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {SidebarNvimGitStatusState = "Keyword"}
    },
    bindings = {
        ["a"] = function() loclist:open_all_groups() end,
        ["c"] = function() loclist:close_all_groups() end,
        ["t"] = function(line) loclist:toggle_group_at(line) end
    }
}

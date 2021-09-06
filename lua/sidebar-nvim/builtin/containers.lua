local utils = require("sidebar-nvim.utils")
local docker_utils = require("sidebar-nvim.docker_utils")
local Loclist = require("sidebar-nvim.components.loclist")
local Debouncer = require("sidebar-nvim.debouncer")
local luv = vim.loop

local loclist = Loclist:new({
    show_location = false,
    ommit_single_group = true,
    highlights = {item_text = "SidebarNvimDockerContainerName"}
})

local output_tmp = ""

local function get_container_icon(container)
    local default = {hl = "SidebarNvimDockerContainerStatus", text = "🆙"}

    local mapping = {running = default}

    local icon = mapping[container.State] or default

    return icon
end

local function async_update(ctx)
    local stdout = luv.new_pipe(false)
    local stderr = luv.new_pipe(false)

    local handle
    local cmd = docker_utils.build_docker_command({"ps"}, stdout, stderr)
    handle = luv.spawn(cmd.bin, cmd.opts, function()

        vim.schedule(function()
            loclist:clear()
            if output_tmp ~= "" then
                for _, line in ipairs(vim.split(output_tmp, '\n')) do
                    line = string.sub(line, 2, #line - 1)
                    if line ~= "" then
                        local ret, container = pcall(vim.fn.json_decode, line)
                        if ret then
                            loclist:add_item({
                                group = "containers",
                                text = container.Names,
                                icon = get_container_icon(container)
                            })
                        else
                            vim.schedule(function()
                                utils.echo_warning("invalid container output: " .. container)
                            end)
                        end
                    end
                end
            end
        end)

        luv.read_stop(stdout)
        luv.read_stop(stderr)
        stdout:close()
        stderr:close()
        handle:close()
    end)

    output_tmp = ""

    luv.read_start(stdout, function(err, data)
        if data == nil then return end

        output_tmp = output_tmp .. data

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

local async_update_debounced = Debouncer:new(async_update, 2000)

return {
    title = "Containers",
    icon = "🐳",
    setup = function() async_update_debounced:call() end,
    draw = function(ctx)
        async_update_debounced:call(ctx)

        local lines = {}
        local hl = {}

        loclist:draw(ctx, lines, hl)

        if #lines == 0 then lines = {"<no containers>"} end

        return {lines = lines, hl = hl}
    end,
    highlights = {
        -- { MyHLGroup = { gui=<color>, fg=<color>, bg=<color> } }
        groups = {},
        -- { MyHLGroupLink = <string> }
        links = {SidebarNvimDockerContainerStatus = "Keyword", SidebarNvimDockerContainerName = "Normal"}
    },
    bindings = {
        ["e"] = function(line)
            -- local location = loclist:get_location_at(line)
            -- if location == nil then return end
            -- vim.cmd("wincmd p")
            -- vim.cmd("e " .. location)
        end
    }
}


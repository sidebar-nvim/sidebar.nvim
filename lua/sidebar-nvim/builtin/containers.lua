local async = require("sidebar-nvim.lib.async")
local Section = require("sidebar-nvim.lib.section")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local reloaders = require("sidebar-nvim.lib.reloaders")
local Job = require("plenary.job")
local Loclist = require("sidebar-nvim.lib.loclist")
local logger = require("sidebar-nvim.logger")

local Containers = Section:new({
    title = "Containers",

    icon = "",
    use_podman = false,
    attach_shell = "/bin/sh",
    show_all = true,

    reloaders = { reloaders.interval(5000) },

    keymaps = {
        container_attach = "e",
    },

    highlights = {
        groups = {},
        links = {
            SidebarNvimDockerContainerStatusRunning = "LspDiagnosticsDefaultInformation",
            SidebarNvimDockerContainerStatusExited = "LspDiagnosticsDefaultError",
            SidebarNvimDockerContainerName = "Normal",
        },
    },
})

function Containers:get_docker_bin()
    local bin = "docker"

    if self.use_podman then
        bin = "podman"
    end

    return bin
end

function Containers:build_docker_command(args)
    local cmd = self:get_docker_bin()

    args = args or {}
    -- make sure the command only fetches the bare minimum fields to work
    -- otherwise docker goes crazy with high load. See https://github.com/sidebar-nvim/sidebar.nvim/issues/3
    -- we also need to make sure that each line has valid json syntax so the parser can understand
    -- the formatting string below is to make sure we reconstruct the json object with only the fields we want
    table.insert(args, '--format=\'{"Names": {{json .Names}}, "State": {{json .State}}, "ID": {{json .ID}} }\'')

    return { cmd = cmd, args = args }
end

function Containers:build_docker_attach_command(container_id)
    local bin = Containers:get_docker_bin()

    return bin .. " exec -it " .. container_id .. " " .. self.attach_shell
end

function Containers:container_attach(container_id)
    vim.cmd("wincmd p")
    vim.cmd("terminal " .. self:build_docker_attach_command(container_id))
end

function Containers:get_container_icon(container)
    local default = { hl = "SidebarNvimDockerContainerStatusRunning", text = "✓" }

    local mapping = { running = default, exited = { hl = "SidebarNvimDockerContainerStatusExited", text = "☒" } }

    local icon = mapping[container.State] or default

    return icon
end

function Containers:get_containers()
    local args = { "ps" }
    if self.show_all then
        args = { "ps", "-a" }
    end

    local cmd = self:build_docker_command(args)

    if async.fn.executable(cmd.cmd) ~= 1 then
        logger:warn("docker executable not found: " .. cmd.cmd, { cmd = cmd }, true)
        return {}
    end

    local output, code = Job:new({
        command = cmd.cmd,
        args = cmd.args,
        cwd = vim.loop.cwd(),
        -- interactive = false,
    }):sync()

    if code ~= 0 then
        logger:error(
            string.format("error trying to run '%s'", cmd),
            { command = cmd, args = args, code = code, output = output },
            true
        )
        return {}
    end

    output = output or {}

    local containers = {}

    for _, line in ipairs(output) do
        line = vim.trim(line)
        if line ~= "" then
            line = string.sub(line, 2, #line - 1)
            local ret, container = pcall(vim.json.decode, line)
            if ret then
                table.insert(containers, container)
            else
                logger:warn("error trying to parse container json line", { line = line, err = container })
            end
        end
    end

    local state_order_mapping = { running = 1, exited = 2 }

    table.sort(containers, function(a, b)
        return (state_order_mapping[a.State] or 0) < (state_order_mapping[b.State] or 0)
    end)

    local loclist_items = {}

    for _, container in ipairs(containers) do
        local icon = self:get_container_icon(container)
        table.insert(
            loclist_items,
            LineBuilder:new({ keymaps = self:bind_keymaps({ container.ID }) })
                :left(icon.text .. " ", icon.hl)
                :left(container.Names, "SidebarNvimDockerContainerName")
        )
    end

    return loclist_items
end

function Containers:draw_content(ctx)
    local container_items = self:get_containers()

    if #container_items == 0 then
        return { LineBuilder:new():left("<no containers>") }
    end

    local loclist = Loclist:new({
        containers = { items = container_items },
    }, {
        omit_single_group = true,
    })

    return loclist:draw()
end

return Containers

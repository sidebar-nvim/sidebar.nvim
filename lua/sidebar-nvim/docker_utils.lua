local config = require("sidebar-nvim.config")
local luv = vim.loop

local M = {}

function M.get_docker_bin()
    local bin = "docker"

    if config.docker.use_podman then
        bin = "podman"
    end

    return bin
end

function M.build_docker_command(args, stdout, stderr)
    local bin = M.get_docker_bin()

    args = args or {}
    table.insert(args, "--format='{{json .}}'")

    return { bin = bin, opts = { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() } }
end

function M.build_docker_attach_command(container_id)
    local bin = M.get_docker_bin()

    return bin .. " exec -it " .. container_id .. " " .. config.docker.attach_shell
end

return M

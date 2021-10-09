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
    -- make sure the command only fetches the bare minimum fields to work
    -- otherwise docker goes crazy with high load. See https://github.com/sidebar-nvim/sidebar.nvim/issues/3
    -- we also need to make sure that each line has valid json syntax so the parser can understand
    -- the formatting string below is to make sure we reconstruct the json object with only the fields we want
    table.insert(args, '--format=\'{"Names": {{json .Names}}, "State": {{json .State}}, "ID": {{json .ID}} }\'')

    return { bin = bin, opts = { args = args, stdio = { nil, stdout, stderr }, cwd = luv.cwd() } }
end

function M.build_docker_attach_command(container_id)
    local bin = M.get_docker_bin()

    return bin .. " exec -it " .. container_id .. " " .. config.docker.attach_shell
end

return M

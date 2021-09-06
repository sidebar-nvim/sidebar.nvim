local config = require("sidebar-nvim.config")
local luv = vim.loop

local M = {}

function M.build_docker_command(args, stdout, stderr)
  local bin = "docker"

  if config.docker.use_podman then
    bin = "podman"
  end

  args = args or {}
  table.insert(args, "--format='{{json .}}'")

  return {bin = bin, opts = {args = args,  stdio = {nil, stdout, stderr}, cwd = luv.cwd()}}
end

return M

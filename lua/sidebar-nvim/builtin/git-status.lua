local luv = vim.loop

local status = "<no changes>"

local status_tmp = ""

local function async_update()
  local stdout = luv.new_pipe()
  local stderr = luv.new_pipe()

  local handle, pid
  handle, _  = luv.spawn("git", {
    args = {"status", "--porcelain"},
    stdio = {nil, stdout, stderr},
    cwd = luv.cwd(),
  }, function(code, signal)

    if status_tmp == "" then
      status = "<no changes>"
    else
      status = status_tmp
    end

    luv.read_stop(stdout)
    luv.read_stop(stderr)
    luv.close(handle)
  end)

  status_tmp = ""

  luv.read_start(stdout, function(err, data)
    if data == nil then return end
    status_tmp = status_tmp .. data
  end)

  luv.read_start(stderr, function(err, data)
    if data == nil then return end
    print(data)
  end)

end

return {
  title = "Git Status",
  icon = "📄",
  draw = function()
    async_update()
    return status
  end,
}

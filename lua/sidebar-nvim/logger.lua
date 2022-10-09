-- inspired by: https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/lua/null-ls/logger.lua

local Path = require("plenary.path")
local Error = require("sidebar-nvim.error")

local async_vim_notify = vim.schedule_wrap(vim.notify)

local default_notify_opts = {
    title = "sidebar-nvim",
}

local log = {
    level = "warn",

    notify_format = "[sidebar-nvim] %s %s",
}

function log:setup(opts)
    opts = vim.tbl_extend("force", { level = "warn" }, opts or {})
    self.level = opts.level

    -- reset the handle
    self.__handle = nil
end

local function format_props(props)
    local ret = {}
    for key, value in pairs(props or {}) do
        table.insert(ret, string.format("%s=%s", key, vim.inspect(value)))
    end

    return table.concat(ret, ", ")
end

local function expand_msg_and_props(msg, props)
    if getmetatable(msg) == Error then
        msg = msg.message
        props = vim.tbl_deep_extend("force", msg.attrs or {}, props or {})
    end

    return msg, props
end

--- Adds a log entry using Plenary.log
---@param msg any
---@param props table key-value props to attach to the message
---@param level string [same as vim.log.log_levels]
function log:add_entry(msg, props, level)
    if not self.__notify_fmt then
        self.__notify_fmt = function(m, p)
            m, p = expand_msg_and_props(m, p)

            if type(m) == "table" then
                m = vim.inspect(m)
            end
            return string.format(self.notify_format, m, format_props(p))
        end
    end

    if self.level == "off" then
        return
    end

    msg, props = expand_msg_and_props(msg, props)

    if type(msg) == "table" then
        msg = vim.inspect(msg)
    end

    msg = string.format("%s | %s", msg, format_props(props))

    if self.__handle then
        self.__handle[level](msg)
        return
    end

    local default_opts = {
        plugin = "sidebar-nvim",
        level = self.level or "warn",
        use_console = false,
        info_level = 4,
    }

    local plenary_log = require("plenary.log")

    local handle = plenary_log.new(default_opts)
    handle[level](msg)
    self.__handle = handle
end

---Retrieves the path of the logfile
---@return string path of the logfile
function log:get_path()
    local p = Path:new(vim.fn.stdpath("cache")) / "sidebar-nvim.log"
    return p.filename
end

---Add a log entry at TRACE level
---@param msg any
---@param props table key-value props to attach to the message
function log:trace(msg, props)
    self:add_entry(msg, props, "trace")
end

---Add a log entry at DEBUG level
---@param msg any
---@param props table key-value props to attach to the message
function log:debug(msg, props)
    self:add_entry(msg, props, "debug")
end

---Add a log entry at INFO level
---@param msg any
---@param props table key-value props to attach to the message
function log:info(msg, props)
    self:add_entry(msg, props, "info")
end

---Add a log entry at WARN level
---@param msg any
---@param props table key-value props to attach to the message
function log:warn(msg, props)
    self:add_entry(msg, props, "warn")
    async_vim_notify(self.__notify_fmt(msg, props), vim.log.levels.WARN, default_notify_opts)
end

---Add a log entry at ERROR level
---@param msg any
---@param props table key-value props to attach to the message
function log:error(msg, props)
    self:add_entry(msg, props, "error")
    async_vim_notify(self.__notify_fmt(msg, props), vim.log.levels.ERROR, default_notify_opts)
end

setmetatable({}, log)
return log

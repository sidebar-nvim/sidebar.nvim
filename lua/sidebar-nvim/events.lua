local M = {}

local global_handlers = {}

local Event = {Ready = 'Ready'}

local function get_handlers(event_name) return global_handlers[event_name] or {} end

local function register_handler(event_name, handler)
    local handlers = get_handlers(event_name)
    table.insert(handlers, handler)
    global_handlers[event_name] = handlers
end

local function dispatch(event_name, payload)
    for _, handler in pairs(get_handlers(event_name)) do
        local success, error = pcall(handler, payload)
        if not success then vim.api.nvim_err_writeln('Handler for event ' .. event_name .. ' errored. ' .. vim.inspect(error)) end
    end
end

-- @private
function M._dispatch_ready() dispatch(Event.Ready) end

-- Registers a handler for the Ready event.
-- @param handler (function) Handler with the signature `function()`
function M.on_sidebar_nvim_ready(handler) register_handler(Event.Ready, handler) end

return M

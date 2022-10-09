local pasync = require("sidebar-nvim.lib.async")
local bindings = require("sidebar-nvim.bindings")
local config = require("sidebar-nvim.config")
local utils = require("sidebar-nvim.utils")

local api = pasync.api

local M = {}

M.is_prompt_exiting = false

M.View = {
    bufnr = nil,
    tabpages = {},
    width = 30,
    side = "left",
    winopts = {
        relativenumber = false,
        number = false,
        list = false,
        winfixwidth = true,
        winfixheight = true,
        foldenable = false,
        spell = false,
        signcolumn = "yes",
        foldmethod = "manual",
        foldcolumn = "0",
        cursorcolumn = false,
        colorcolumn = "0",
    },
    bufopts = {
        { name = "swapfile", val = false },
        { name = "buftype", val = "nofile" },
        { name = "modifiable", val = false },
        { name = "filetype", val = "SidebarNvim" },
        { name = "bufhidden", val = "hide" },
    },
}

---Find a rogue SidebarNvim buffer that might have been spawned by i.e. a session.
---@return table list of buffer numbers
local function find_rogue_buffers()
    local ret = {}
    for _, v in ipairs(api.nvim_list_bufs() or {}) do
        if string.match(pasync.fn.bufname(v), "^SidebarNvim_.*") then
            if M.View.bufnr ~= v then
                table.insert(ret, v)
            end
        end
    end
    return ret
end

---Check if the tree buffer is valid and loaded.
---@return boolean
local function is_buf_valid()
    if M.View.bufnr == nil then
        return false
    end
    return api.nvim_buf_is_valid(M.View.bufnr) and api.nvim_buf_is_loaded(M.View.bufnr)
end

---Find pre-existing SidebarNvim buffer, delete its windows then wipe it.
---@private
function M._wipe_rogue_buffer()
    local bns = find_rogue_buffers()
    for _, bn in ipairs(bns) do
        if bn then
            local win_ids = pasync.fn.win_findbuf(bn)
            for _, id in ipairs(win_ids) do
                if pasync.fn.win_gettype(id) ~= "autocmd" then
                    api.nvim_win_close(id, true)
                end
            end

            api.nvim_buf_set_name(bn, "")
            pcall(api.nvim_buf_delete, bn, {})
        end
    end
end

local function generate_buffer_name()
    return "SidebarNvim_" .. math.random(1000000)
end

-- set user options and create tree buffer (should never be wiped)
function M.setup()
    M.View.side = config.side or M.View.side
    M.View.width = config.initial_width or M.View.width

    M.View.bufnr = api.nvim_create_buf(false, false)
    -- TODO: keybindings
    -- bindings.inject(M.View.bufnr)

    local buffer_name = generate_buffer_name()

    if not pcall(api.nvim_buf_set_name, M.View.bufnr, buffer_name) then
        M._wipe_rogue_buffer()
        api.nvim_buf_set_name(M.View.bufnr, buffer_name)
    end

    for _, opt in ipairs(M.View.bufopts) do
        vim.bo[M.View.bufnr][opt.name] = opt.val
    end

    local group = api.nvim_create_augroup("sidebar_nvim_prevent_buffer_override", { clear = true })
    api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = group,
        callback = function()
            pasync.run(function()
                M._prevent_buffer_override()
            end)
        end,
    })
end

local goto_tbl = { right = "h", left = "l", top = "j", bottom = "k" }

function M._prevent_buffer_override()
    local curwin = api.nvim_get_current_win()
    local curbuf = api.nvim_win_get_buf(curwin)
    if curwin ~= M.get_winnr() or curbuf == M.View.bufnr then
        return
    end

    pasync.cmd.buffer(M.View.bufnr)

    if #api.nvim_list_wins() < 2 then
        pasync.cmd.vsplit()
    else
        pasync.cmd.wincmd(goto_tbl[M.View.side])
    end

    -- copy target window options
    local winopts_target = vim.deepcopy(M.View.winopts)
    for key, _ in pairs(winopts_target) do
        winopts_target[key] = api.nvim_win_get_option(0, key)
    end

    -- change the buffer will override the target window with the sidebar window opts
    pasync.cmd.buffer(curbuf)

    -- revert the changes made when changing buffer
    for key, value in pairs(winopts_target) do
        api.nvim_win_set_option(0, key, value)
    end

    M.resize()
end

-- @param opts table
-- @param |- opts.any_tabpage boolean if true check if is open in any tabpage, if false check in current tab
function M.is_win_open(opts)
    if opts and opts.any_tabpage then
        for _, v in pairs(M.View.tabpages) do
            if api.nvim_win_is_valid(v.winnr) then
                return true
            end
        end
        return false
    else
        return M.get_winnr() ~= nil and api.nvim_win_is_valid(M.get_winnr())
    end
end

function M.set_cursor(opts)
    if M.is_win_open() then
        pcall(api.nvim_win_set_cursor, M.get_winnr(), opts)
    end
end

function M.focus(winnr)
    local wnr = winnr or M.get_winnr()

    if wnr == nil then
        return
    end

    if api.nvim_win_get_tabpage(wnr) ~= api.nvim_win_get_tabpage(0) then
        M.close()
        M.open()
        wnr = M.get_winnr()
    end

    api.nvim_set_current_win(wnr)
end

local function get_defined_width()
    if type(M.View.width) == "number" then
        return M.View.width
    end
    local width_as_number = tonumber(M.View.width:sub(0, -2))
    local percent_as_decimal = width_as_number / 100
    return math.floor(vim.o.columns * percent_as_decimal)
end

function M.resize()
    if not M.is_win_open() then
        return
    end

    if not api.nvim_win_is_valid(M.get_winnr()) then
        return
    end

    api.nvim_win_set_width(M.get_winnr(), get_defined_width())
end

local move_tbl = { left = "H", right = "L", bottom = "J", top = "K" }

local function set_local(opt, value)
    api.nvim_win_set_option(0, opt, value)
end

function M.open(options)
    options = options or { focus = false }
    if not is_buf_valid() then
        -- M.setup()
        P("view setup again")
    end

    api.nvim_command("vsp")

    local move_to = move_tbl[M.View.side]
    api.nvim_command("wincmd " .. move_to)
    api.nvim_command("vertical resize " .. get_defined_width())
    local winnr = api.nvim_get_current_win()
    local tabpage = api.nvim_get_current_tabpage()
    M.View.tabpages[tabpage] = vim.tbl_extend("force", M.View.tabpages[tabpage] or {}, { winnr = winnr })
    pasync.cmd.buffer(M.View.bufnr)
    for k, v in pairs(M.View.winopts) do
        set_local(k, v)
    end
    pasync.cmd.wincmd("=")
    if not options.focus then
        pasync.cmd.wincmd("p")
    end
end

function M.close()
    if not M.is_win_open() then
        return
    end
    if #api.nvim_list_wins() == 1 then
        local modified_buffers = utils.get_existing_buffers({ modified = true })

        if #modified_buffers == 0 then
            api.nvim_command(":silent q!")
        else
            utils.echo_warning("cannot exit with modified buffers!")
            api.nvim_command(":sb " .. modified_buffers[1])
        end
    end
    api.nvim_win_hide(M.get_winnr())
end

--- Returns the window number for sidebar-nvim within the tabpage specified
---@param tabpage number|nil: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number | nil
function M.get_winnr(tabpage)
    tabpage = tabpage or api.nvim_get_current_tabpage()
    local tabinfo = M.View.tabpages[tabpage]
    if tabinfo ~= nil then
        return tabinfo.winnr
    end
end

--- Returns the window width for sidebar-nvim within the tabpage specified
---@param tabpage number: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number
function M.get_width(tabpage)
    local winnr = M.get_winnr(tabpage)
    return pasync.fn.winwidth(winnr)
end

return M

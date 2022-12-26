local async = require("sidebar-nvim.lib.async")
local utils = require("sidebar-nvim.utils")
local logger = require("sidebar-nvim.logger")
local colors = require("sidebar-nvim.colors")
local LineBuilder = require("sidebar-nvim.lib.line_builder")
local ns = require("sidebar-nvim.lib.namespaces")

local api = async.api

local next_view_id = 1

local move_tbl = { left = "H", right = "L", bottom = "J", top = "K" }
local goto_tbl = { right = "h", left = "l", top = "j", bottom = "k" }

local ViewProps = {

    bufopts = {
        { name = "swapfile", val = false },
        { name = "buftype", val = "nofile" },
        { name = "modifiable", val = false },
        { name = "filetype", val = "SidebarNvim" },
        { name = "bufhidden", val = "hide" },
    },

    winopts = {
        ["local"] = {
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
        hide_statusline = false,
        position = "left",
        width = 30,
        height = 100,
    },

    sections = {},

    _internal_state = {
        bufnr = nil,
        tabpages = {},
        -- tab id -> winnr
        winnr = {},

        -- keymap_extmark_id -> key -> cb
        keymaps = {},
    },
}

local View = {}

View.__index = View

-- return the buffer with the specified name
---@private
local function find_buffer(name)
    for _, v in ipairs(api.nvim_list_bufs() or {}) do
        if async.fn.bufname(v) == name then
            return v
        end
    end
end

---Find pre-existing SidebarNvim buffer, delete its windows then wipe it.
---@private
local function wipe_rogue_buffer(name)
    local bufnr = find_buffer(name)

    if not bufnr then
        return
    end

    local win_ids = async.fn.win_findbuf(bufnr)
    for _, id in ipairs(win_ids) do
        if async.fn.win_gettype(id) ~= "autocmd" then
            api.nvim_win_close(id, true)
        end
    end

    api.nvim_buf_set_name(bufnr, "")
    pcall(api.nvim_buf_delete, bufnr, {})
end

-- @private
local function create_buf(view_id, bufopts)
    local bufnr = api.nvim_create_buf(false, false)

    local bufname = "SidebarNvimView" .. view_id
    wipe_rogue_buffer(bufname)

    api.nvim_buf_set_name(bufnr, bufname)

    for _, opt in ipairs(bufopts) do
        api.nvim_buf_set_option(bufnr, opt.name, opt.val)
    end

    return bufnr
end

-- @private
local function section_update(view, section_index, section, logger_props)
    local ctx = { view = view, width = view:get_width(), height = view:get_height() }

    local ok, data = pcall(section.draw, section, ctx)
    if not ok then
        logger:error(
            data,
            vim.tbl_deep_extend("force", { view_id = view.id, section_index = section_index }, logger_props or {})
        )
        return
    end

    data = data or {}

    view:draw(section_index, section, data)

    logger:debug("section update done", { view_id = view.id, section_index = section_index })
end

local function start_sections(view, sections)
    local group_id = api.nvim_create_augroup("SidebarNvimSectionsReloadersView" .. view.id, { clear = true })

    for section_index, section_data in ipairs(sections) do
        local ok, section_or_err = pcall(utils.resolve_section, section_data)
        if not ok then
            error(section_or_err .. " " .. " index: " .. section_index .. " view_id: " .. view.id)
        end

        local section = section_or_err
        assert(section, "invalid section! index:" .. section_index)

        local reloaders = section.reloaders or {}

        logger:debug("starting section", { view_id = view.id, index = section_index, reloaders_count = #reloaders })

        local hl_def = section.highlights or {}

        for hl_group, hl_group_data in pairs(hl_def.groups or {}) do
            colors.def_hl_group(hl_group, hl_group_data.gui, hl_group_data.fg, hl_group_data.bg)
        end

        for hl_group, hl_group_link_to in pairs(hl_def.links or {}) do
            colors.def_hl_link(hl_group, hl_group_link_to)
        end

        for _, reloader in ipairs(reloaders) do
            local cb = function()
                async.run(function()
                    section_update(view, section_index, section, { reloader = reloader })
                end)
            end
            reloader(group_id, cb)
        end

        section._internal_state.invalidate_cb = function()
            async.run(function()
                section_update(view, section_index, section, { requester = "user-invalidate" })
            end)
        end

        section_update(view, section_index, section, { requester = "bootstrap" })
        table.insert(view.sections, section)
    end
end

-- prevent the window to change buffers
-- @private
local function prevent_buffer_override(view)
    local group = api.nvim_create_augroup("SidebarNvimBufferOverrideView" .. view.id, { clear = true })
    api.nvim_create_autocmd({ "BufWinEnter" }, {
        group = group,
        callback = function()
            async.run(function()
                local curwin = api.nvim_get_current_win()
                local curbuf = api.nvim_win_get_buf(curwin)
                if
                    curwin ~= view:get_winnr()
                    or curbuf == view._internal_state.bufnr
                    or view.winopts.position == "float"
                then
                    return
                end

                async.cmd.buffer(view._internal_state.bufnr)

                if #api.nvim_list_wins() < 2 then
                    async.cmd.vsplit()
                else
                    async.cmd.wincmd(goto_tbl[view.winopts.position])
                end

                -- copy target window options
                local winopts_target = vim.deepcopy(view.winopts["local"])
                for key, _ in pairs(winopts_target) do
                    winopts_target[key] = api.nvim_win_get_option(0, key)
                end

                -- change the buffer will override the target window with the sidebar window opts
                async.cmd.buffer(curbuf)

                -- revert the changes made when changing buffer
                for key, value in pairs(winopts_target) do
                    api.nvim_win_set_option(0, key, value)
                end

                view:resize()
            end)
        end,
    })
end

function View:new(sections, opts)
    opts = vim.tbl_extend("force", vim.deepcopy(ViewProps), self, opts or {})
    opts._internal_state = vim.deepcopy(ViewProps._internal_state)

    opts.id = next_view_id
    next_view_id = next_view_id + 1

    opts.sections = {}
    opts._internal_state.bufnr = create_buf(opts.id, opts.bufopts)

    local obj = setmetatable(opts, self)

    prevent_buffer_override(obj)
    start_sections(obj, sections)

    return obj
end

local function normalize_size(input, total_size)
    if not input then
        return input
    end

    -- fixed size
    if type(input) == "number" then
        return input
    end

    -- percent string, example "4%"
    local percent = input:gsub(0, -2)
    local percent_decimal = percent / 100
    return math.floor(total_size * percent_decimal)
end

-- @param opts table
-- @param |- opts.any_tabpage boolean if true check if is open in any tabpage, if false check in current tab
function View:is_open(opts)
    if opts and opts.any_tabpage then
        for _, v in pairs(self._internal_state.winnr) do
            if api.nvim_win_is_valid(v.winnr) then
                return true
            end
        end
        return false
    end

    return self:get_winnr() ~= nil and api.nvim_win_is_valid(self:get_winnr())
end

local function set_width(winnr, w)
    local resize_total = vim.o.columns
    api.nvim_win_set_width(winnr, normalize_size(w, resize_total))
end

local function set_height(winnr, h)
    local resize_total = vim.o.lines
    api.nvim_win_set_height(winnr, normalize_size(h, resize_total))
end

function View:open(opts)
    if self:is_open() then
        return
    end

    opts = opts or { focus = false }

    if self.winopts.position ~= "float" then
        api.nvim_command("vsp")

        local move_to = move_tbl[self.winopts.position]
        api.nvim_command("wincmd " .. move_to)

        local winnr = api.nvim_get_current_win()

        set_height(winnr, self.winopts.height)
        set_width(winnr, self.winopts.width)

        local tabpage = api.nvim_get_current_tabpage()
        self._internal_state.winnr[tabpage] =
            vim.tbl_extend("force", self._internal_state.winnr[tabpage] or {}, { winnr = winnr })
        async.cmd.buffer(self._internal_state.bufnr)
        for k, v in pairs(self.winopts["local"]) do
            api.nvim_win_set_option(winnr, k, v)
        end
        async.cmd.wincmd("=")
        if not opts.focus then
            async.cmd.wincmd("p")
        end
    end

    -- TODO: float
    -- TODO: should allow buffer override in float windows?
end

--- Returns the window number for sidebar-nvim within the tabpage specified
---@param tabpage number|nil: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number | nil
function View:get_winnr(tabpage)
    tabpage = tabpage or api.nvim_get_current_tabpage()
    local tabinfo = self._internal_state.winnr[tabpage]
    if tabinfo ~= nil then
        return tabinfo.winnr
    end
end

--- Returns the window width for sidebar-nvim within the tabpage specified
---@param tabpage number: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number
function View:get_width(tabpage)
    local winnr = self:get_winnr(tabpage)
    return async.fn.winwidth(winnr)
end

--- Returns the window height for sidebar-nvim within the tabpage specified
---@param tabpage number: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number
function View:get_height(tabpage)
    local winnr = self:get_winnr(tabpage)
    return async.fn.winheight(winnr)
end

function View:close()
    if not self:is_open() then
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
    api.nvim_win_hide(self:get_winnr())
end

function View:resize()
    if not self:is_open() then
        return
    end

    if not api.nvim_win_is_valid(self:get_winnr()) then
        return
    end

    set_width(self:get_winnr(), self.winopts.width)
    set_height(self:get_winnr(), self.winopts.height)
end

function View:get_extmark_by_id(id)
    local mark =
        api.nvim_buf_get_extmark_by_id(self._internal_state.bufnr, ns.extmarks_namespace_id, id, { details = true })
    local row, col, details = mark[1], mark[2], mark[3]

    if details then
        details.start_row = row
        details.start_col = col
    end

    return details
end

-- @private
function View:get_last_extmark()
    local ids = vim.tbl_map(function(section)
        return section._internal_state.extmark_id
    end, self.sections)

    local id = #ids > 0 and ids[#ids] or nil

    if not id then
        return nil
    end

    return self:get_extmark_by_id(id)
end

-- @private
function View:draw(section_index, section, data)
    if not api.nvim_buf_is_loaded(self._internal_state.bufnr) then
        return
    end

    local cursor
    if self:is_open() then
        cursor = api.nvim_win_get_cursor(self:get_winnr())
    end

    local max_width = self:get_width()

    self:draw_section(max_width, section_index, section, data)

    if self:is_open() then
        -- TODO: do we still need this?
        -- if cursor and #lines >= cursor[1] then
        --     api.nvim_win_set_cursor(view.get_winnr(), cursor)
        -- end
        if cursor then
            api.nvim_win_set_option(self:get_winnr(), "wrap", false)
        end

        if self.winopts.hide_statusline then
            api.nvim_win_set_option(self:get_winnr(), "statusline", "%#NonText#")
        end
    end
end

-- @private
function View:draw_section(max_width, section_index, section, data)
    -- TODO: we're passing section index everywhere, maybe it's time for a log span thing (tracing)
    logger:debug("drawing section", { view_id = self.id, section_index = section_index })

    local start_row = 0
    -- we need this to make proper replacements and make neovim move things correctly
    -- otherwise it will just replace the next sections
    local previous_end_row = nil

    if section._internal_state.extmark_id then
        local extmark = self:get_extmark_by_id(section._internal_state.extmark_id)
        if extmark then
            start_row = extmark.start_row
            previous_end_row = extmark.end_row
        else
            logger:error("error trying to find extmark", {
                namespace_id = ns.extmarks_namespace_id,
                extmark = "not found",
                section_index = section_index,
                id = section._internal_state.extmark_id or "invalid section extmark id",
                start_row = start_row,
            })
        end
    -- get the last known position in the buffer
    else
        local last_extmark = self:get_last_extmark()
        if last_extmark then
            start_row = last_extmark.end_row + 1
        end

        -- since we don't have the old end_row yet, we calculate the initial end_row based on the length
        previous_end_row = start_row + #data - 1
    end

    local lines = {}
    local hls = {}
    local keymaps = {}

    for _, line in ipairs(data) do
        local current_line, current_hl = LineBuilder.build_from_table(line, max_width)

        table.insert(lines, current_line)
        table.insert(hls, current_hl)

        local current_keymaps = {}
        for key, cb in pairs(line.keymaps or {}) do
            table.insert(current_keymaps, { key = key, cb = cb, start_col = 0, end_col = #current_line })
        end

        table.insert(keymaps, current_keymaps)
    end

    local change = {
        start_row = start_row,
        previous_end_row = previous_end_row,
        end_row = start_row + #data - 1,
        lines = lines,
        hls = hls,
        keymaps = keymaps,
    }

    api.nvim_buf_set_option(self._internal_state.bufnr, "modifiable", true)

    api.nvim_buf_set_lines(
        self._internal_state.bufnr,
        change.start_row,
        change.previous_end_row + 1,
        false,
        change.lines
    )

    section._internal_state.extmark_id =
        api.nvim_buf_set_extmark(self._internal_state.bufnr, ns.extmarks_namespace_id, change.start_row, 0, {
            id = section._internal_state.extmark_id,
            end_row = change.end_row,
            end_col = 0,
            ephemeral = false,
        })

    self:render_hl(change.hls, change.start_row, change.end_row)

    -- TODO: maybe not clean and reuse old extmarks?
    api.nvim_buf_clear_namespace(self._internal_state.bufnr, ns.keymaps_namespace_id, change.start_row, change.end_row)

    self:attach_change_keymaps(section, change.keymaps, change.start_row, change.end_row)
    self:attach_section_keymaps(section, change.start_row, change.end_row, 0, 0)

    api.nvim_buf_set_option(self._internal_state.bufnr, "modifiable", false)
end

function View:render_hl(hls, start_row, end_row)
    api.nvim_buf_clear_namespace(self._internal_state.bufnr, ns.hl_namespace_id, start_row, end_row)

    for line_offset, line_hls in ipairs(hls) do
        for _, hl in ipairs(line_hls) do
            api.nvim_buf_add_highlight(
                self._internal_state.bufnr,
                ns.hl_namespace_id,
                hl.group,
                start_row + line_offset - 1,
                hl.start_col,
                hl.start_col + hl.length
            )
        end
    end
end

-- @private
function View:update_keymaps_map(section, extmark_id, key, cb)
    self._internal_state.keymaps[extmark_id] = self._internal_state.keymaps[extmark_id] or {}
    self._internal_state.keymaps[extmark_id][key] = { cb = cb, section = section }

    vim.keymap.set("n", key, function()
        local cursor = vim.api.nvim_win_get_cursor(0)

        local cursor_row = cursor[1] - 1
        local cursor_col = cursor[2]

        local extmarks = vim.api.nvim_buf_get_extmarks(
            self._internal_state.bufnr,
            ns.keymaps_namespace_id,
            0,
            -1,
            { details = true }
        )

        for _, extmark in ipairs(extmarks) do
            local id = extmark[1]

            local kb = (self._internal_state.keymaps[id] or {})[key]
            if not kb then
                goto continue
            end

            local start_row = extmark[2]
            local end_row = extmark[4].end_row or extmark[2]
            local start_col = extmark[3]
            local end_col = extmark[4].end_col or extmark[3]

            -- based on this: https://github.com/neovim/neovim/pull/21393/files#diff-7a0fd644bfc20cec6b227e43716f4e27a46e8a65d76c73933a3d288940f8080bR115-R117
            if
                (cursor_row >= start_row and cursor_row <= end_row) -- within the rows of the extmark
                and (cursor_row > start_row or cursor_col >= start_col) -- either not the first row, or in range of the col
                and (cursor_row < end_row or cursor_col < end_col) -- either not in the last row or in range of the col
            then
                async.run(function()
                    kb.cb()
                    kb.section:invalidate()
                end)
            end

            ::continue::
        end
    end, {
        buffer = self._internal_state.bufnr,
        silent = true,
        nowait = true,
        desc = "SidebarNvim section keybinding",
    })
end

-- @private
function View:attach_change_keymaps(section, keymaps, start_row, end_row)
    for line_offset, line_kbs in ipairs(keymaps) do
        for _, kb in ipairs(line_kbs) do
            local line_index = start_row + line_offset - 1

            local extmark_id = api.nvim_buf_set_extmark(
                self._internal_state.bufnr,
                ns.keymaps_namespace_id,
                line_index,
                kb.start_col,
                { end_col = kb.end_col, end_row = line_index }
            )

            self:update_keymaps_map(section, extmark_id, kb.key, kb.cb)
        end
    end
end

-- @private
function View:attach_section_keymaps(section, start_row, end_row, start_col, end_col)
    local keymaps = section:get_default_keymaps() or {}

    local extmark_id = api.nvim_buf_set_extmark(
        self._internal_state.bufnr,
        ns.keymaps_namespace_id,
        start_row,
        start_col,
        { end_col = end_col, end_row = end_row }
    )

    for key, cb in pairs(keymaps) do
        self:update_keymaps_map(section, extmark_id, key, cb)
    end
end

function View:get_bufnr()
    return self._internal_state.bufnr
end

return View

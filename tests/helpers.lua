local LineBuilder = require("sidebar-nvim.lib.line_builder")
local async = require("sidebar-nvim.lib.async")
local spy = require("luassert.spy")

Helpers = {}

function Helpers.assert_lines(lines1, lines2)
    for i, line in ipairs(lines1) do
        assert.is.truthy(line)
        assert.is.truthy(lines2[i])
        assert.are.same(line.current, lines2[i].current)
        assert.are.same(line.keymaps, lines2[i].keymaps)
        assert.are.same(line, lines2[i])
    end

    assert.are.equal(#lines1, #lines2)
end

function P(...)
    print(vim.inspect(...))
end

function Helpers.create_test_section(id)
    local section = {
        title = string.format("s%d", id),
        icon = id,
        reloaders = {},

        _internal_state = {},

        draw = spy.new(function()
            return { LineBuilder:new():left(id) }
        end),

        _test_data = {},
    }

    table.insert(
        section.reloaders,
        spy.new(function(_, cb)
            section._test_data.reloader_cb = cb
        end)
    )

    return section
end

local function check_snapsot_lines(filename, lines)
    if async.fn.filereadable(async.fn.expand(filename)) == 1 then
        local data = async.fs.read_file(filename)

        assert(data == lines, vim.diff(data, lines, { result_type = "unified" }))
        return
    end

    -- create snapshot
    print("lines snapshot does not exist, creating new one")
    async.fn.mkdir(async.fn.fnamemodify(filename, ":h"), "p")

    async.fs.write_file(filename, lines)
end

local function check_snapsot_hls(filename, hls)
    if async.fn.filereadable(async.fn.expand(filename)) == 1 then
        local data = vim.json.decode(async.fs.read_file(filename))

        assert.is.same(data, hls)
        return
    end

    -- create snapshot
    print("hl snapshot does not exist, creating new one")
    async.fn.mkdir(async.fn.fnamemodify(filename, ":h"), "p")

    async.fs.write_file(filename, vim.json.encode(hls))
end

function Helpers.test_snapshot(test_name, opts)
    opts = vim.tbl_extend("force", { with_hl = true }, opts or {})

    local base_filename = test_name:gsub("%s", "_"):gsub(":", "_"):gsub("/", "_")

    local snapshot_filename_lines = string.format("__snapshots__/%s_lines.snap", base_filename)

    local snapshot_filename_hl = string.format("__snapshots__/%s_hls.snap", base_filename)

    local view = require("sidebar-nvim.view")
    local renderer = require("sidebar-nvim.renderer")

    local lines = async.api.nvim_buf_get_lines(view.View.bufnr, 0, -1, false)
    lines = table.concat(lines, "\n")

    check_snapsot_lines(snapshot_filename_lines, lines)

    if not opts.with_hl then
        return
    end

    local hls = async.api.nvim_buf_get_extmarks(view.View.bufnr, renderer.hl_namespace_id, 0, -1, { details = true })

    check_snapsot_hls(snapshot_filename_hl, hls)
end

function Helpers.it_snapshot_wrapper(it, prefix)
    return function(test_name, test_fn)
        it(test_name, function()
            test_fn()
            Helpers.test_snapshot(string.format("%s: %s", prefix, test_name))
        end)
    end
end

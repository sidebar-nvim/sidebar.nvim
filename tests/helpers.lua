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

local function read_file(filename)
    local err, fd = async.uv.fs_open(filename, "r", 438)
    assert(not err, err)

    local stat
    err, stat = async.uv.fs_fstat(fd)
    assert(not err, err)

    local data
    err, data = async.uv.fs_read(fd, stat.size, 0)
    assert(not err, err)

    err = async.uv.fs_close(fd)
    assert(not err, err)

    return data
end

function Helpers.test_snapshot(test_name)
    local snapshot_filename =
        string.format("__snapshots__/%s.snap", test_name:gsub("%s", "_"):gsub(":", "_"):gsub("/", "_"))

    local view = require("sidebar-nvim.view")
    local lines = async.api.nvim_buf_get_lines(view.View.bufnr, 0, -1, false)
    lines = table.concat(lines, "\n")

    if async.fn.filereadable(async.fn.expand(snapshot_filename)) == 1 then
        local data = read_file(snapshot_filename)

        assert(data == lines, vim.diff(data, lines, { result_type = "unified" }))
        return
    end

    -- create snapshot
    print("snapshot does not exist, creating new one")
    async.fn.mkdir(async.fn.fnamemodify(snapshot_filename, ":h"), "p")

    local err, fd = async.uv.fs_open(snapshot_filename, "w", 438)
    assert(not err, err)

    err = async.uv.fs_write(fd, lines)
    assert(not err, err)

    err = async.uv.fs_close(fd)
    assert(not err, err)
end

function Helpers.it_snapshot_wrapper(it, prefix)
    return function(test_name, test_fn)
        it(test_name, function()
            test_fn()
            Helpers.test_snapshot(string.format("%s: %s", prefix, test_name))
        end)
    end
end

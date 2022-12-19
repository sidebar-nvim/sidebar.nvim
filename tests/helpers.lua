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

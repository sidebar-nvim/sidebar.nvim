local Error = { message = "", attrs = {}, original = nil }

function Error:new(message, attrs, original)
    local err = {
        message = message,
        attrs = attrs,
        original = original,
    }

    setmetatable(err, self)
    self.__index = self
    return err
end

function Error:format_attrs()
    local values = {}

    for k, v in pairs(self.attrs or {}) do
        table.insert(values, string.format("%s=%s", k, v))
    end

    return table.concat(values, ", ")
end

function Error:__tostring()
    return string.format("%s %s from: %s", self.message, self:format_attrs(), self.original)
end

return Error

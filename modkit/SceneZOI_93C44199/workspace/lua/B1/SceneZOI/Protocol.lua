-- Restricted, versioned ASCII messages; no executable scene expressions.
local M = {}

function M.pack(...)
    local fields = {"SZ2"}
    for _, field in ipairs({...}) do
        local value = tostring(field)
        assert(value:match("^[%w_.:+%-]+$"), "Unsafe SceneZOI protocol field")
        fields[#fields + 1] = value
    end
    return table.concat(fields, "|")
end

function M.unpack(value)
    if type(value) ~= "string" then return nil end
    -- cfg_load returns JSON text. The payload itself has no escaping or quotes.
    local packet = value:match("SZ2|[%w_.:+|%-]+")
    if not packet then return nil end
    local fields = {}
    for field in packet:gmatch("[^|]+") do fields[#fields + 1] = field end
    if fields[1] ~= "SZ2" or #fields < 2 then return nil end
    table.remove(fields, 1)
    return fields
end

-- Encode UTF-8 labels as inert hex inside the restricted ASCII protocol.
function M.encode(value)
    local text = tostring(value or "")
    if text == "" then return "00" end
    return (text:gsub(".", function(char) return string.format("%02x", string.byte(char)) end))
end

function M.decode(value)
    if value == "00" then return "" end
    if type(value) ~= "string" or #value % 2 ~= 0 or value:find("[^%x]") then return nil end
    return (value:gsub("%x%x", function(byte) return string.char(tonumber(byte, 16)) end))
end

function M.id(value)
    if type(value) == "string" or type(value) == "number" then return tostring(value) end
    return tostring(value.Value)
end

return M

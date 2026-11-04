local M = {}
function M.copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do if type(item) ~= "function" then result[key] = M.copy(item) end end
    return result
end
function M.map(value)
    local map = value or {}
    function map:Find(key) return self[key] end
    function map:Add(key, item) self[key] = M.copy(item) end
    function map:ToTable()
        local result = {}
        for key, item in pairs(self) do if type(item) ~= "function" then result[key] = item end end
        return result
    end
    return map
end
function M.array(value)
    local array = value or {}
    function array:Add(item)
        local copy=M.copy(item)
        if copy.PrintedAccessoryData then copy.PrintedAccessoryData=M.map(copy.PrintedAccessoryData) end
        self[#self+1]=copy
    end
    function array:Clear() for i=#self,1,-1 do self[i]=nil end end
    return array
end
function M.style()
    return {Outfit={Garments=M.map(),Accessories=M.map(),PrintedAccessories=M.array()}}
end
return M

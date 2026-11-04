-- The registry belongs to the framework; every actual profile is pack data.
local M={}
function M.set(value)M.value=value end
local function get(kind,id)
 local data=M.value
 if not data then data=require('SceneZOI.Catalog').get_snapshot().profiles end
 return assert(data[kind][id],'Unavailable '..kind..' profile: '..tostring(id))
end
function M.body(id)return get('body',id)end
function M.material(id)return get('material',id)end
return M

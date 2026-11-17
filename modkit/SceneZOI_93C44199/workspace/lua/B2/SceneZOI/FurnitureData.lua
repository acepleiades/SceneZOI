local V=require('SceneZOI.DataValidation')
local M={}
function M.profile(v)
 V.fields(v,{'schema_version','id','kind','objects','surface_height_cm','offset_cm','yaw_degrees'},{'schema_version','id','kind','objects','surface_height_cm'})
 assert(v.schema_version==1,'Unsupported furniture profile version');V.id(v.id);V.id(v.kind)
 V.array(v.objects,512);assert(#v.objects>0,'Empty furniture object list');local seen={}
 for _,id in ipairs(v.objects)do V.name(id);assert(not seen[id],'Duplicate furniture object');seen[id]=true end
 V.number(v.surface_height_cm,-10000,10000);V.number(v.yaw_degrees or 0,-360,360)
 local o=v.offset_cm or {};V.fields(o,{'x','y','z'})
 for _,k in ipairs({'x','y','z'})do V.number(o[k]or 0,-10000,10000)end
 return V.copy(v)
end
return M

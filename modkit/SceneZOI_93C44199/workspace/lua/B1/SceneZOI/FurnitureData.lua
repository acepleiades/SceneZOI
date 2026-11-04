local V=require('SceneZOI.DataValidation')
local M={}
function M.scene(v)
 if v==nil then return end
 V.fields(v,{'kind','surface_height_cm'},{'kind','surface_height_cm'})
 V.id(v.kind);V.number(v.surface_height_cm,-10000,10000)
end
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
function M.compile(snapshot)
 local result={profiles={},objects={},warnings={}}
 for _,doc in ipairs(snapshot.by_kind.furniture_profile or {})do
  local ok,p=pcall(M.profile,doc.data)
  if ok then
   local conflict=result.profiles[p.id]and not V.equal(result.profiles[p.id],p)
   for _,id in ipairs(p.objects)do if result.objects[id]and not V.equal(result.objects[id],p)then conflict=true end end
   if conflict then result.warnings[#result.warnings+1]='Conflicting furniture profile: '..p.id
   else result.profiles[p.id]=p;for _,id in ipairs(p.objects)do result.objects[id]=p end end
  else result.warnings[#result.warnings+1]=doc.source..': '..tostring(p)end
 end
 return result
end
function M.compatible(node,profile)
 return node.furniture and profile and node.furniture.kind==profile.kind or not node.furniture and not profile
end
return M

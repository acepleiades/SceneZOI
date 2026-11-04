-- Inert namespaced annotations; no evaluation, asset loading or runtime callbacks.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local M={}
function M.validate(value)
 if value==nil then return end
 assert(V.object(value),'addon_data must be a namespace object')
 local count=0
 local function visit(v,depth)
  count=count+1;assert(count<=1024 and depth<=8,'addon_data exceeds nesting/item limits')
  if v==J.null then return end
  local t=type(v)
  assert(t=='table'or t=='string'or t=='boolean'or t=='number','addon_data must contain JSON values')
  if t=='number'then assert(v==v and math.abs(v)<math.huge,'addon_data contains a non-finite number')end
  if t=='table'then for k,x in pairs(v)do
   assert(type(k)=='string'or(type(k)=='number'and k>=1 and k%1==0),'Invalid addon_data key');visit(x,depth+1)
  end end
 end
 for namespace,data in pairs(value)do
  V.id(namespace);assert(namespace:find('.',1,true),'addon_data namespaces must include author.addon')
  assert(V.object(data),'Each addon_data namespace must contain an object');visit(data,1)
 end
 assert(#J.encode(value)<=8192,'addon_data exceeds 8 KiB')
end
function M.scene(node)
 M.validate(node.addon_data)
 assert(V.object(node.participant_addon_data or {}),'Invalid participant_addon_data')
 for role,data in pairs(node.participant_addon_data or {})do assert(node.participants[role],'Unbound addon_data participant');M.validate(data)end
 for _,a in ipairs(node.actions or {})do M.validate(a.addon_data)end
end
return M

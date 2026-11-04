local V=require('SceneZOI.DataValidation')
local M={}
local function tags(t)V.array(t or {},256);for _,s in ipairs(t or {})do V.id(s:lower():gsub('[%s%-]+','_'))end end
function M.validate(v)
 require('SceneZOI.AddonData').scene(v)
 tags(v.tags);assert(V.object(v.participant_tags or {}),'Invalid participant tags')
 for role,t in pairs(v.participant_tags or {})do assert(v.participants[role],'Unbound tag participant');tags(t)end
 V.array(v.actions or {},256)
 for _,a in ipairs(v.actions or {})do
  V.fields(a,{'type','actor','target','performer','addon_data'},{'type','actor'});V.id(a.type:lower():gsub('[%s%-]+','_'))
  for _,key in ipairs({'actor','target','performer'})do if a[key]then assert(v.participants[a[key]],'Unbound action participant')end end
 end
end
return M

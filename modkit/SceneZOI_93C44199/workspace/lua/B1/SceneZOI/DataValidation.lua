-- Shared inert-data validation. No asset loads, code evaluation or pack callbacks.
local M={}
function M.object(v)
 return type(v)=='table'and not(getmetatable(v)and getmetatable(v).__jsonkind~='object')
end
function M.fields(v,allowed,required)
 assert(M.object(v),'Expected data object')
 local names={};for _,k in ipairs(allowed)do names[k]=true end
 for k in pairs(v)do assert(names[k],'Unknown data field: '..tostring(k))end
 for _,k in ipairs(required or {})do assert(v[k]~=nil,'Missing data field: '..k)end
end
function M.array(v,maximum)
 assert(type(v)=='table'and not(getmetatable(v)and getmetatable(v).__jsonkind~='array'),'Expected data array')
 local n=0;for k in pairs(v)do n=n+1;assert(type(k)=='number'and k%1==0 and k>=1,'Invalid array key')end
 assert(n==#v and n<=(maximum or 4096),'Invalid array length');return v
end
function M.id(v)
 assert(type(v)=='string'and #v<=96 and v:match('^[a-z][a-z0-9_.%-]*$'),'Invalid identifier');return v
end
function M.name(v)
 assert(type(v)=='string'and #v>=1 and #v<=160 and v:match('%S') and not v:find('[%z\1-\31]'),'Invalid data name');return v
end
function M.asset(v)
 assert(type(v)=='string'and #v<=512 and v:match('^/[A-Za-z0-9_/]+%.[A-Za-z0-9_]+$'),'Invalid asset path');return v
end
function M.number(v,lo,hi,integer)
 assert(type(v)=='number'and v==v and math.abs(v)<math.huge and v>=lo and v<=hi and(not integer or v%1==0),'Invalid numeric value');return v
end
function M.boolean(v)assert(type(v)=='boolean','Invalid boolean');return v end
function M.copy(v)
 if type(v)~='table'then return v end
 local r={};for k,x in pairs(v)do r[k]=M.copy(x)end
 return setmetatable(r,getmetatable(v))
end
function M.equal(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not M.equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
function M.roles(roles)
 assert(M.object(roles)and next(roles),'Scene requires participant roles')
 local n=0
 for role,spec in pairs(roles)do
  n=n+1;M.id(role);M.fields(spec,{'body','body_age','growth_steps'},{'body'})
  assert(spec.body=='male'or spec.body=='female','Unsupported appearance body')
  if spec.body_age then M.name(spec.body_age)end
  if spec.growth_steps then
   M.array(spec.growth_steps,16);assert(#spec.growth_steps>0,'Empty life-stage requirement')
   local seen={};for _,step in ipairs(spec.growth_steps)do M.name(step);assert(not seen[step],'Duplicate life stage');seen[step]=true end
  end
 end
 assert(n<=64,'Too many scene roles');return roles
end
M.slots={Top=true,Bottom=true,Full=true,Jacket=true,Shoes=true,Socks=true,InnerTop=true,InnerUnder=true,Stockings=true,Gloves=true,Scarf=true}
function M.outfits(value,roles)
 assert(M.object(value),'Expected outfit directives')
 for role,spec in pairs(value)do
  assert(roles[role],'Unbound outfit owner');M.fields(spec,{'remove_slots'},{'remove_slots'});M.array(spec.remove_slots,32)
  local seen={};for _,slot in ipairs(spec.remove_slots)do assert(M.slots[slot]and not seen[slot],'Unsupported or duplicate outfit slot');seen[slot]=true end
 end
end
function M.point(v,roles)
 M.fields(v,{'participant','component','bones'},{'participant','component','bones'})
 assert(roles[v.participant],'Unbound bone target');assert(v.component=='head'or v.component=='body','Unsupported target component')
 M.array(v.bones,8);assert(#v.bones>0,'Empty bone target')
 local seen={};for _,bone in ipairs(v.bones)do M.name(bone);assert(not seen[bone],'Duplicate bone target');seen[bone]=true end
end
return M

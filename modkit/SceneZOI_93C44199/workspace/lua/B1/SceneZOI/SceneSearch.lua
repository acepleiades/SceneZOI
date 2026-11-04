-- One predicate is shared by discovery, random choice and every session route.
local V=require('SceneZOI.DataValidation')
local Meta=require('SceneZOI.Metadata')
local J=require('SceneZOI.Json')
local M={}
local function array(t)V.array(t or {},256);return t or {}end
function M.criteria(registry,value)
 value=value or {};V.fields(value,{'allowed_content_ratings','required_tags','any_tags','excluded_tags','required_actions','any_actions','excluded_actions','participant_tags','action_filters','starting_hub_only'})
 local out=V.copy(value)
 if value.allowed_content_ratings then
  local seen={};for _,r in ipairs(array(value.allowed_content_ratings))do assert(Meta.ratings[r]and not seen[r],'Invalid/duplicate content rating');seen[r]=true end
 end
 for _,kind in ipairs({'tags','actions'})do for _,prefix in ipairs({'required_','any_','excluded_'})do
  local key=prefix..kind
  if value[key]then out[key]=J.array({});for _,n in ipairs(array(value[key]))do out[key][#out[key]+1]=Meta.resolve_name(registry,kind,n)end end
 end end
 if value.starting_hub_only~=nil then V.boolean(value.starting_hub_only)end
 assert(V.object(value.participant_tags or {}),'Invalid participant tag criteria')
 out.participant_tags={}
 for role,tags in pairs(value.participant_tags or {})do
  V.id(role);V.fields(tags,{'required_tags','any_tags','excluded_tags'})
  out.participant_tags[role]=M.criteria(registry,tags)
 end
 out.action_filters=J.array({})
 for _,a in ipairs(array(value.action_filters))do
  V.fields(a,{'type','actor','target','performer'},{'type'});local copy=V.copy(a);copy.type=Meta.resolve_name(registry,'actions',a.type)
  for _,key in ipairs({'actor','target','performer'})do if a[key]then V.id(a[key])end end
  out.action_filters[#out.action_filters+1]=copy
 end
 return out
end
local function contains(list,s)for _,v in ipairs(list or {})do if v==s then return true end end;return false end
local function list_match(list,query,kind)
 for _,s in ipairs(query['required_'..kind]or {})do if not contains(list,s)then return false end end
 local any=query['any_'..kind];if any and #any>0 then local found=false;for _,s in ipairs(any)do if contains(list,s)then found=true end end;if not found then return false end end
 for _,s in ipairs(query['excluded_'..kind]or {})do if contains(list,s)then return false end end
 return true
end
function M.matches(node,q)
 q=q or {}
 if q.allowed_content_ratings and not contains(q.allowed_content_ratings,node.content_rating)then return false end
 if q.starting_hub_only and not node.starting_hub then return false end
 if not list_match(node.tags,q,'tags')then return false end
 local types={};for _,a in ipairs(node.actions or {})do types[#types+1]=a.type end
 if not list_match(types,q,'actions')then return false end
 for role,tags in pairs(q.participant_tags or {})do
  if not node.participants[role]or not list_match((node.participant_tags or {})[role],tags,'tags')then return false end
 end
 for _,f in ipairs(q.action_filters or {})do
  local found=false
  for _,a in ipairs(node.actions or {})do
   local same=true;for key,value in pairs(f)do if a[key]~=value then same=false end end
   if same then found=true end
  end
  if not found then return false end
 end
 return true
end
function M.allowed(nodes,node,q,seen)
 if not node or not M.matches(node,q)then return false end
 if node.kind~='transition'then return true end
 seen=seen or {};if seen[node.id]then return false end;seen[node.id]=true
 return M.allowed(nodes,nodes[node.destination],q,seen)
end
function M.bind(node,roster,pinned)
 local Traits=require('SceneZOI.Traits');local roles,seen={},{}
 for role in pairs(node.participants)do roles[#roles+1]=role end;table.sort(roles)
 if #roles~=#roster then return nil end
 for _,p in ipairs(roster)do assert(p.id and not seen[p.id],'Duplicate selected participant');seen[p.id]=true end
 local occupied,locked={},{}
 if pinned then
  assert(V.object(pinned),'Invalid bindings')
  for role,id in pairs(pinned)do
   assert(node.participants[role]and type(id)=='string','Invalid role binding')
   local found=false
   for i,p in ipairs(roster)do if p.id==id then
    if occupied[i]or not Traits.matches(node.participants[role],p)then return nil end
    occupied[i],locked[role],found=role,true,true
   end end
   if not found then return nil end
  end
 end
 local assign
 assign=function(role,visited)
  for i,person in ipairs(roster)do if not visited[i]and Traits.matches(node.participants[role],person)then
   visited[i]=true;if not occupied[i]or(not locked[occupied[i]]and assign(occupied[i],visited))then occupied[i]=role;return true end
  end end;return false
 end
 for _,role in ipairs(roles)do if not locked[role]and not assign(role,{})then return nil end end
 local bindings={};for i,role in pairs(occupied)do bindings[role]=roster[i].id end;return bindings
end
function M.find(catalog,query,roster,profile,pinned)
 assert(not pinned or roster,'Bindings require participants')
 local result={}
 for id,node in pairs(catalog.nodes)do
  if M.allowed(catalog.nodes,node,query)and (not roster or require('SceneZOI.FurnitureData').compatible(node,profile))then
   local bindings
   if roster then
    -- Different scene role names simply do not match this explicit binding.
    local roles_match=true;for role in pairs(pinned or {})do if not node.participants[role]then roles_match=false end end
    if roles_match then bindings=M.bind(node,roster,pinned)end
   end
   if not roster or bindings then result[#result+1]={scene_id=id,bindings=bindings,content_rating=node.content_rating,tags=V.copy(node.tags or {}),participant_tags=V.copy(node.participant_tags or {}),actions=V.copy(node.actions or {}),starting_hub=node.starting_hub==true,label=node.label,furniture=V.copy(node.furniture)}end
  end
 end
 table.sort(result,function(a,b)return a.scene_id<b.scene_id end);return J.array(result)
end
function M.random(rows,random)
 if #rows==0 then return nil end
 local i=(random or math.random)(#rows);assert(type(i)=='number'and i%1==0 and rows[i],'Invalid random scene result');return V.copy(rows[i])
end
return M

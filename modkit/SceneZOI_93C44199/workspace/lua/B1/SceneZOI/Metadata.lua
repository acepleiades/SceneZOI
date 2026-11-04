-- Inert dictionaries, directional actions and derived ratings. No gameplay effects.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local M={ratings={GENERAL=1,SUGGESTIVE=2,EXPLICIT=3}}
function M.name(s)
 assert(type(s)=='string'and #s<=96,'Invalid metadata name')
 s=s:lower():match('^%s*(.-)%s*$'):gsub('[%s%-]+','_');V.id(s);return s
end
local function names(v)
 V.array(v or {},256);local out,seen={},{}
 for _,s in ipairs(v or {})do local n=M.name(s);assert(not seen[n],'Duplicate metadata name');seen[n]=true;out[#out+1]=n end
 return out
end
function M.dictionary(data,kind,owner)
 local key=kind=='tag_dictionary'and 'tags'or 'actions'
 V.fields(data,{'schema_version','id',key},{'schema_version','id',key});assert(data.schema_version==1,'Unsupported metadata dictionary version');V.id(data.id);V.array(data[key],512)
 local out={}
 for _,d in ipairs(data[key])do
  V.fields(d,{'id','aliases','description','content_rating','actor_description','target_description','performer_description','actor_requirements','target_requirements','addon_data'},key=='actions'and {'id','description','content_rating'}or {'id','description'})
  assert(d.id==M.name(d.id),'Canonical metadata IDs must be normalized');V.name(d.description)
  if owner and owner~='scenezoi'then assert(d.id:sub(1,#owner+1)==owner..'.','Custom metadata must use its owner namespace')end
  for _,alias in ipairs(d.aliases or {})do assert(alias==M.name(alias),'Dictionary aliases must use lowercase words separated by underscores')end
  require('SceneZOI.AddonData').validate(d.addon_data)
  local value=V.copy(d);value.aliases=J.array(names(d.aliases))
  if key=='actions'then assert(M.ratings[d.content_rating],'Unknown action content_rating')
  else assert(d.content_rating==nil,'Only actions have content_rating')end
  for _,k in ipairs({'actor_description','target_description','performer_description'})do if d[k]then V.name(d[k])end end
  for _,k in ipairs({'actor_requirements','target_requirements'})do if d[k]then value[k]=names(d[k])end end
  if owner and owner~='scenezoi'then for _,alias in ipairs(value.aliases)do assert(alias:sub(1,#owner+1)==owner..'.','Custom aliases must use their owner namespace')end end
  assert(not out[value.id],'Duplicate dictionary ID');out[value.id]=value
 end
 return out
end
function M.compile(source)
 local result={tags={},actions={},tag_names={},action_names={},warnings={}}
 for _,kind in ipairs({'tag_dictionary','action_dictionary'})do
  local key=kind=='tag_dictionary'and 'tags'or 'actions';local defs,conflict={},{}
  for _,doc in ipairs((source.by_kind or {})[kind]or {})do
   local ok,rows=pcall(M.dictionary,doc.data,kind,doc.owner)
   if ok then for id,value in pairs(rows)do
    if defs[id]and not V.equal(defs[id],value)then conflict[id]=true else defs[id]=value end
   end else result.warnings[#result.warnings+1]=doc.source..': '..tostring(rows)end
  end
  local aliases,claims={},{}
  for id,d in pairs(defs)do
   local list={id};for _,a in ipairs(d.aliases)do list[#list+1]=a end
   for _,name in ipairs(list)do
    claims[name]=claims[name]or {};claims[name][id]=true
   end
  end
  for name,ids in pairs(claims)do
   local count=0;for _ in pairs(ids)do count=count+1 end
   if count>1 then for id in pairs(ids)do conflict[id]=true end;result.warnings[#result.warnings+1]='Ambiguous metadata alias: '..name end
  end
  for id,d in pairs(defs)do
   if conflict[id]then result.warnings[#result.warnings+1]='Conflicting metadata definition: '..id
   else result[key][id]=d;aliases[id]=id;for _,a in ipairs(d.aliases)do aliases[a]=id end end
  end
  result[key=='tags'and 'tag_names'or 'action_names']=aliases
 end
 table.sort(result.warnings);return result
end
function M.resolve_name(registry,kind,name)
 local key=kind=='tags'and 'tag_names'or 'action_names'
 return assert(registry[key][M.name(name)],'Unknown registered '..kind..': '..tostring(name))
end
local function resolved(registry,kind,value)
 local out,seen={},{}
 for _,name in ipairs(names(value))do local id=M.resolve_name(registry,kind,name);assert(not seen[id],'Duplicate canonical '..kind);seen[id]=true;out[#out+1]=id end
 table.sort(out);return J.array(out)
end
function M.validate_scene(node)
 require('SceneZOI.AddonData').scene(node)
 names(node.tags);V.fields(node.participant_tags or {},(function()local r={};for role in pairs(node.participants)do r[#r+1]=role end;return r end)())
 for _,tags in pairs(node.participant_tags or {})do names(tags)end
 V.array(node.actions or {},256)
 for _,a in ipairs(node.actions or {})do
  V.fields(a,{'type','actor','target','performer','addon_data'},{'type','actor'});M.name(a.type)
  for _,key in ipairs({'actor','target','performer'})do if a[key]then assert(node.participants[a[key]],'Unbound action '..key)end end
 end
end
function M.resolve_scene(registry,node)
 M.validate_scene(node)
 local out=V.copy(node);out.tags=resolved(registry,'tags',node.tags);out.participant_tags={};out.actions=J.array({})
 for role,tags in pairs(node.participant_tags or {})do out.participant_tags[role]=resolved(registry,'tags',tags)end
 local highest=0;local seen={}
 for _,a in ipairs(node.actions or {})do
  local id=M.resolve_name(registry,'actions',a.type)
  local r={type=id,actor=a.actor,target=a.target or a.actor,performer=a.performer or a.actor,addon_data=V.copy(a.addon_data)}
  local key=table.concat({id,r.actor,r.target,r.performer},'|');assert(not seen[key],'Duplicate directional action');seen[key]=true
  out.actions[#out.actions+1]=r
  local rating=registry.actions[id].content_rating;if M.ratings[rating]>highest then highest=M.ratings[rating];out.content_rating=rating end
 end
 return out
end
return M

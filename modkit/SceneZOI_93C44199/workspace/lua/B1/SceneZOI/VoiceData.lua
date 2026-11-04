-- Inert, independently contributed voice metadata. No built-in families or contexts.
local V=require('SceneZOI.DataValidation')
local Keys=require('SceneZOI.ExpressionKeys')
local M={}
local function key(v)return Keys.required(v)end
function M.validate(kind,v)
 local common={'schema_version','id','label'}
 if kind=='voice_context'then V.fields(v,common,common)
 elseif kind=='voice_archetype'then
  V.fields(v,{'schema_version','id','label','body','default'}, {'schema_version','id','label','body'})
  assert(v.body=='male'or v.body=='female','Invalid voice body')
  if v.default~=nil then V.boolean(v.default)end
 elseif kind=='voice_set'then
  V.fields(v,{'schema_version','id','label','body','archetype','context','clips','volume','gap','responses'}, {'schema_version','id','label','body','archetype','context','clips'})
  assert(v.body=='male'or v.body=='female','Invalid voice body');key(v.archetype);key(v.context)
  V.number(v.volume or 1,0,1);V.number(v.gap or 0,0,60)
  V.array(v.clips,512);assert(#v.clips>0,'Empty voice set');local seen={}
  for _,path in ipairs(v.clips)do V.asset(path);assert(not seen[path],'Duplicate voice clip');seen[path]=true end
  if v.responses~=nil then
   assert(V.object(v.responses),'Expected named voice response groups');local names={};local count=0
   for id,group in pairs(v.responses)do
    local name=key(id);assert(not names[name],'Conflicting response names');names[name]=true;count=count+1
    V.fields(group,{'clips','volume'},{'clips'});V.array(group.clips,512);assert(#group.clips>0,'Empty voice response')
    if group.volume~=nil then V.number(group.volume,0,1)end
    local clips={};for _,path in ipairs(group.clips)do V.asset(path);assert(not clips[path],'Duplicate response clip');clips[path]=true end
   end
   assert(count<=64,'Too many voice response groups')
  end
 else error('Unknown voice declaration kind')end
 assert(v.schema_version==1,'Unsupported voice schema');key(v.id);V.name(v.label)
 local out=V.copy(v);out.id=key(out.id)
 if out.archetype then out.archetype=key(out.archetype);out.context=key(out.context);out.volume=out.volume or 1;out.gap=out.gap or 0 end
 if out.responses then local normalized={};for id,group in pairs(out.responses)do normalized[key(id)]=group end;out.responses=normalized end
 return out
end
function M.compile(snapshot)
 local result={archetypes={},contexts={},sets={},defaults={},warnings={}}
 local kinds={voice_context='contexts',voice_archetype='archetypes',voice_set='sets'}
 for _,kind in ipairs({'voice_context','voice_archetype','voice_set'})do
  local docs={};for i,d in ipairs(snapshot.by_kind[kind]or {})do docs[i]=d end
  table.sort(docs,function(a,b)return a.source<b.source end)
  for _,doc in ipairs(docs)do
   local ok,value=pcall(M.validate,kind,doc.data)
   if ok then
    local target=result[kinds[kind]];local old=target[value.id]
    if old and not V.equal(old,value)then result.warnings[#result.warnings+1]=doc.source..': conflicting voice ID '..value.id
    else target[value.id]=value end
   else result.warnings[#result.warnings+1]=doc.source..': '..tostring(value)end
  end
 end
 local ids={};for id in pairs(result.archetypes)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do
  local a=result.archetypes[id]
  -- A body has no implicit voice: only a content-declared default opts it in.
  if a.default then
   if result.defaults[a.body]then result.warnings[#result.warnings+1]='Multiple default voice archetypes for '..a.body
   else result.defaults[a.body]=id end
  end
 end
 for id,set in pairs(result.sets)do
  local a=result.archetypes[set.archetype]
  if not a or a.body~=set.body or not result.contexts[set.context]then
   result.warnings[#result.warnings+1]='Unavailable/incompatible voice archetype or context for '..id;result.sets[id]=nil
  end
 end
 return result
end
return M

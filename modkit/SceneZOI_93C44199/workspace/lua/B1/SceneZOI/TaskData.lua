-- Inert task definitions. Every identifier and presentation rule belongs to content.
local V=require('SceneZOI.DataValidation')
local M={}
local function color(v)assert(type(v)=='string'and v:match('^#%x%x%x%x%x%x$'),'Expected #RRGGBB color')end
local function actions(value, allow_set)
 if value~=nil then
  V.array(value,32)
  for _,action in ipairs(value)do
   V.fields(action,{'type','when','clip','sound_set','source','volume','attenuation','max_voices'},{'type','source'})
   assert(action.type=='play_sound','Unsupported task completion action')
   assert((action.clip~=nil)~=(action.sound_set~=nil),'Expected one completion sound clip or set')
   if action.sound_set~=nil then assert(allow_set,'Task definitions require a clip');V.id(action.sound_set) else V.asset(action.clip) end
   if action.when~=nil then
    V.fields(action.when,{'body'})
    if action.when.body~=nil then assert(action.when.body=='male'or action.when.body=='female','Invalid action body filter')end
   end
   V.fields(action.source,{'component','bones'},{'component','bones'})
   V.point({participant='completed',component=action.source.component,bones=action.source.bones},{completed=true})
   if action.volume~=nil then V.number(action.volume,0,1)end
   if action.max_voices~=nil then V.number(action.max_voices,1,16,true)end
   if action.attenuation~=nil then
    V.fields(action.attenuation,{'radius_cm','falloff_cm'})
    if action.attenuation.radius_cm~=nil then V.number(action.attenuation.radius_cm,0,100000)end
    if action.attenuation.falloff_cm~=nil then V.number(action.attenuation.falloff_cm,0,100000)end
   end
  end
 end
end
function M.validate(v)
 V.fields(v,{'schema_version','id','label','maximum','initial','decay','completion_event','display','metadata','on_completion'},{'schema_version','id','label','maximum'})
 assert(v.schema_version==1,'Unsupported task schema');V.id(v.id);V.name(v.label)
 if v.completion_event~=nil then V.id(v.completion_event)end
 V.number(v.maximum,0.001,1000000000);V.number(v.initial==nil and 0 or v.initial,0,v.maximum);V.number(v.decay==nil and 0 or v.decay,0,1000000)
 if v.metadata~=nil then assert(V.object(v.metadata),'Expected task metadata')end
 if v.display~=nil then
  V.fields(v.display,{'visible','color','track_color','text_color','body_colors'})
  if v.display.visible~=nil then V.boolean(v.display.visible)end
  for _,k in ipairs({'color','track_color','text_color'})do if v.display[k]~=nil then color(v.display[k])end end
  if v.display.body_colors~=nil then
   V.fields(v.display.body_colors,{'male','female'})
   for _,c in pairs(v.display.body_colors)do color(c)end
  end
 end
 actions(v.on_completion)
 local out=V.copy(v);out.initial=out.initial or 0;out.decay=out.decay or 0
 return out
end
function M.directives(value,roles)
 assert(V.object(value or {}),'Expected participant task map')
 for role,tasks in pairs(value or {})do
  assert(roles[role],'Unbound task participant');assert(V.object(tasks),'Expected task map')
  for id,spec in pairs(tasks)do
   V.id(id);V.fields(spec,{'rate','cap_percent'},{'rate'});V.number(spec.rate,-1000000,1000000)
   V.number(spec.cap_percent==nil and 100 or spec.cap_percent,0,100)
  end
 end
end
function M.scene(node)
 M.directives(node.tasks,node.participants)
 assert(V.object(node.task_providers or {}),'Expected task provider map')
 for id,owner in pairs(node.task_providers or {})do V.id(id);V.id(owner)end
 assert(V.object(node.task_completion_sounds or {}),'Expected task completion sound map')
 for role,tasks in pairs(node.task_completion_sounds or {})do
  assert(node.participants[role] and V.object(tasks),'Unbound completion sound role')
  for id,value in pairs(tasks)do V.id(id);actions(value,true)end
 end
end

-- A shared definition has one state key. Distinct definitions retain separate progress.
function M.compile(source)
 local result={definitions={},variants={},by_owner={},defaults={},providers={},conflicts={},warnings={}}
 local docs,by_id={},{}
 for i,doc in ipairs(source.by_kind.scene_task or {})do docs[i]=doc end
 table.sort(docs,function(a,b)return a.source<b.source end)
 for _,doc in ipairs(docs)do
  local ok,value=pcall(M.validate,doc.data)
  if ok then
   local rows=by_id[value.id] or {};by_id[value.id]=rows
   local owner=doc.owner or ''
   if rows[owner] and not V.equal(rows[owner],value)then
    result.warnings[#result.warnings+1]=doc.source..': conflicting task ID '..value.id..' within '..owner
   else rows[owner]=value end
  else result.warnings[#result.warnings+1]=doc.source..': '..tostring(value)end
 end
 local ids={};for id in pairs(by_id)do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids)do
  local rows=by_id[id];local owners,groups={},{}
  for owner in pairs(rows)do owners[#owners+1]=owner end;table.sort(owners)
  for _,owner in ipairs(owners)do
   local definition=rows[owner];local group
   for _,candidate in ipairs(groups)do if V.equal(candidate.definition,definition)then group=candidate;break end end
   if not group then group={owner=owner,definition=definition,owners={}};groups[#groups+1]=group end
   group.owners[#group.owners+1]=owner
  end
  local keys={}
  for _,group in ipairs(groups)do
   local key=#groups==1 and id or group.owner..':'..id
   result.variants[key]=group.definition
   for _,owner in ipairs(group.owners)do
    result.by_owner[owner]=result.by_owner[owner] or {}
    result.by_owner[owner][id]=key;keys[owner]=key
   end
  end
  -- Match API discovery and keep the fallback independent of load order.
  local fallback_owner=keys.scenezoi and 'scenezoi' or owners[1]
  result.defaults[id]=keys[fallback_owner]
  result.definitions[id]=result.variants[result.defaults[id]]
  result.providers[id]=keys
  if #groups>1 then
   result.conflicts[#result.conflicts+1]={id=id,owners=owners,fallback=fallback_owner}
   result.warnings[#result.warnings+1]='Conflicting task ID '..id..' from '..table.concat(owners,', ')..' (fallback: '..fallback_owner..')'
  end
 end
 return result
end

function M.resolve(registry,node,id)
 if not registry.variants then return registry.definitions[id] and id or nil end
 local providers=registry.providers[id]
 if not providers then return nil,'task_not_found' end
 local owner=node and node._owner
 local key=providers[owner] or providers.scenezoi
 if key then return key end
 local requested=node and (node.task_providers or {})[id]
 if requested then
  if providers[requested] then return providers[requested] end
  return nil,'task_provider_unavailable'
 end
 return registry.defaults[id]
end

function M.can_finish(directive)
 return directive and directive.rate>0 and (directive.cap_percent or 100)>=100
end

function M.directive(node,role,id,key)
 local directive=((node.tasks or {})[role] or {})[id]
 if directive and (not node._task_keys or node._task_keys[id]==(key or id))then return directive end
end
return M

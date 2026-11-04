-- Inert task definitions. Every identifier and presentation rule belongs to content.
local V=require('SceneZOI.DataValidation')
local M={}
local function color(v)assert(type(v)=='string'and v:match('^#%x%x%x%x%x%x$'),'Expected #RRGGBB color')end
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
 if v.on_completion~=nil then
  V.array(v.on_completion,32)
  for _,action in ipairs(v.on_completion)do
   V.fields(action,{'type','when','clip','source','volume','attenuation','max_voices'},{'type','clip','source'})
   assert(action.type=='play_sound','Unsupported task completion action')
   V.asset(action.clip)
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
function M.compile(source)
 local result={definitions={},warnings={}}
 local docs={};for i,doc in ipairs(source.by_kind.scene_task or {})do docs[i]=doc end
 table.sort(docs,function(a,b)return a.source<b.source end)
 for _,doc in ipairs(docs)do
  local ok,value=pcall(M.validate,doc.data)
  if ok then
   local old=result.definitions[value.id]
   if old and not V.equal(old,value)then result.warnings[#result.warnings+1]=doc.source..': conflicting task ID '..value.id
   else result.definitions[value.id]=value end
  else result.warnings[#result.warnings+1]=doc.source..': '..tostring(value)end
 end
 return result
end
return M

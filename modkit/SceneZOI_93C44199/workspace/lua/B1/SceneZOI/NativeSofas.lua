-- Classification uses native Object metadata, never translated names, mesh
-- filenames or a model whitelist. Blueprint slot data supplies the topology.
local J=require('SceneZOI.Json')
local Layout=require('SceneZOI.SofaLayout')
local M={cache={},models={},reported={},queue={},cursor=1,next_scan=0}
local function has(tags,wanted)for _,tag in ipairs(tags or {})do if tostring(tag)==wanted then return true end end;return false end
function M.is_sofa(row)
 return type(row)=='table'and(has(row.objectTags,'Object_Sofa')or row.filterCategory=='Sofa'or row.objectCategory=='Sofa')
end
local function quaternion_yaw(q)
 assert(math.abs(q.X)<.0001 and math.abs(q.Y)<.0001,'Tilted sofa sitting markers are unsupported')
 return math.deg(math.atan(2*(q.W*q.Z+q.X*q.Y),1-2*(q.Y*q.Y+q.Z*q.Z)))
end
local function sits(s)
 local d=s.SlotComponentData
 if d.SlotType~=inzoi.EB1SlotType.Interaction then return end
 local age=d.InteractionSlot.BodyAge
 if age~=inzoi.EB1BodyAgeType.Default and age~=inzoi.EB1BodyAgeType.Adult then return end
 local tags={};local sitting=false
 for _,tag in ipairs(d.InteractionSlot.EnableOnlyInteractionTags)do
  tag=tostring(tag);tags[#tags+1]=tag
  if tag=='Sit'or tag:sub(1,4)=='Sit_'then sitting=true end
 end
 return sitting and tags or nil
end
local function model_row(model)
 local cached=M.models[model]
 if cached and cached.retry>os.time()then return cached.row end
 local ok,_,raw=inzoi.cli.execute('data.table_get alias=Object row='..J.encode(model))
 if not ok or not raw then return nil end
 local row=J.decode(raw);M.models[model]={row=row,retry=os.time()+30}
 return row
end
local function report(id,model,code,profile)
 if M.reported[id]==code then return end;M.reported[id]=code
 pcall(function()require('SceneZOI.Diagnostics').record(profile and'furniture_discovered'or'furniture_discovery_warning',
  {furniture_id=id,object_id=model,profile_source='native_sofa_slots',code=code,
   sitting_spots=profile and #profile.sitting_spots or nil,seat_pairs=profile and #profile.seat_pairs or nil})end)
end
---@param actor AB1GameObject
local function inspect(id,actor,model)
 local native=actor.RuntimeSlotInfos
 if not native or native:Num()<2 then return end
 local known=M.models[model]
 if known and known.retry>os.time()and not M.is_sofa(known.row)then return end
 local selected,normal={},0
 for _,slot in ipairs(native)do
  local tags=sits(slot)
  if tags then selected[#selected+1]={slot=slot,tags=tags};if has(tags,'Sit')then normal=normal+1 end end
 end
 if normal<2 then return end
 local row=model_row(model)
 if not row then return nil,'object_metadata_pending'end
 if not M.is_sofa(row)then return end
 local components={}
 for _,component in ipairs(actor:K2_GetComponentsByClass(UE.USceneComponent:StaticClass()))do components[component:GetName()]=component end
 local mathlib=UE.UKismetMathLibrary;local inverse=mathlib.InvertTransform(actor:GetTransform());local rows={}
 for _,entry in ipairs(selected)do
  local s=entry.slot;local name=tostring(s.ParentComponentName)
  assert(tostring(s.ParentSlotName)=='None'and tostring(s.ParentSocketName)=='None','Nested sofa slots need an explicit furniture profile')
  local parent=components[name];assert(parent or name=='None','Sofa slot parent is unavailable')
  local world=parent and parent:K2_GetComponentToWorld()or actor:GetTransform()
  local local_transform=mathlib.ComposeTransforms(mathlib.ComposeTransforms(s.RelativeTransform,world),inverse)
  local p=local_transform.Translation
  rows[#rows+1]={component_name=tostring(s.ComponentName),slot_name=tostring(s.SlotName),tags=entry.tags,
   position={x=p.X,y=p.Y,z=p.Z},yaw_degrees=quaternion_yaw(local_transform.Rotation)}
 end
 return Layout.build(model,id,rows)
end
function M.profile(id,actor)
 local model=tostring(actor.ObjectDataTableId);local old=M.cache[id];local now=os.time()
 if old and old.actor==actor and old.model==model and now<old.until_time then return old.profile end
 local ok,profile,reason=pcall(inspect,id,actor,model)
 if not ok then reason=tostring(profile);profile=nil end
 local native=actor.RuntimeSlotInfos
 M.cache[id]={actor=actor,model=model,profile=profile,until_time=now+2,
  slot_count=native and native:Num()or 0,background_retry=now+60}
 local known=M.models[model]
 if profile or(reason and((known and M.is_sofa(known.row))or reason=='object_metadata_pending'))then
  report(id,model,profile and'automatic_sofa_layout'or reason,profile)
 end
 return profile
end
function M.peek(id,actor)
 local cached=M.cache[id]
 return cached and cached.actor==actor and cached.model==tostring(actor.ObjectDataTableId)and cached.profile or nil
end
function M.scan_due()return M.cursor>#M.queue and os.time()>=M.next_scan end
function M.begin_scan(rows)
 M.queue=rows;M.cursor=1;M.next_scan=os.time()+10
end
function M.tick()
 -- Native property reads across a loaded city can be costly. Bound discovery
 -- per render tick; explicit picker/API requests inspect their target directly.
 local began=os.clock();local count=0
 while M.cursor<=#M.queue and count<2 and os.clock()-began<.001 do
  local row=M.queue[M.cursor];M.cursor=M.cursor+1;count=count+1
  pcall(function()
   local old=M.cache[row.id]
   if old and not old.profile and old.actor==row.actor and old.model==tostring(row.actor.ObjectDataTableId)and os.time()<old.background_retry then
    local native=row.actor.RuntimeSlotInfos
    if(native and native:Num()or 0)==old.slot_count then return end
   end
   M.profile(row.id,row.actor)
  end)
 end
 if count>0 and M.cursor>#M.queue then M.next_scan=os.time()+10 end
end
function M.prune(alive)
 for id in pairs(M.cache)do if not alive[id]then M.cache[id]=nil;M.reported[id]=nil end end
 local used={};for _,row in pairs(M.cache)do used[row.model]=true end
 for model in pairs(M.models)do if not used[model]then M.models[model]=nil end end
end
return M

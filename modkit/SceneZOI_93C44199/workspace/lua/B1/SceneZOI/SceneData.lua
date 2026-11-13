-- Validate contributions before linking the graph. Bad files never execute code.
local V=require('SceneZOI.DataValidation')
local Keys=require('SceneZOI.ExpressionKeys')
local M={}
local function group(v)
 V.fields(v,{'clips'},{'clips'});V.array(v.clips,512);assert(#v.clips>0,'Empty sound clip group')
 local seen={};for _,path in ipairs(v.clips)do V.asset(path);assert(not seen[path],'Duplicate sound clip');seen[path]=true end
end
local function sounds(sets,owner)
 assert(V.object(sets),'Expected sound sets')
 for id,spec in pairs(sets)do
  V.id(id);assert(id:sub(1,#owner+1)==owner..'.','Sound set namespace mismatch')
  V.fields(spec,{'default','variants'});assert(spec.default or(spec.variants and #spec.variants>0),'Empty sound set')
  if spec.default then group(spec.default)end
  V.array(spec.variants or {},16);local seen={}
  for _,variant in ipairs(spec.variants or {})do
   V.fields(variant,{'scene_speed','clips'},{'scene_speed','clips'})
   local speed=variant.scene_speed;assert((speed==0.5 or speed==1 or speed==1.5 or speed==2)and not seen[speed],'Unsupported or duplicate sound variant')
   seen[speed]=true;group({clips=variant.clips})
  end
 end
end
local function emitter(v,roles)
 V.fields(v,{'mode','owner','sound_set','source','distance','volume','gap','avoid_repeat','max_voices','attenuation'},{'mode','owner','sound_set','source'})
 assert(v.mode=='bone_distance'or v.mode=='continuous','Unsupported sound mode');assert(roles[v.owner],'Unbound sound owner');V.id(v.sound_set)
 V.array(v.source,8);assert(#v.source>0,'Empty sound source');for _,p in ipairs(v.source)do V.point(p,roles)end
 V.number(v.volume or 1,0,1);V.number(v.gap or 0,0,60);V.number(v.max_voices or 4,1,16,true)
 if v.avoid_repeat~=nil then V.boolean(v.avoid_repeat)end
 local a=v.attenuation or {};V.fields(a,{'radius_cm','falloff_cm'});V.number(a.radius_cm or 100,0,100000);V.number(a.falloff_cm or 900,0.001,100000)
 if v.mode=='bone_distance'then
  local d=v.distance;V.fields(d,{'from','to','max_distance_cm','min_delta_cm','cooldown','sample_interval'},{'from','to'})
  V.point(d.from,roles);V.point(d.to,roles);V.number(d.max_distance_cm or 30,0.001,100000)
  V.number(d.min_delta_cm or 0.1,0.000001,1000);V.number(d.cooldown or 0.15,0,60);V.number(d.sample_interval or 1/60,0.001,1)
 else assert(v.distance==nil,'Continuous sound has a distance detector')end
end
local function attachment(v,roles)
 V.fields(v,{'participant','component','socket','reference_bone','mesh','animation','body_profile','material_profile','when_undressed','retain_for_session','retained_tracks'},{'participant','socket','reference_bone','mesh'})
 assert(roles[v.participant],'Unbound attachment owner');if v.component~=nil then assert(v.component=='head'or v.component=='body','Invalid attachment component')end;V.name(v.socket);V.name(v.reference_bone);V.asset(v.mesh)
 if v.animation then V.asset(v.animation)end
 if v.body_profile then V.id(v.body_profile);assert(v.component~='head','Body-region replacement requires body attachment')end
 if v.material_profile then V.id(v.material_profile);assert(v.body_profile,'Material matching requires a source-region profile')end
 for _,field in ipairs({'when_undressed','retain_for_session'})do if v[field]~=nil then V.boolean(v[field])end end
 if v.retained_tracks then
  assert(v.retain_for_session and V.object(v.retained_tracks),'Invalid retained track map')
  for id,path in pairs(v.retained_tracks)do V.id(id);V.asset(path)end
 end
end
local function edge(v)
 V.fields(v,{'id','label','target'},{'id','target'});V.id(v.id);V.id(v.target)
 if v.label~=nil and v.label~=false then assert(type(v.label)=='string'and #v.label<=400 and not v.label:find('[%z\1-\31]'),'Invalid edge label')end
end
-- Track keys depend on the declared roster, so use a dedicated check.
function M.node(v,owner)
 local tracks=v.tracks;local placeholder={}
 for role in pairs(v.participants or {})do placeholder[#placeholder+1]=role end
 -- Run the remaining validation without treating dynamic track keys as schema fields.
 V.fields(v,{'id','label','kind','destination','hub','starting_hub','duration','fps','participants','anchor_participant','tracks','hide_if_tracks_missing','outfits','attachments','gaze','expressions','voices','tasks','task_completion_routes','movement_timing','completion_responses','task_completion_voices','sfx','navigation','furniture','tags','participant_tags','actions','addon_data','participant_addon_data'},{'id','label','kind','duration','fps','participants','anchor_participant','tracks','navigation'})
 require('SceneZOI.FurnitureData').scene(v.furniture)
 require('SceneZOI.MetadataShape').validate(v)
 V.id(v.id);assert(v.id:sub(1,#owner+1)==owner..'.','Node namespace mismatch');V.name(v.label);assert(v.kind=='loop'or v.kind=='transition','Unsupported scene kind')
 if v.kind=='transition'then
  V.id(v.destination);assert(v.destination~=v.id,'Transition cannot target itself')
  assert(v.starting_hub~=true and v.hub==nil,'Transitions cannot be starting scenes or hubs')
  V.array(v.navigation,0)
 else assert(v.destination==nil,'Loop scene cannot declare a transition destination')end
 V.number(v.duration,0.000001,86400);V.number(v.fps,0.000001,240);V.roles(v.participants)
 if v.hub then V.id(v.hub)end;if v.starting_hub~=nil then V.boolean(v.starting_hub)end
 assert(v.participants[v.anchor_participant],'Unbound scene anchor')
 V.fields(tracks,placeholder,placeholder);for _,path in pairs(tracks)do V.asset(path)end
 if v.hide_if_tracks_missing~=nil then V.boolean(v.hide_if_tracks_missing)end
 V.outfits(v.outfits or {},v.participants)
 assert(V.object(v.attachments or {}),'Expected named attachments');local profiled={}
 for id,spec in pairs(v.attachments or {})do
  V.id(id);attachment(spec,v.participants)
  if spec.body_profile then assert(not profiled[spec.participant],'Multiple region replacement owners');profiled[spec.participant]=true end
 end
 assert(V.object(v.gaze or {}),'Expected gaze settings');for role,p in pairs(v.gaze or {})do assert(v.participants[role],'Unbound gaze owner');V.point(p,v.participants)end
 assert(V.object(v.expressions or {}),'Expected expression settings')
 for role,spec in pairs(v.expressions or {})do
  assert(v.participants[role],'Unbound expression owner');V.fields(spec,{'context','facial_pose'});assert(spec.context or spec.facial_pose,'Empty expression instruction')
  if spec.context then assert(Keys.normalize(spec.context),'Invalid expression context')end
  if spec.facial_pose~=nil then V.id(spec.facial_pose)end
 end
 assert(V.object(v.voices or {}),'Expected voice settings')
 for role,spec in pairs(v.voices or {})do
  assert(v.participants[role],'Unbound voice owner');V.fields(spec,{'context'},{'context'});assert(Keys.normalize(spec.context),'Invalid voice context')
 end
 require('SceneZOI.VoiceResponseData').validate(v.task_completion_voices,v.participants)
 require('SceneZOI.CompletionData').timing(v.movement_timing,v.duration)
 require('SceneZOI.CompletionData').responses(v.completion_responses,v.participants,v.kind)
 require('SceneZOI.TaskData').directives(v.tasks,v.participants)
 require('SceneZOI.TaskRoutes').validate(v.task_completion_routes,v.participants)
 assert(V.object(v.sfx or {}),'Expected named sound emitters');for id,spec in pairs(v.sfx or {})do V.id(id);emitter(spec,v.participants)end
 V.array(v.navigation,512);local ids={}
 for _,link in ipairs(v.navigation)do edge(link);assert(not ids[link.id],'Duplicate navigation ID');ids[link.id]=true end
 return V.copy(v)
end
local function contribution(v)
 V.fields(v,{'schema_version','id','nodes','extensions','sound_sets'},{'schema_version','id','nodes','extensions'})
 assert(v.schema_version==3,'Unsupported scene pack version');V.id(v.id);V.array(v.nodes,512);V.array(v.extensions,512)
 sounds(v.sound_sets or {},v.id);local result={id=v.id,nodes={},extensions=V.copy(v.extensions),sound_sets=V.copy(v.sound_sets or {})}
 for _,node in ipairs(v.nodes)do local value=M.node(node,v.id);assert(not result.nodes[node.id],'Duplicate node ID');result.nodes[node.id]=value end
 for _,link in ipairs(v.extensions)do
  V.fields(link,{'hub','id','label','target'},{'hub','id','target'});V.id(link.hub)
  assert(link.id:sub(1,#v.id+1)==v.id..'.','Extension namespace mismatch');local test=V.copy(link);test.hub=nil;edge(test)
 end
 return result
end
function M.compile(documents,check_tracks)
 local result={nodes={},sound_sets={},warnings={}};local links={}
 for _,doc in ipairs(documents)do
  local ok,value=pcall(contribution,doc.data)
  if ok then
   local conflict
   for id,node in pairs(value.nodes)do if result.nodes[id]and not V.equal(result.nodes[id],node)then conflict='Conflicting node ID: '..id end end
   for id,spec in pairs(value.sound_sets)do if result.sound_sets[id]and not V.equal(result.sound_sets[id],spec)then conflict='Conflicting sound ID: '..id end end
   if conflict then result.warnings[#result.warnings+1]=doc.source..': '..conflict
   else
    for id,node in pairs(value.nodes)do result.nodes[id]=node end
    for id,spec in pairs(value.sound_sets)do result.sound_sets[id]=spec end
    for _,link in ipairs(value.extensions)do links[#links+1]=link end
   end
  else result.warnings[#result.warnings+1]=doc.source..': '..tostring(value)end
 end
 if check_tracks then
  for id,node in pairs(result.nodes)do
   if node.hide_if_tracks_missing then
    local ok,reason=pcall(check_tracks,node)
    if not ok then
     result.nodes[id]=nil
     result.warnings[#result.warnings+1]=id..': '..tostring(reason)
    end
   end
  end
 end
 for _,link in ipairs(links)do
  local node=result.nodes[link.hub]
  if node and node.hub then local added=V.copy(link);added.hub=nil;node.navigation[#node.navigation+1]=added
  else result.warnings[#result.warnings+1]='Unavailable extension hub: '..link.hub end
 end
 -- Validate automatic paths before exposing incoming links. Isolate invalid transitions.
 local state={}
 local function reachable(id)
  local node=result.nodes[id]
  if not node then return false end
  if node.kind~='transition'then return true end
  if state[id]~=nil then return state[id]==true end
  state[id]='visiting'
  local target=result.nodes[node.destination]
  local valid=target and V.equal(target.participants,node.participants)and V.equal(target.furniture,node.furniture)and reachable(node.destination)or false
  state[id]=valid;return valid
 end
 local invalid={}
 for id,node in pairs(result.nodes)do if node.kind=='transition'and not reachable(id)then invalid[#invalid+1]=id end end
 for _,id in ipairs(invalid)do
  result.warnings[#result.warnings+1]='Unavailable, incompatible or cyclic transition destination from '..id
  result.nodes[id]=nil
 end
 require('SceneZOI.TaskRoutes').link(result.nodes,result.warnings)
 for id,node in pairs(result.nodes)do
  local navigation,seen={},{}
  for _,link in ipairs(node.navigation)do
   local target=result.nodes[link.target]
   if not seen[link.id]and target and V.equal(target.participants,node.participants)and V.equal(target.furniture,node.furniture)then
    local value=V.copy(link);if not value.label or not value.label:match('%S')then value.label=target.label;value._label_from_target=true end
    navigation[#navigation+1]=value;seen[link.id]=true
   else result.warnings[#result.warnings+1]='Unavailable or incompatible navigation from '..id..': '..link.id end
  end
  node.navigation=navigation
  for _,spec in pairs(node.expressions or {})do spec.context=Keys.normalize(spec.context)end
  for _,spec in pairs(node.voices or {})do spec.context=Keys.normalize(spec.context)end
  for key,spec in pairs(node.sfx or {})do
   if not result.sound_sets[spec.sound_set]then result.warnings[#result.warnings+1]='Unavailable sound set: '..spec.sound_set;node.sfx[key]=nil end
  end
 end
 return result
end
function M.simulation(v)
 V.fields(v,{'id','participants','outfits','cleanup_layers'},{'id','participants'})
 V.id(v.id);V.roles(v.participants);V.outfits(v.outfits or {},v.participants)
 if v.cleanup_layers then V.array(v.cleanup_layers,16);for _,name in ipairs(v.cleanup_layers)do V.name(name)end end
 return v
end
return M

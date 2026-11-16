-- Session-owned numerical tasks; no native animation, content semantics or save-file state.
local V=require('SceneZOI.DataValidation')
local Protocol=require('SceneZOI.Protocol')
local Control=require('SceneZOI.AddonControl')
local Settings=require('SceneZOI.Settings')
local Plan=require('SceneZOI.Plan')
local Data=require('SceneZOI.TaskData')
local function appearance_body(p,session)return p.body or p.expression_body or((session.node.participants or {})[p.role]or {}).body end
local M={}
local function sorted(t)local ids={};for id in pairs(t)do ids[#ids+1]=id end;table.sort(ids);return ids end
function M.new(definitions,participants,registry,node)
 local public=registry and registry.definitions or definitions
 local result={registry=registry,definitions=V.copy(definitions),task_ids=sorted(public),last_keys={},
  participants={},warnings={},warned={}}
 for _,p in ipairs(participants)do
  local entries={}
  for id,definition in pairs(public)do entries[id]={value=definition.initial or 0,completions=0}end
  result.participants[p.id]=entries
 end
 if node then M.enter_node(result,node)
 elseif not registry then
  for _,id in ipairs(result.task_ids)do result.last_keys[id]=id end
 end
 return result
end
function M.key(state,node,id)
 if state.registry then return Data.resolve(state.registry,node,id) end
 if state.definitions[id]then return id end
 return nil,'task_not_found'
end
-- Keep one meter per participant and task ID. Its units follow the last
-- resolved definition, even while a scene with a missing provider hides it.
function M.enter_node(state,node)
 for _,id in ipairs(state.task_ids)do
  local key=M.key(state,node,id)
  local previous=state.last_keys[id]
  local definition=key and state.definitions[key]
  for _,entries in pairs(state.participants)do
   local entry=entries[id]
   if previous then
    local maximum=state.definitions[previous].maximum
    if entry.value>=maximum then
     entry.pending_handoff=true
     if definition then entry.value=definition.maximum end
    elseif definition and key~=previous then
     local limit=definition.maximum
     local value=(entry.value/maximum)*limit
     -- A below-full meter can round up when the destination uses different units.
     entry.value=value<limit and value or limit*(1-2^-52)
    end
   elseif definition then
    entry.value=definition.initial or 0
   end
  end
  if key then state.last_keys[id]=key end
 end
end
function M.public_definitions(state,session)
 local definitions={}
 for _,id in ipairs(state.task_ids)do
  local key=M.key(state,session.node,id)
  if key then definitions[id]=state.definitions[key]end
 end
 return V.copy(definitions)
end
function M.progress(state,session)
 local progress={}
 for participant,entries in pairs(state.participants)do
  progress[participant]={}
  for id,entry in pairs(entries)do
   if M.key(state,session.node,id)then
    progress[participant][id]={value=entry.value,completions=entry.completions}
   end
  end
 end
 return progress
end
function M.update(state,session,dt,emit)
 if session.node.kind=='transition' or session.preparing or session.stopping or session.ended or type(dt)~='number'or dt~=dt or dt<=0 or dt==math.huge then return end
 local directives=session.node.tasks or {}
 for role,tasks in pairs(directives)do for id in pairs(tasks)do
  local key=session.node.id..':'..role..':'..id
  if not M.key(state,session.node,id)and not state.warned[key]then
   state.warned[key]=true;state.warnings[#state.warnings+1]='Unavailable task '..id..' for '..role..' in '..session.node.id
   print('[SceneZOI] '..state.warnings[#state.warnings])
  end
 end end
 for _,p in ipairs(session.participants)do
  for _,id in ipairs(state.task_ids)do
   local key=M.key(state,session.node,id)
   if key then
    local definition=state.definitions[key]
    local entry=state.participants[p.id][id]
    local directive=Data.directive(session.node,p.role,id,key)
    -- Omission lets the meter decay. An authored zero holds its value.
    local rate=directive and directive.rate or -(definition.decay or 0)
    local multiplier,held=Control.task(session,p.id,id)
    if rate>0 then multiplier=multiplier*Settings.task_multiplier(appearance_body(p,session))*Plan.rate_factor(session)end
    if rate>0 and Plan.frozen(session,p.id,id)then multiplier=0 end
    rate=rate*multiplier
    local maximum=definition.maximum
    if entry.value<maximum then entry.pending_handoff=nil end
    if entry.value<maximum and rate>0 then
     local cap=maximum*(directive.cap_percent or 100)/100
     if entry.value<cap then entry.value=math.min(cap,entry.value+rate*dt)end
    elseif entry.value<maximum and rate<0 then entry.value=math.max(0,entry.value+rate*dt)end
    entry.value=math.min(maximum,math.max(0,entry.value))
    if entry.value>=maximum and not held and (not entry.pending_handoff or Data.can_finish(directive))then
     entry.completions=entry.completions+1
     local task={id=id,label=definition.label,value=maximum,maximum=maximum,percent=100,
      completed=true,completion_index=entry.completions,completion_event=definition.completion_event,
      metadata=V.copy(definition.metadata)}
     -- Commit reset before observers can run. Overshoot is intentionally discarded.
     entry.value,entry.pending_handoff=0,nil
     emit({task=task,task_key=key,participant_id=p.id,participant_role=p.role})
    end
   end
  end
 end
end
function M.snapshot(state,session)
 local rows={}
 for _,p in ipairs(session.participants)do
  for _,id in ipairs(state.task_ids)do
   local key=M.key(state,session.node,id)
   if key then
    local d=state.definitions[key];local e=state.participants[p.id][id];local display=d.display or {}
    local directive=Data.directive(session.node,p.role,id,key)
    if display.visible~=false and(e.value>0 or (directive~=nil and directive.rate>=0))then
     local body=appearance_body(p,session)
     rows[#rows+1]={participant_id=p.id,participant_name=(p.outfit_name and Protocol.decode(p.outfit_name)) or p.task_name or p.id,participant_role=p.role,
      task_id=id,label=require('SceneZOI.Localization').label('scene_task',id,d.label),value=e.value,maximum=d.maximum,percent=e.value/d.maximum*100,
      completions=e.completions,color=(display.body_colors or {})[body]or display.color or '#3185c3',
      track_color=display.track_color or '#bfbfbf',text_color=display.text_color or '#222222'}
    end
   end
  end
 end
 return rows
end
function M.inspect(state,session)
 local rows=require('SceneZOI.Json').array({})
 for _,p in ipairs(session.participants)do for _,id in ipairs(state.task_ids)do
  local key=M.key(state,session.node,id)
  if key then
   local d=state.definitions[key];local e=state.participants[p.id][id]
   local directive=Data.directive(session.node,p.role,id,key)
   local multiplier,held=Control.task(session,p.id,id)
   local base_rate=directive and directive.rate or -(d.decay or 0)
   local player=Settings.task_multiplier(appearance_body(p,session))
   local plan_factor=base_rate>0 and Plan.rate_factor(session)or 1
   if base_rate>0 and Plan.frozen(session,p.id,id)then plan_factor=0 end
   local combined=multiplier*(base_rate>0 and player or 1)*plan_factor
   rows[#rows+1]={participant_id=p.id,participant_role=p.role,task_id=id,label=d.label,value=e.value,
    maximum=d.maximum,percent=100*e.value/d.maximum,completions=e.completions,
    base_rate=base_rate,rate_multiplier=combined,player_rate_multiplier=player,addon_rate_multiplier=multiplier,plan_rate_multiplier=plan_factor,effective_rate=base_rate*combined,completion_hold=held}
  end
 end end
 return rows
end
return M

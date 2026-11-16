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
function M.new(definitions,participants,registry)
 local result={registry=registry,definitions=V.copy(definitions),definition_ids=sorted(definitions),participants={},warnings={},warned={}}
 for _,p in ipairs(participants)do
  local values={};for id,definition in pairs(definitions)do values[id]={value=definition.initial or 0,completions=0}end
  result.participants[p.id]=values
 end
 return result
end
function M.key(state,node,id)
 if state.registry then return Data.resolve(state.registry,node,id) end
 if state.definitions[id]then return id end
 return nil,'task_not_found'
end
function M.public_definitions(state,session)
 local definitions={}
 for key,definition in pairs(state.definitions)do
  local id=definition.id or key
  if M.key(state,session.node,id)==key then definitions[id]=definition end
 end
 return V.copy(definitions)
end
function M.progress(state,session)
 local progress={}
 for participant,entries in pairs(state.participants)do
  progress[participant]={}
  for key,entry in pairs(entries)do
   local id=state.definitions[key].id or key
   if M.key(state,session.node,id)==key then progress[participant][id]=V.copy(entry) end
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
  for _,id in ipairs(state.definition_ids)do
   local definition=state.definitions[id];local entry=state.participants[p.id][id]
   local task_id=definition.id or id
   local active=M.key(state,session.node,task_id)==id
   local directive=active and Data.directive(session.node,p.role,task_id,id)
   -- Omission lets the meter decay. An authored zero holds its value.
   local rate=directive and directive.rate or -(definition.decay or 0)
   local multiplier,held=Control.task(session,p.id,id)
   if rate>0 then multiplier=multiplier*Settings.task_multiplier(appearance_body(p,session))*Plan.rate_factor(session)end
   if rate>0 and Plan.frozen(session,p.id,id)then multiplier=0 end
   rate=rate*multiplier
   local maximum=definition.maximum
   if entry.value<maximum and rate>0 then
    local cap=maximum*(directive.cap_percent or 100)/100
    if entry.value<cap then entry.value=math.min(cap,entry.value+rate*dt)end
   elseif entry.value<maximum and rate<0 then entry.value=math.max(0,entry.value+rate*dt)end
   entry.value=math.min(maximum,math.max(0,entry.value))
   if active and entry.value>=maximum and not held then
    entry.completions=entry.completions+1
    local task={id=task_id,label=definition.label,value=maximum,maximum=maximum,percent=100,
     completed=true,completion_index=entry.completions,completion_event=definition.completion_event,
     metadata=V.copy(definition.metadata)}
    -- Commit reset before observers can run. Overshoot is intentionally discarded.
    entry.value=0
    emit({task=task,task_key=id,participant_id=p.id,participant_role=p.role})
   end
  end
 end
end
function M.snapshot(state,session)
 local rows={}
 for _,p in ipairs(session.participants)do
  for _,id in ipairs(state.definition_ids)do
   local d=state.definitions[id];local e=state.participants[p.id][id];local display=d.display or {}
   local task_id=d.id or id
  local directive=Data.directive(session.node,p.role,task_id,id)
   if M.key(state,session.node,task_id)==id and display.visible~=false and(e.value>0 or (directive~=nil and directive.rate>=0))then
    local body=p.body or p.expression_body or((session.node.participants or {})[p.role]or {}).body
    rows[#rows+1]={participant_id=p.id,participant_name=(p.outfit_name and Protocol.decode(p.outfit_name)) or p.task_name or p.id,participant_role=p.role,
     task_id=task_id,label=require('SceneZOI.Localization').label('scene_task',task_id,d.label),value=e.value,maximum=d.maximum,percent=e.value/d.maximum*100,
     completions=e.completions,color=(display.body_colors or {})[body]or display.color or '#3185c3',
     track_color=display.track_color or '#bfbfbf',text_color=display.text_color or '#222222'}
   end
  end
 end
 return rows
end
function M.inspect(state,session)
 local rows=require('SceneZOI.Json').array({})
 for _,p in ipairs(session.participants)do for _,id in ipairs(state.definition_ids)do
  local d=state.definitions[id];local e=state.participants[p.id][id]
  local task_id=d.id or id
  if M.key(state,session.node,task_id)==id then
  local directive=Data.directive(session.node,p.role,task_id,id)
  local multiplier,held=Control.task(session,p.id,id)
  local base_rate=directive and directive.rate or -(d.decay or 0)
  local player=Settings.task_multiplier(appearance_body(p,session))
  local plan_factor=base_rate>0 and Plan.rate_factor(session)or 1
  if base_rate>0 and Plan.frozen(session,p.id,id)then plan_factor=0 end
  local combined=multiplier*(base_rate>0 and player or 1)*plan_factor
  rows[#rows+1]={participant_id=p.id,participant_role=p.role,task_id=task_id,label=d.label,value=e.value,
   maximum=d.maximum,percent=100*e.value/d.maximum,completions=e.completions,
   base_rate=base_rate,rate_multiplier=combined,player_rate_multiplier=player,addon_rate_multiplier=multiplier,plan_rate_multiplier=plan_factor,effective_rate=base_rate*combined,completion_hold=held}
  end
 end end
 return rows
end
return M

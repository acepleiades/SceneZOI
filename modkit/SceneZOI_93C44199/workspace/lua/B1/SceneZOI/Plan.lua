-- Autonomous plans: what an add-on asked an automatic scene to achieve and how it ends.
-- Owns no playback. Runtime asks tick() what to do next and carries it out.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local C=require('SceneZOI.Config')
local Control=require('SceneZOI.AddonControl')
local M={}
M.fields={'goals','restrictions','end_policy','task_progress_multiplier','stages','required_stages','stage_preferences','auto_speed'}
local function search()return require('SceneZOI.SceneSearch')end

local function end_policy(value,has_goals)
 if value==nil then assert(has_goals,'An end policy is required without goals');return {type='goals'}end
 V.fields(value,{'type','seconds','clock'},{'type'})
 if value.type=='goals'then assert(has_goals,'Ending on goals requires goals');return {type='goals'}end
 if value.type=='addon'then return {type='addon'}end
 assert(value.type=='duration','Invalid end policy')
 V.number(value.seconds,1,C.plan_max_seconds)
 local clock=value.clock or 'game';assert(clock=='game'or clock=='real','Invalid plan clock')
 return {type='duration',seconds=value.seconds,clock=clock}
end

local function stage_range(value)
 if value==nil then return 1,1 end
 if type(value)=='number'then V.number(value,1,C.plan_max_stages,true);return value,value end
 V.fields(value,{'min','max'},{'min','max'})
 V.number(value.min,1,C.plan_max_stages,true);V.number(value.max,value.min,C.plan_max_stages,true)
 return value.min,value.max
end

local function criteria(metadata,value)
 assert(V.object(value),'A selector needs a scene match')
 return search().criteria(metadata,value)
end

local function required_stages(value,metadata,least)
 local out=J.array({})
 if value==nil then return out end
 V.array(value,C.plan_max_goals)
 for _,row in ipairs(value)do
  V.fields(row,{'stage','match'},{'match'})
  if row.stage~=nil then
   V.number(row.stage,1,C.plan_max_stages,true)
   assert(row.stage<=least,'required_stage_unavailable')
  end
  out[#out+1]={stage=row.stage,match=criteria(metadata,row.match),met=false}
 end
 return out
end

local function stage_preferences(value,metadata)
 local out=J.array({})
 if value==nil then return out end
 V.array(value,C.plan_max_goals)
 for _,row in ipairs(value)do
  V.fields(row,{'from','to','match'},{'match'})
  local from,to=row.from==nil and 0 or row.from,row.to==nil and 1 or row.to
  V.number(from,0,1);V.number(to,0,1);assert(from<=to,'Invalid stage preference range')
  out[#out+1]={from=from,to=to,match=criteria(metadata,row.match)}
 end
 return out
end

local function auto_speed(value)
 if value==nil or value==true then return {start=1,finish=C.plan_ramp_finish}end
 if value==false then return false end
 V.fields(value,{'start','finish'},{'start','finish'})
 V.number(value.start,C.plan_min_speed,C.plan_max_speed);V.number(value.finish,C.plan_min_speed,C.plan_max_speed)
 return {start=value.start,finish=value.finish}
end

function M.parse(args,definitions,ids,metadata)
 local known,goals,seen={},J.array({}),{}
 for _,id in ipairs(ids)do known[id]=true end
 if args.goals~=nil then
  V.array(args.goals,C.plan_max_goals)
  for _,goal in ipairs(args.goals)do
   V.fields(goal,{'participant_id','task_id','completions'},{'participant_id','task_id'})
   assert(type(goal.participant_id)=='string'and known[goal.participant_id],'participant_not_found')
   V.id(goal.task_id);assert(definitions[goal.task_id],'task_not_found')
   local count=goal.completions==nil and 1 or goal.completions
   V.number(count,1,C.plan_max_completions,true)
   local key=goal.participant_id..'|'..goal.task_id
   assert(not seen[key],'Duplicate goal for one participant and task');seen[key]=true
   goals[#goals+1]={participant_id=goal.participant_id,task_id=goal.task_id,completions=count}
  end
 end
 local multiplier=args.task_progress_multiplier==nil and 1 or args.task_progress_multiplier
 V.number(multiplier,C.plan_min_multiplier,C.plan_max_multiplier)
 local least,most=stage_range(args.stages)
 local policy=end_policy(args.end_policy,#goals>0)
 local required=required_stages(args.required_stages,metadata,least)
 -- Neither goals nor a timer can move this plan past its first stage.
 if #goals==0 and policy.type=='addon'then
  for _,row in ipairs(required)do assert(row.stage==nil or row.stage==1,'required_stage_unavailable')end
 end
 return {goals=goals,end_policy=policy,task_progress_multiplier=multiplier,
  stage_min=least,stage_max=most,required_stages=required,
  stage_preferences=stage_preferences(args.stage_preferences,metadata),auto_speed=auto_speed(args.auto_speed)}
end

local function targets(node,with_completion_routes)
 if node.kind=='transition'then return {node.destination}end
 local out={}
 for _,edge in ipairs(node.navigation or {})do out[#out+1]=edge.target end
 if with_completion_routes then
  for _,routes in pairs(node.task_completion_routes or {})do for _,target in pairs(routes)do out[#out+1]=target end end
 end
 return out
end
local function finishes(directive)return directive~=nil and directive.rate>0 and(directive.cap_percent or 100)>=100 end

-- Walks the authored graph from a proposed entry. A node counts only if the fixed roster can play it.
local function explore(nodes,entry,spec,people,restrictions,with_completion_routes)
 local Search=search();local Binding=require('SceneZOI.Binding')
 local start=nodes[entry.scene_id];local roles={}
 for role,id in pairs(entry.bindings)do roles[id]=role end
 local roster={};for _,person in ipairs(people)do roster[#roster+1]={role=roles[person.id],body=person.body}end
 local function playable(node)
  return V.equal(node.furniture,start.furniture)and Search.allowed(nodes,node,restrictions)and pcall(Binding.resolve,roster,node)
 end
 local visited,queue,finishable,matched,head,uncertain,links={[entry.scene_id]=true},{entry.scene_id},{},{},1,false,{}
 while head<=#queue do
  local id=queue[head];local node=nodes[id];head=head+1
  links[id]={}
  if node.kind~='transition'then
   for _,goal in ipairs(spec.goals)do
    local directive=((node.tasks or {})[roles[goal.participant_id]]or {})[goal.task_id]
    if finishes(directive)then
     local key=goal.participant_id..'|'..goal.task_id
     finishable[key]=finishable[key]or {};finishable[key][id]=true
    end
   end
   for index,requirement in ipairs(spec.required_stages or {})do
    if Search.matches(node,requirement.match)then matched[index]=matched[index]or {};matched[index][id]=true end
   end
  end
  for _,target in ipairs(targets(node,with_completion_routes))do
   local candidate=nodes[target]
   if candidate and playable(candidate)then
    links[id][target]=true
    if not visited[target]then
     if #queue>=C.plan_route_limit then uncertain=true else visited[target]=true;queue[#queue+1]=target end
    end
   end
  end
 end
 if uncertain then return true,true end
 local function reaches(from,to)
  if from==to then return true end
  local seen,stack={[from]=true},{from}
  while #stack>0 do
   for target in pairs(links[table.remove(stack)]or {})do
    if target==to then return true end
    if not seen[target]then seen[target]=true;stack[#stack+1]=target end
   end
  end
  return false
 end
 for _,goal in ipairs(spec.goals)do
  if not finishable[goal.participant_id..'|'..goal.task_id]then return false,false,'goal_unreachable'end
 end
 -- A required loop must connect to where each goal can finish, in one order or the other.
 for index in ipairs(spec.required_stages or {})do
  if not matched[index]then return false,false,'required_stage_unavailable'end
  local workable=false
  for id in pairs(matched[index])do
   local connected=true
   for _,goal in ipairs(spec.goals)do
    local linked=false
    for finish in pairs(finishable[goal.participant_id..'|'..goal.task_id])do
     if reaches(id,finish)or reaches(finish,id)then linked=true;break end
    end
    if not linked then connected=false;break end
   end
   if connected then workable=true;break end
  end
  if not workable then return false,false,'required_stage_unavailable'end
 end
 return true,false
end

local function route_check(nodes,entry,spec,people,restrictions)
 local viable,uncertain,why=explore(nodes,entry,spec,people,restrictions,false)
 if viable then return viable,uncertain end
 -- A completion route may open a path that automatic navigation cannot take: possible, not provable.
 if explore(nodes,entry,spec,people,restrictions,true)then return true,true end
 return false,false,why
end

local function hash(text,seed)
 local value=seed
 for i=1,#text do value=(value*31+text:byte(i))%1000003 end
 return value/1000003
end
local function preference_bonus(plan,node,fraction)
 local bonus,count=0,#plan.stage_preferences
 for index,preference in ipairs(plan.stage_preferences)do
  if fraction>=preference.from and fraction<=preference.to and search().matches(node,preference.match)then
   bonus=bonus+50*(count-index+1)
  end
 end
 return bonus
end
local function entry_score(nodes,row,spec,seed)
 local node,score=nodes[row.scene_id],0
 local roles={};for role,id in pairs(row.bindings)do roles[id]=role end
 for _,goal in ipairs(spec.goals)do
  local directive=((node.tasks or {})[roles[goal.participant_id]]or {})[goal.task_id]
  if directive and directive.rate>0 then score=score+10;if finishes(directive)then score=score+1 end end
 end
 for _,requirement in ipairs(spec.required_stages or {})do
  if(requirement.stage==nil or requirement.stage==1)and search().matches(node,requirement.match)then score=score+1000 end
 end
 return score+preference_bonus(spec,node,0)+hash(row.scene_id,seed)
end

-- Chooses where the scene begins, refusing a plan the data shows cannot be finished.
function M.pick_entry(data,spec,rows,people,restrictions)
 assert(#rows>0,'no_matching_scenes')
 spec.seed=spec.seed or math.random(1,1000000)
 spec.stage_count=spec.stage_count or(spec.stage_min+(spec.seed%(spec.stage_max-spec.stage_min+1)))
 local best,best_score,best_uncertain,reason
 for _,row in ipairs(rows)do
  local viable,uncertain,why=route_check(data.nodes,row,spec,people,restrictions)
  if viable then
   local score=entry_score(data.nodes,row,spec,spec.seed)
   if not best or score>best_score then best,best_score,best_uncertain=row,score,uncertain end
  else reason=why end
 end
 assert(best,reason or'goal_unreachable')
 spec.route_uncertain=best_uncertain==true
 return best
end

function M.new(spec)
 local plan=V.copy(spec)
 plan.auto_mode=true;plan.state='running';plan.stage=1;plan.stage_count=plan.stage_count or 1;plan.stage_played=false
 plan.real_used,plan.game_used,plan.stall_age,plan.dwell,plan.wait_age,plan.marks=0,0,0,0,0,{}
 plan.seed=plan.seed or 1;plan.credited={};plan.required_stages=plan.required_stages or J.array({})
 plan.stage_preferences=plan.stage_preferences or J.array({})
 if plan.auto_speed==nil then plan.auto_speed=false end
 return plan
end

local function goal_state(session,goal)
 local entry=session.tasks.participants[goal.participant_id][goal.task_id]
 local maximum=session.tasks.definitions[goal.task_id].maximum
 local satisfied=entry.completions>=goal.completions
 return satisfied,satisfied and 1 or(entry.completions+entry.value/maximum)/goal.completions,entry,maximum
end

local function each_open(session,plan,visit)
 for _,goal in ipairs(plan.goals)do
  local satisfied,progress,entry,maximum=goal_state(session,goal)
  if not satisfied then visit(goal,progress,entry,maximum)end
 end
end

local function role_of(session,id)
 for _,person in ipairs(session.participants)do if person.id==id then return person.role end end
end

-- Can this node still move the goal? The effective rate is what counts, not the authored one.
local function advance(session,node,goal,entry,maximum)
 local directive=((node.tasks or {})[role_of(session,goal.participant_id)]or {})[goal.task_id]
 if not directive or not directive.rate or directive.rate<=0 then return false,false end
 if Control.task(session,goal.participant_id,goal.task_id)<=0 then return false,false end
 local percent=directive.cap_percent or 100
 return entry.value<maximum*percent/100,percent>=100
end

local function advancing(session,plan,node)
 local found=false
 each_open(session,plan,function(goal,_,entry,maximum)if advance(session,node,goal,entry,maximum)then found=true end end)
 return found
end

local function fraction(plan)
 return plan.stage_count>1 and(plan.stage-1)/(plan.stage_count-1)or 0
end

local function open_requirement(plan,requirement)
 return not requirement.met and(requirement.stage==nil or requirement.stage==plan.stage)
end

-- Visits what the fixed roster can reach along authored edges, nearest first. Never a jump.
local function walk(session,visit,from)
 local Catalog=require('SceneZOI.Catalog');local Search=search();local Binding=require('SceneZOI.Binding')
 local nodes=Catalog.get_snapshot().nodes
 from=from or session.node
 local visited,queue,head={[from.id]=true},{{node=from,depth=0}},1
 while head<=#queue and head<=C.plan_route_limit do
  local row=queue[head];head=head+1
  if row.depth>0 and visit(row)then return end
  local edges=row.node.kind=='transition'and {{target=row.node.destination}}or row.node.navigation or {}
  for _,edge in ipairs(edges)do
   local target=nodes[edge.target]
   if target and not visited[edge.target]and V.equal(target.furniture,session.node.furniture)and
    Search.allowed(nodes,target,session.session_restrictions)and pcall(Binding.resolve,session.participants,target)then
    visited[edge.target]=true
    queue[#queue+1]={node=target,depth=row.depth+1,first=row.first or edge.id}
   end
  end
 end
end

-- A required loop is worth visiting only if the goals still open can be reached from it.
local function route_out(session,plan,node)
 local missing={}
 each_open(session,plan,function(goal,_,entry,maximum)
  if not advance(session,node,goal,entry,maximum)then missing[goal]={entry,maximum}end
 end)
 if next(missing)==nil then return true end
 walk(session,function(row)
  if row.node.kind~='transition'then
   for goal,state in pairs(missing)do
    if advance(session,row.node,goal,state[1],state[2])then missing[goal]=nil end
   end
  end
  return next(missing)==nil
 end,node)
 return next(missing)==nil
end

-- Worth of a candidate loop for this stage. Nil means it moves nothing the plan still needs.
local function node_value(session,plan,node)
 local value,useful=0,false
 local has_work=false
 for _,requirement in ipairs(plan.required_stages)do
  if not requirement.met then has_work=true end
  if open_requirement(plan,requirement)and search().matches(node,requirement.match)and route_out(session,plan,node)then value=value+1000;useful=true end
 end
 local least=math.huge
 each_open(session,plan,function(_,progress)least=math.min(least,progress);has_work=true end)
 each_open(session,plan,function(goal,progress,entry,maximum)
  local can,full=advance(session,node,goal,entry,maximum)
  if can then
   useful=true;value=value+1
   if full then value=value+10 end
   if progress<=least then value=value+100 end
  end
 end)
 if has_work and not useful then return nil end
 return value+preference_bonus(plan,node,fraction(plan))+hash(node.id,plan.seed)
end

-- The next edge toward the best loop, and that loop, so a route through a hub keeps its destination.
function M.route(session,plan)
 local best
 walk(session,function(row)
  if row.node.kind=='transition'then return false end
  local value=node_value(session,plan,row.node)
  if value then
   value=value-row.depth*.01
   if not best or value>best.value then best={first=row.first,value=value,target=row.node.id}end
  end
  return false
 end)
 if best then return best.first,best.target,best.value end
end

local function edge_toward(session,target)
 local first
 walk(session,function(row)
  if row.node.id==target then first=row.first;return true end
  return false
 end)
 return first
end

local function goals_met(session,plan)
 for _,goal in ipairs(plan.goals)do if not goal_state(session,goal)then return false end end
 return true
end
local function requirements_met(plan)
 for _,requirement in ipairs(plan.required_stages)do if not requirement.met then return false end end
 return true
end

-- Authored responses to a completion resolve before the plan moves on or ends.
local function settled(session)
 local effects=session.completion_effects
 if effects and(effects.motion or next(effects.shakes or {}))then return false end
 local voices=session.voice_responses
 return not(voices and next(voices.channels or {}))
end

local function finish(plan,code,outcome)
 plan.state='finished';plan.outcome=outcome or code
 return {stop=code}
end

local function clock_seconds(plan,clock)return clock=='real'and plan.real_used or plan.game_used end

-- A stage is earned by its loop actually playing. A later visit to the same stage earns nothing.
local function credit_stage(session,plan)
 plan.stage_played=true
 -- A loop the player chose by hand earns nothing: credit comes through auto-mode entry.
 if plan.manual_revision~=nil and plan.manual_revision==session.revision then return false end
 local key=plan.stage..':'..session.revision
 if plan.credited[key]then return false end
 plan.credited[key]=true
 local earned=false
 for _,requirement in ipairs(plan.required_stages)do
  if open_requirement(plan,requirement)and search().matches(session.node,requirement.match)then requirement.met=true;earned=true end
 end
 return earned
end

-- Decay never moves a stage back: the minimum across goals decides, and only upward.
local function stage_due(session,plan)
 if plan.stage_count<=1 then return plan.stage end
 local due=plan.stage
 if #plan.goals>0 then
  local least=1
  for _,goal in ipairs(plan.goals)do local _,progress=goal_state(session,goal);least=math.min(least,progress)end
  due=math.floor(least*plan.stage_count)+1
 elseif plan.end_policy.type=='duration'then
  due=math.floor(clock_seconds(plan,plan.end_policy.clock)/plan.end_policy.seconds*plan.stage_count)+1
 end
 return math.max(plan.stage,math.min(due,plan.stage_count))
end

-- A hold or a paused rate is temporary. The no-progress window decides if it never lifts.
local function held(session,plan,node)
 local found=false
 each_open(session,plan,function(goal,_,entry,maximum)
  local directive=((node.tasks or {})[role_of(session,goal.participant_id)]or {})[goal.task_id]
  if directive and directive.rate and directive.rate>0 and(Control.task(session,goal.participant_id,goal.task_id)<=0 or
   (entry.value>=maximum and(directive.cap_percent or 100)>=100))then found=true end
 end)
 return found
end

-- This loop still does something, but a requirement or the slowest goal needs another one.
local function wants_move(session,plan,node)
 for _,requirement in ipairs(plan.required_stages)do
  if open_requirement(plan,requirement)and not search().matches(node,requirement.match)then return true end
 end
 local least,lagging=math.huge,false
 each_open(session,plan,function(goal,progress,entry,maximum)
  if progress<least then least,lagging=progress,not advance(session,node,goal,entry,maximum)end
 end)
 return lagging
end

function M.tick(session,dt,scale)
 local plan=session.plan
 if not plan or plan.state=='finished'or not plan.auto_mode or session.preparing or session.stopping or scale<=0 or dt<=0 then return nil end
 plan.real_used=plan.real_used+dt;plan.game_used=plan.game_used+dt*scale
 if session.node.kind=='transition'then return nil end
 plan.dwell=plan.dwell+dt
 local earned=credit_stage(session,plan)
 if earned then plan.stall_age=0 end
 local policy=plan.end_policy
 local timed=policy.type=='duration'
 if timed and clock_seconds(plan,policy.clock)>=policy.seconds and settled(session)then
  return finish(plan,'ok','duration_elapsed')
 end
 if plan.real_used>=C.plan_max_playback_seconds then return finish(plan,'playback_budget_exceeded')end
 local goals_done,requirements_done=goals_met(session,plan),requirements_met(plan)
 local done=goals_done and requirements_done
 local has_targets=#plan.goals>0 or #plan.required_stages>0
 if done and has_targets then
  if timed then return nil end
  if not settled(session)then plan.state='resolving';return nil end
  if policy.type=='goals'then return finish(plan,'ok','goals_met')end
  if plan.state~='waiting'then plan.state='waiting';return {event='plan_goals_met'}end
  plan.wait_age=plan.wait_age+dt
  if plan.wait_age>=C.plan_wait_seconds then return finish(plan,'owner_expired','wait_expired')end
  return nil
 end
 if not timed then
  for _,requirement in ipairs(plan.required_stages)do
   if not requirement.met and requirement.stage and requirement.stage<plan.stage then return finish(plan,'required_stage_unavailable')end
  end
 end
 if not settled(session)then return nil end
 local rested=plan.dwell>=C.plan_min_dwell_seconds
 -- One decision at a time: a route through a hub reaches its destination before anything else is decided.
 if plan.heading then
  if session.node.id==plan.heading then plan.heading=nil
  else
   local edge=edge_toward(session,plan.heading)
   if edge then
    if plan.stage_played and rested then plan.dwell=0;return {navigate=edge}end
    return nil
   end
   plan.heading=nil
  end
 end
 if plan.stage_played and stage_due(session,plan)>plan.stage then
  plan.stage,plan.stage_played=plan.stage+1,false
  local edge,target=M.route(session,plan)
  plan.heading=target
  if edge and rested then plan.dwell=0;return {event='plan_stage_changed',navigate=edge}end
  return {event='plan_stage_changed'}
 end
 if not has_targets then return nil end
 local moved=false
 each_open(session,plan,function(goal,progress)
  local key=goal.participant_id..'|'..goal.task_id
  if progress>(plan.marks[key]or -1)+1e-6 then plan.marks[key],moved=progress,true end
 end)
 plan.stall_age=moved and 0 or plan.stall_age+dt
 if plan.stall_age>=C.plan_no_progress_seconds and not timed then return finish(plan,'no_progress')end
 if not rested then return nil end
 local stuck=not advancing(session,plan,session.node)
 if not stuck and not wants_move(session,plan,session.node)then return nil end
 local edge,target,value=M.route(session,plan)
 local here=node_value(session,plan,session.node)
 plan.dwell=0
 if edge and(stuck or not here or value>here)then plan.heading=target;return {navigate=edge}end
 -- A timed plan runs its time and reports what it did not reach.
 if not stuck or timed or held(session,plan,session.node)then return nil end
 if not goals_done then return finish(plan,'goal_unreachable')end
 return finish(plan,'required_stage_unavailable')
end

function M.rate_factor(session)
 local plan=session.plan
 return plan and plan.auto_mode and plan.task_progress_multiplier or 1
end
-- While a finished scene resolves or an add-on decides, fulfilled tasks stop so they cannot complete again.
function M.frozen(session,participant_id,task_id)
 local plan=session.plan
 if not plan or(plan.state~='waiting'and plan.state~='resolving')then return false end
 for _,goal in ipairs(plan.goals)do
  if goal.participant_id==participant_id and goal.task_id==task_id then return (goal_state(session,goal))end
 end
 return false
end
function M.locked(session)return session.plan~=nil and session.plan.auto_mode==true and session.plan.state~='finished'end

-- The animation ramp for this stage. Task rates stay on game time.
function M.speed(session)
 local plan=session.plan
 if not plan or not plan.auto_mode or not plan.auto_speed then return 1 end
 local profile=plan.auto_speed
 return profile.start+(profile.finish-profile.start)*fraction(plan)
end

-- Manual takeover keeps everything; turning it back on re-evaluates from the current state.
function M.set_auto(session,enabled)
 local plan=session.plan
 if not plan or plan.state=='finished'or plan.auto_mode==enabled then return false end
 plan.auto_mode,plan.heading=enabled,nil
 if enabled then
  plan.dwell,plan.stall_age,plan.marks=0,0,{}
  if session.revision~=plan.handover_revision then plan.manual_revision=session.revision end
 else plan.handover_revision=session.revision end
 return true
end

function M.snapshot(session)
 local plan=session.plan
 if not plan then return nil end
 local goals=J.array({})
 for _,goal in ipairs(plan.goals)do
  local satisfied,progress,entry=goal_state(session,goal)
  goals[#goals+1]={participant_id=goal.participant_id,task_id=goal.task_id,requested=goal.completions,
   completed=entry.completions,progress=progress,satisfied=satisfied}
 end
 local required=J.array({})
 for _,requirement in ipairs(plan.required_stages)do required[#required+1]={stage=requirement.stage,met=requirement.met}end
 return {auto_mode=plan.auto_mode,state=plan.state,outcome=plan.outcome,end_policy=V.copy(plan.end_policy),goals=goals,
  required_stages=required,stage=plan.stage,stage_count=plan.stage_count,task_progress_multiplier=plan.task_progress_multiplier,
  real_seconds=plan.real_used,game_seconds=plan.game_used,route_uncertain=plan.route_uncertain==true}
end
return M

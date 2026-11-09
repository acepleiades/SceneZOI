-- Autonomous plans: what an add-on asked an automatic scene to achieve and how it ends.
-- Owns no playback. Runtime asks tick() what to do next and carries it out.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local C=require('SceneZOI.Config')
local Control=require('SceneZOI.AddonControl')
local M={}
M.fields={'goals','restrictions','end_policy','task_progress_multiplier'}

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

function M.parse(args,definitions,ids)
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
 return {goals=goals,end_policy=end_policy(args.end_policy,#goals>0),task_progress_multiplier=multiplier}
end

local function targets(node)
 if node.kind=='transition'then return {node.destination}end
 local out={}
 for _,edge in ipairs(node.navigation or {})do out[#out+1]=edge.target end
 for _,routes in pairs(node.task_completion_routes or {})do for _,target in pairs(routes)do out[#out+1]=target end end
 return out
end
local function finishes(directive)return directive~=nil and directive.rate>0 and(directive.cap_percent or 100)>=100 end

-- Walks the authored graph from a proposed entry. A node counts only if the fixed roster can play it.
local function route_check(nodes,entry,spec,people,restrictions)
 local Search=require('SceneZOI.SceneSearch');local Binding=require('SceneZOI.Binding')
 local start=nodes[entry.scene_id];local roles={}
 for role,id in pairs(entry.bindings)do roles[id]=role end
 local roster={};for _,person in ipairs(people)do roster[#roster+1]={role=roles[person.id],body=person.body}end
 local function playable(node)
  return V.equal(node.furniture,start.furniture)and Search.allowed(nodes,node,restrictions)and pcall(Binding.resolve,roster,node)
 end
 local visited,queue,finishable,head,uncertain={[entry.scene_id]=true},{entry.scene_id},{},1,false
 while head<=#queue do
  local node=nodes[queue[head]];head=head+1
  if node.kind~='transition'then
   for _,goal in ipairs(spec.goals)do
    local directive=((node.tasks or {})[roles[goal.participant_id]]or {})[goal.task_id]
    if finishes(directive)then finishable[goal.participant_id..'|'..goal.task_id]=true end
   end
  end
  for _,target in ipairs(targets(node))do
   local candidate=nodes[target]
   if candidate and not visited[target]and playable(candidate)then
    if #queue>=C.plan_route_limit then uncertain=true else visited[target]=true;queue[#queue+1]=target end
   end
  end
 end
 for _,goal in ipairs(spec.goals)do
  if not finishable[goal.participant_id..'|'..goal.task_id]and not uncertain then return false end
 end
 return true,uncertain
end

local function hash(text,seed)
 local value=seed
 for i=1,#text do value=(value*31+text:byte(i))%1000003 end
 return value/1000003
end
local function entry_score(nodes,row,spec,seed)
 local node,score=nodes[row.scene_id],0
 local roles={};for role,id in pairs(row.bindings)do roles[id]=role end
 for _,goal in ipairs(spec.goals)do
  local directive=((node.tasks or {})[roles[goal.participant_id]]or {})[goal.task_id]
  if directive and directive.rate>0 then score=score+10;if finishes(directive)then score=score+1 end end
 end
 return score+hash(row.scene_id,seed)
end

-- Chooses where the scene begins, refusing a plan the data shows cannot be finished.
function M.pick_entry(data,spec,rows,people,restrictions)
 assert(#rows>0,'no_matching_scenes')
 local best,best_score,best_uncertain
 spec.seed=spec.seed or math.random(1,1000000)
 for _,row in ipairs(rows)do
  local viable,uncertain=route_check(data.nodes,row,spec,people,restrictions)
  if viable then
   local score=entry_score(data.nodes,row,spec,spec.seed)
   if not best or score>best_score then best,best_score,best_uncertain=row,score,uncertain end
  end
 end
 assert(best,'goal_unreachable')
 spec.route_uncertain=best_uncertain==true
 return best
end

function M.new(spec)
 local plan=V.copy(spec)
 plan.auto_mode=true;plan.state='running';plan.stage=1;plan.stage_count=1
 plan.real_used,plan.game_used,plan.stall_age,plan.dwell,plan.wait_age,plan.progress_mark=0,0,0,0,0,-1
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

-- Favors the least-progressed goal, then nodes that can finish a goal. Nil if it moves nothing.
local function node_score(session,plan,node)
 local least=math.huge
 each_open(session,plan,function(_,progress)least=math.min(least,progress)end)
 local score,moved=0,false
 each_open(session,plan,function(goal,progress,entry,maximum)
  local can,full=advance(session,node,goal,entry,maximum)
  if can then
   moved=true;score=score+1
   if full then score=score+10 end
   if progress<=least then score=score+100 end
  end
 end)
 return moved and score+hash(node.id,plan.seed or 1)or nil
end

-- Next authored edge toward the nearest node that moves an open goal.
function M.route(session,plan)
 local Catalog=require('SceneZOI.Catalog');local Search=require('SceneZOI.SceneSearch');local Binding=require('SceneZOI.Binding')
 local nodes=Catalog.get_snapshot().nodes
 local visited,queue,head,best={[session.node.id]=true},{{node=session.node,depth=0}},1,nil
 while head<=#queue and head<=C.plan_route_limit do
  local row=queue[head];head=head+1
  if row.depth>0 and row.node.kind~='transition'then
   local score=node_score(session,plan,row.node)
   if score and(not best or row.depth<best.depth or row.depth==best.depth and score>best.score)then
    best={first=row.first,depth=row.depth,score=score}
   end
  end
  if not best or row.depth<best.depth then
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
 return best and best.first
end

local function all_satisfied(session,plan)
 for _,goal in ipairs(plan.goals)do if not goal_state(session,goal)then return false end end
 return true
end

local function settled(session)
 local effects=session.completion_effects
 return not(effects and effects.motion)
end

local function finish(plan,code,outcome)
 plan.state='finished';plan.outcome=outcome or code
 return {stop=code}
end

function M.tick(session,dt,scale)
 local plan=session.plan
 if not plan or plan.state=='finished'or not plan.auto_mode or session.preparing or session.stopping or scale<=0 or dt<=0 then return nil end
 plan.real_used=plan.real_used+dt;plan.game_used=plan.game_used+dt*scale
 if session.node.kind=='transition'then return nil end
 plan.dwell=plan.dwell+dt
 if plan.real_used>=C.plan_max_playback_seconds then return finish(plan,'playback_budget_exceeded')end
 local policy=plan.end_policy
 local done=all_satisfied(session,plan)
 if policy.type=='duration'then
  local used=policy.clock=='real'and plan.real_used or plan.game_used
  if used>=policy.seconds and settled(session)then return finish(plan,'ok','duration_elapsed')end
 end
 if done and #plan.goals>0 then
  if policy.type=='goals'then
   if settled(session)then return finish(plan,'ok','goals_met')end
   return nil
  end
  if policy.type=='addon'then
   if plan.state~='waiting'then plan.state='waiting';return {event='plan_goals_met'}end
   plan.wait_age=plan.wait_age+dt
   if plan.wait_age>=C.plan_wait_seconds then return finish(plan,'owner_expired','wait_expired')end
  end
  return nil
 end
 if #plan.goals==0 then return nil end
 local total=0
 for _,goal in ipairs(plan.goals)do local _,progress=goal_state(session,goal);total=total+progress end
 if total>plan.progress_mark+1e-6 then plan.progress_mark,plan.stall_age=total,0
 else plan.stall_age=plan.stall_age+dt end
 if plan.stall_age>=C.plan_no_progress_seconds then return finish(plan,'no_progress')end
 if plan.dwell>=C.plan_min_dwell_seconds and not advancing(session,plan,session.node)then
  local edge=M.route(session,plan)
  if not edge then return finish(plan,'goal_unreachable')end
  plan.dwell=0
  return {navigate=edge}
 end
end

function M.rate_factor(session)
 local plan=session.plan
 return plan and plan.auto_mode and plan.task_progress_multiplier or 1
end
-- While an add-on holds a finished scene open, fulfilled tasks stop so they cannot complete again.
function M.frozen(session,participant_id,task_id)
 local plan=session.plan
 if not plan or plan.state~='waiting'then return false end
 for _,goal in ipairs(plan.goals)do
  if goal.participant_id==participant_id and goal.task_id==task_id then return (goal_state(session,goal))end
 end
 return false
end
function M.locked(session)return session.plan~=nil and session.plan.auto_mode==true and session.plan.state~='finished'end

function M.snapshot(session)
 local plan=session.plan
 if not plan then return nil end
 local goals=J.array({})
 for _,goal in ipairs(plan.goals)do
  local satisfied,progress,entry=goal_state(session,goal)
  goals[#goals+1]={participant_id=goal.participant_id,task_id=goal.task_id,requested=goal.completions,
   completed=entry.completions,progress=progress,satisfied=satisfied}
 end
 return {auto_mode=plan.auto_mode,state=plan.state,outcome=plan.outcome,end_policy=V.copy(plan.end_policy),goals=goals,
  stage=plan.stage,stage_count=plan.stage_count,task_progress_multiplier=plan.task_progress_multiplier,
  real_seconds=plan.real_used,game_seconds=plan.game_used,route_uncertain=plan.route_uncertain==true}
end
return M

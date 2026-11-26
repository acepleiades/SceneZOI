local TaskData=require('SceneZOI.TaskData')
-- Autonomous plans: what an add-on asked an automatic scene to achieve and how it ends.
-- Owns no playback. Runtime asks tick() what to do next and carries it out.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local C=require('SceneZOI.Config')
local Control=require('SceneZOI.AddonControl')
local M={}
M.fields={'goals','restrictions','auto_restrictions','end_policy','post_completion_stay_seconds',
 'skip_post_completion_stay_after_manual','task_progress_multiplier','stages','stage_progress',
 'required_stages','stage_preferences','stage_priorities','variety_groups','auto_speed'}
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

local function stage_priorities(value,metadata,least)
 if value==nil then return end
 V.array(value,C.plan_max_stages)
 assert(#value>0,'Stage priorities need at least one stage')
 local out,seen={},{}
 for _,row in ipairs(value)do
  V.fields(row,{'stage','matches'},{'stage','matches'})
  V.number(row.stage,1,least,true)
  assert(not seen[row.stage],'Duplicate stage priority')
  V.array(row.matches,C.plan_max_stages)
  assert(#row.matches>0,'A stage priority needs at least one match')
  local matches={}
  for _,match in ipairs(row.matches)do matches[#matches+1]=criteria(metadata,match)end
  out[#out+1]={stage=row.stage,matches=matches}
  seen[row.stage]=true
 end
 return out
end

local function variety_groups(value)
 if value==nil then return end
 assert(V.object(value),'Invalid variety groups')
 local out,count={},0
 for scene_id,group in pairs(value)do
  V.id(scene_id)
  V.id(group)
  count=count+1
  assert(count<=C.plan_route_limit,'Too many variety groups')
  out[scene_id]=group
 end
 return out
end

local function auto_speed(value)
 if value==nil then return true end
 if type(value)=='boolean'then return value end
 V.fields(value,{'start','finish','minimum'},{'start','finish'})
 local speeds=C.playback_speeds
 V.number(value.start,speeds[1],speeds[#speeds]);V.number(value.finish,speeds[1],speeds[#speeds])
 local minimum
 if value.minimum~=nil then
  for _,speed in ipairs(speeds)do
   if value.minimum==speed then minimum=speed;break end
  end
  assert(minimum,'Invalid minimum Auto-mode playback speed')
 end
 return {start=value.start,finish=value.finish,minimum=minimum}
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
 local stage_progress=args.stage_progress
 if stage_progress~=nil then
  assert(stage_progress=='slowest'or stage_progress=='fastest','Invalid stage progress')
  assert(#goals>0,'Stage progress requires goals')
 end
 local policy=end_policy(args.end_policy,#goals>0)
 local stay=args.post_completion_stay_seconds
 if stay~=nil then
  assert(policy.type=='goals','Post-completion stay requires a goals end policy')
  V.number(stay,0,C.plan_max_seconds)
 end
 local skip_stay=args.skip_post_completion_stay_after_manual
 if skip_stay~=nil then
  V.boolean(skip_stay)
  assert(policy.type=='goals','Manual completion stay option requires a goals end policy')
 end
 local required=required_stages(args.required_stages,metadata,least)
 local auto_restrictions
 if args.auto_restrictions~=nil then
  assert(V.object(args.auto_restrictions),'Expected Auto-mode restrictions')
  auto_restrictions=search().criteria(metadata,args.auto_restrictions)
 end
 -- Neither goals nor a timer can move this plan past its first stage.
 if #goals==0 and policy.type=='addon'then
  for _,row in ipairs(required)do assert(row.stage==nil or row.stage==1,'required_stage_unavailable')end
 end
 return {goals=goals,end_policy=policy,post_completion_stay_seconds=stay,
  skip_post_completion_stay_after_manual=skip_stay,task_progress_multiplier=multiplier,
  stage_min=least,stage_max=most,stage_progress=stage_progress,required_stages=required,
  stage_preferences=stage_preferences(args.stage_preferences,metadata),
  stage_priorities=stage_priorities(args.stage_priorities,metadata,least),
  variety_groups=variety_groups(args.variety_groups),auto_restrictions=auto_restrictions,
  auto_speed=auto_speed(args.auto_speed)}
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
local function goal_directive(node,role,id,registry)
 local key,reason=TaskData.resolve(registry,node,id)
 if key then return TaskData.directive(node,role,id,key) end
 return nil,reason
end

local function allowed(nodes,node,restrictions,auto_restrictions)
 local Search=search()
 return Search.allowed(nodes,node,restrictions) and
  (not auto_restrictions or Search.allowed(nodes,node,auto_restrictions))
end

-- Each mask represents the goals one directed walk can finish. Walks can
-- revisit loops, but goals found on separate one-way branches cannot combine.
local function joint_routes(links,masks,goal_count)
 local all=(1<<goal_count)-1
 if all==0 then return {},false end
 local predecessors,reachable,solved,queue={},{},{},{}
 for id in pairs(links)do predecessors[id]={} end
 for id,edges in pairs(links)do
  for target in pairs(edges)do
   local incoming=predecessors[target]
   if incoming then incoming[#incoming+1]=id end
  end
 end
 local function record(id,mask)
  if mask==0 then return end
  local known=reachable[id] or {}
  reachable[id]=known
  for old in pairs(known)do if (old|mask)==old then return end end
  for old in pairs(known)do if (old|mask)==mask then known[old]=nil end end
  known[mask]=true
  if mask==all then solved[id]=true end
  queue[#queue+1]={id=id,mask=mask}
 end
 for id in pairs(links)do record(id,masks[id] or 0)end
 local head,limit=1,C.plan_route_limit*goal_count*4
 while head<=#queue do
  if #queue>limit then return solved,true end
  local row=queue[head];head=head+1
  if reachable[row.id][row.mask]then
   for _,id in ipairs(predecessors[row.id])do record(id,row.mask|(masks[id] or 0))end
  end
 end
 return solved,false
end

-- Walks the authored graph from a proposed entry. A node counts only if the fixed roster can play it.
local function explore(data,entry,spec,people,restrictions,with_completion_routes)
 local nodes=data.nodes;local registry=data.tasks
 local Search=search();local Binding=require('SceneZOI.Binding')
 local start=nodes[entry.scene_id];local roles={}
 for role,id in pairs(entry.bindings)do roles[id]=role end
 local roster={};for _,person in ipairs(people)do roster[#roster+1]={role=roles[person.id],body=person.body}end
 local function playable(node)
  return V.equal(node.furniture,start.furniture)and allowed(nodes,node,restrictions,spec.auto_restrictions)and
   pcall(Binding.resolve,roster,node)
 end
 local unresolved={}
 local visited,queue,finishable,matched,head,uncertain,links,masks={[entry.scene_id]=true},{entry.scene_id},{},{},1,false,{},{}
 while head<=#queue do
  local id=queue[head];local node=nodes[id];head=head+1
  links[id]={}
  if node.kind~='transition'then
   for index,goal in ipairs(spec.goals)do
    local declared=((node.tasks or {})[roles[goal.participant_id]]or {})[goal.task_id]
    if TaskData.can_finish(declared)then
     local directive,reason=goal_directive(node,roles[goal.participant_id],goal.task_id,registry)
     if directive then
      local candidates=finishable[goal]or {};finishable[goal]=candidates
      candidates[id]=true
      masks[id]=(masks[id] or 0)|(1<<(index-1))
     elseif reason=='task_provider_unavailable'then unresolved[goal]=reason end
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
 for _,goal in ipairs(spec.goals)do
  if not finishable[goal]then return false,false,unresolved[goal] or 'goal_unreachable' end
 end
 if #spec.goals>1 then
  local solved,bounded=joint_routes(links,masks,#spec.goals)
  if not solved[entry.scene_id]then return bounded,bounded,'goal_unreachable' end
 end
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
 -- A required loop must connect to where each goal can finish, in one order or the other.
 for index in ipairs(spec.required_stages or {})do
  if not matched[index]then return false,false,'required_stage_unavailable'end
  local workable=false
  for id in pairs(matched[index])do
   local connected=true
   for _,goal in ipairs(spec.goals)do
    local linked=false
    for finish in pairs(finishable[goal])do
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

local function route_check(data,entry,spec,people,restrictions)
 local viable,uncertain,why=explore(data,entry,spec,people,restrictions,false)
 if viable then return viable,uncertain end
 -- A completion route may open a path that automatic navigation cannot take: possible, not provable.
 local possible,_,fallback_reason=explore(data,entry,spec,people,restrictions,true)
 if possible then return true,true end
 if fallback_reason=='task_provider_unavailable'then why=fallback_reason end
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
local function priority_matches(plan,stage)
 for _,row in ipairs(plan.stage_priorities or {})do
  if row.stage==stage then return row.matches end
 end
end

local function priority(matches,node)
 for index,match in ipairs(matches or {})do
  if search().matches(node,match)then return index end
 end
 return math.huge
end

local function variety_key(plan,node)
 local group=(plan.variety_groups or {})[node.id]
 return group and 'group:'..group or 'loop:'..node.id
end

local function preferred(candidate,best)
 if not best then return true end
 if candidate.required~=best.required then return candidate.required>best.required end
 if candidate.uncertain~=best.uncertain then return not candidate.uncertain end
 if candidate.priority~=best.priority then return candidate.priority<best.priority end
 if candidate.unplayed~=best.unplayed then return candidate.unplayed end
 return candidate.value>best.value
end

local function entry_score(data,row,spec,seed)
 local node,score,required=data.nodes[row.scene_id],0,0
 local roles={};for role,id in pairs(row.bindings)do roles[id]=role end
 local registry=data.tasks
 for _,goal in ipairs(spec.goals)do
  local directive=goal_directive(node,roles[goal.participant_id],goal.task_id,registry)
  if directive and directive.rate>0 then score=score+10;if TaskData.can_finish(directive)then score=score+1 end end
 end
 for _,requirement in ipairs(spec.required_stages or {})do
  if(requirement.stage==nil or requirement.stage==1)and search().matches(node,requirement.match)then required=required+1 end
 end
 return score+required*1000+preference_bonus(spec,node,0)+hash(row.scene_id,seed),required
end

-- Chooses where the scene begins, refusing a plan the data shows cannot be finished.
function M.pick_entry(data,spec,rows,people,restrictions)
 assert(#rows>0,'no_matching_scenes')
 spec.seed=spec.seed or math.random(1,1000000)
 spec.stage_count=spec.stage_count or(spec.stage_min+(spec.seed%(spec.stage_max-spec.stage_min+1)))
 local best,reason
 local matches=priority_matches(spec,1)
 for _,row in ipairs(rows)do
  local node=data.nodes[row.scene_id]
  local viable,uncertain,why
  if allowed(data.nodes,node,restrictions,spec.auto_restrictions)then
   viable,uncertain,why=route_check(data,row,spec,people,restrictions)
  end
  if viable then
   local value,required=entry_score(data,row,spec,spec.seed)
   if not matches then required=0 end
   local candidate={row=row,value=value,required=required,priority=priority(matches,node),uncertain=uncertain}
   if preferred(candidate,best)then best=candidate end
  elseif not reason or why=='task_provider_unavailable'then reason=why end
 end
 assert(best,reason or'goal_unreachable')
 spec.route_uncertain=best.uncertain==true
 return best.row
end

function M.new(spec)
 local plan=V.copy(spec)
 plan.auto_mode=true;plan.state='running';plan.stage=1;plan.stage_count=plan.stage_count or 1;plan.stage_played=false
 plan.real_used,plan.game_used,plan.stall_age,plan.wait_age,plan.marks=0,0,0,0,{}
 plan.seed=plan.seed or 1;plan.credited={};plan.required_stages=plan.required_stages or J.array({})
 plan.stage_preferences=plan.stage_preferences or J.array({})
 if plan.stage_priorities then plan.played_groups={} end
 plan.goals_by_participant={}
 for _,goal in ipairs(plan.goals)do
  local tasks=plan.goals_by_participant[goal.participant_id] or {}
  plan.goals_by_participant[goal.participant_id]=tasks
  tasks[goal.task_id]=goal
 end
 if plan.auto_speed==nil then plan.auto_speed=false end
 return plan
end

local function goal_for(session,participant_id,task_id)
 local by_person=session.plan and session.plan.goals_by_participant
 local tasks=by_person and by_person[participant_id]
 return tasks and tasks[task_id]
end

local function goal_state(session,goal)
 local tasks=session.tasks
 local key=tasks.last_keys[goal.task_id]
 local entry=key and tasks.participants[goal.participant_id][goal.task_id]
 local completed=entry and entry.completions or 0
 local fraction=entry and entry.value/tasks.definitions[key].maximum or 0
 local satisfied=completed>=goal.completions
 return satisfied,satisfied and 1 or(completed+fraction)/goal.completions,completed,fraction
end

local function each_open(session,plan,visit)
 for _,goal in ipairs(plan.goals)do
  local satisfied,progress,_,fraction=goal_state(session,goal)
  if not satisfied then visit(goal,progress,fraction)end
 end
end

local function role_of(session,id)
 for _,person in ipairs(session.participants)do if person.id==id then return person.role end end
end

-- Can this node still move the goal? The effective rate is what counts, not the authored one.
local function advance(session,node,goal,fraction)
 local directive=goal_directive(node,role_of(session,goal.participant_id),goal.task_id,session.tasks.registry)
 if not directive or directive.rate<=0 then return false,false end
 local factor,hold=Control.task(session,goal.participant_id,goal.task_id)
 local full=TaskData.can_finish(directive)
 if fraction>=1 then return full and (node.id~=session.node.id or not hold),full end
 if factor<=0 then return false,false end
 return fraction<(directive.cap_percent or 100)/100,full
end

local function advancing(session,plan,node)
 local found=false
 each_open(session,plan,function(goal,_,fraction)if advance(session,node,goal,fraction)then found=true end end)
 return found
end

local function plan_fraction(plan)
 return plan.stage_count>1 and(plan.stage-1)/(plan.stage_count-1)or 0
end

local function open_requirement(plan,requirement)
 return not requirement.met and(requirement.stage==nil or requirement.stage==plan.stage)
end

-- A requirement pinned to the current stage that has not played yet: the stage stays until its loop plays (the
-- safety limits still apply), even when progress already calls for the next one.
local function stage_bound_open(plan)
 for _,requirement in ipairs(plan.required_stages)do
  if not requirement.met and requirement.stage==plan.stage then return true end
 end
 return false
end

-- Walk authored edges with the fixed roster. Keep the first transition on each shortest path.
local function walk(session,visit,from,graph,with_completion_routes)
 local Catalog=require('SceneZOI.Catalog');local Binding=require('SceneZOI.Binding')
 local nodes=Catalog.get_snapshot().nodes
 local restrictions=session.plan and session.plan.auto_restrictions
 from=from or session.node
 local visited,queue,head={[from.id]=true},{{node=from,depth=0}},1
 local eligible,bounded={},false
 while head<=#queue do
  local row=queue[head];head=head+1
  if visit and row.depth>0 and visit(row)then return end
  local edges=row.node.kind=='transition'and {{target=row.node.destination}}or row.node.navigation or {}
  if with_completion_routes then
   edges={}
   for _,target in ipairs(targets(row.node,true))do edges[#edges+1]={target=target}end
  end
  local outgoing
  if graph then outgoing={};graph[row.node.id]=outgoing end
  for _,edge in ipairs(edges)do
   local id=edge.target
   if eligible[id]==nil then
    local target=nodes[id]
    eligible[id]=target~=nil and V.equal(target.furniture,session.node.furniture)and
     allowed(nodes,target,session.session_restrictions,restrictions)and pcall(Binding.resolve,session.participants,target)
   end
   if eligible[id]then
    if outgoing then outgoing[id]=true end
    if not visited[id]then
     if #queue<C.plan_route_limit then
      visited[id]=true
      local node=nodes[id]
      queue[#queue+1]={node=node,depth=row.depth+1,
       first_transition=row.first_transition or (node.kind=='transition' and id or nil)}
     else
      -- The bounded walk may have left additional routes undiscovered.
      bounded=true
     end
    end
   end
  end
 end
 return bounded
end

-- A required loop is worth visiting only if the goals still open can be reached from it.
local function route_out(session,plan,node)
 local missing={}
 each_open(session,plan,function(goal,_,fraction)
  if not advance(session,node,goal,fraction)then missing[goal]=fraction end
 end)
 if next(missing)==nil then return true end
 walk(session,function(row)
  if row.node.kind~='transition'then
   for goal,fraction in pairs(missing)do
    if advance(session,row.node,goal,fraction)then missing[goal]=nil end
   end
  end
  return next(missing)==nil
 end,node)
 return next(missing)==nil
end

-- Worth of a candidate loop for this stage. Nil means it moves nothing the plan still needs.
local function node_value(session,plan,node)
 local value,useful,required=0,false,0
 local has_work=false
 for _,requirement in ipairs(plan.required_stages)do
  if not requirement.met then has_work=true end
  if open_requirement(plan,requirement)and search().matches(node,requirement.match)and route_out(session,plan,node)then
   required=required+1;useful=true
  end
 end
 local least=math.huge
 each_open(session,plan,function(_,progress)least=math.min(least,progress);has_work=true end)
 each_open(session,plan,function(goal,progress,fraction)
  local can,full=advance(session,node,goal,fraction)
  if can then
   useful=true;value=value+1
   if full then value=value+10 end
   if progress<=least then value=value+100 end
  end
 end)
 if has_work and not useful then return nil end
 return value+required*1000+preference_bonus(plan,node,plan_fraction(plan))+hash(node.id,plan.seed),required
end

local function reachable_goals(session,graph,pending)
 if #pending==0 then return {},false end
 local nodes=require('SceneZOI.Catalog').get_snapshot().nodes
 local masks={}
 for id in pairs(graph)do
  local node=id==session.node.id and session.node or nodes[id]
  if node.kind~='transition'then
   local mask=0
   for index,goal in ipairs(pending)do
    local directive=goal_directive(node,role_of(session,goal.participant_id),goal.task_id,session.tasks.registry)
    if TaskData.can_finish(directive)then mask=mask|(1<<(index-1)) end
   end
   masks[id]=mask
  end
 end
 return joint_routes(graph,masks,#pending)
end

local function continues_goals(session,node,advancing_goals)
 for goal,fraction in pairs(advancing_goals)do
  if not advance(session,node,goal,fraction)then return false end
 end
 return true
end

-- Choose the activity, then play its first transition or enter it directly.
function M.route(session,plan,changing_stage,minimum)
 local rows,links,pending={},{},{}
 local walk_bounded=walk(session,function(row)rows[#rows+1]=row end,nil,links)
 local matches=priority_matches(plan,plan.stage)
 if changing_stage and matches then table.insert(rows,1,{node=session.node,depth=0})end
 local advancing_goals={}
 each_open(session,plan,function(goal,_,fraction)
  pending[#pending+1]=goal
  if minimum and advance(session,session.node,goal,fraction)then advancing_goals[goal]=fraction end
 end)
 local solved,bounded=reachable_goals(session,links,pending)
 bounded=bounded or walk_bounded
 local possible,conditional_bounded
 local best
 for _,row in ipairs(rows)do
  local node=row.node
  if node.kind~='transition'and (row.depth>0 or not plan.auto_restrictions or
   search().matches(node,plan.auto_restrictions))then
   local rank=priority(matches,node)
   local value,required=node_value(session,plan,node)
   -- A specifically requested stage loop may lead to progress elsewhere. Once
   -- it has played, ordinary goal navigation can move on from it.
   if not value and changing_stage and rank<math.huge then
    value,required=hash(node.id,plan.seed),0
   end
   if value then
    value=value-row.depth*.01
    -- While this loop is useful, avoid trading one advancing goal for another on every tick.
    if not minimum or (value>minimum and (required>0 or continues_goals(session,node,advancing_goals)))then
     local proven=#pending==0 or solved[node.id]
     if not proven and not possible and not bounded then
      local completion_links={}
      local completion_bounded=walk(session,nil,nil,completion_links,true)
      possible,conditional_bounded=reachable_goals(session,completion_links,pending)
      conditional_bounded=conditional_bounded or completion_bounded
     end
     if proven or bounded or conditional_bounded or (possible and possible[node.id])then
      if not matches then required=0 end
      local candidate={next_node=row.depth>0 and (row.first_transition or node.id) or nil,
       value=value,target=node.id,required=required,priority=rank,
       uncertain=not proven,unplayed=matches~=nil and not (plan.played_groups or {})[variety_key(plan,node)]}
      if preferred(candidate,best)then best=candidate end
     end
    end
   end
  end
 end
 if best then return best.next_node,best.target,best.value end
end

-- After a one-shot finishes, resume the path through its authored destination.
-- Intermediate loops provide connectivity without becoming playback nodes.
function M.next_route_node(session)
 local plan=session.plan
 local target=plan and plan.auto_mode and plan.heading
 if not target or session.node.id==target then return end
 local next_node
 walk(session,function(row)
  if row.node.id==target then next_node=row.first_transition or target;return true end
  return false
 end)
 return next_node
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

local function waiting(plan,reason)
 plan.wait_reason=reason
end

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

-- Goal progress can advance a stage. Decay never takes a stage back.
local function stage_due(session,plan)
 if plan.stage_count<=1 then return plan.stage end
 local due=plan.stage
 if #plan.goals>0 then
  local fastest=plan.stage_progress=='fastest'
  local combine=fastest and math.max or math.min
  local progress=fastest and 0 or 1
  for _,goal in ipairs(plan.goals)do
   local _,fraction=goal_state(session,goal)
   progress=combine(progress,fraction)
  end
  due=math.floor(progress*plan.stage_count)+1
 elseif plan.end_policy.type=='duration'then
  due=math.floor(clock_seconds(plan,plan.end_policy.clock)/plan.end_policy.seconds*plan.stage_count)+1
 end
 return math.max(plan.stage,math.min(due,plan.stage_count))
end

-- A hold or a paused rate is temporary. The no-progress window decides if it never lifts.
local function held(session,plan,node)
 local found=false
 each_open(session,plan,function(goal,_,fraction)
  local directive=goal_directive(node,role_of(session,goal.participant_id),goal.task_id,session.tasks.registry)
  if directive and directive.rate>0 and(Control.task(session,goal.participant_id,goal.task_id)<=0 or
   (fraction>=1 and TaskData.can_finish(directive)))then found=true end
 end)
 return found
end

-- This loop still does something, but a requirement or the slowest goal needs another one.
local function wants_move(session,plan,node)
 for _,requirement in ipairs(plan.required_stages)do
  if open_requirement(plan,requirement)and not search().matches(node,requirement.match)then return true end
 end
 local least,lagging=math.huge,false
 each_open(session,plan,function(goal,progress,fraction)
  if progress<least then least,lagging=progress,not advance(session,node,goal,fraction)end
 end)
 return lagging
end

function M.tick(session,dt,scale)
 local plan=session.plan
 if not plan or plan.state=='finished'or session.preparing or session.stopping or scale<=0 or dt<=0 then return nil end
 if plan.played_groups and session.node.kind=='loop'and plan.last_played_loop~=session.node.id then
  plan.played_groups[variety_key(plan,session.node)]=true
  plan.last_played_loop=session.node.id
 end
 if not plan.auto_mode then return nil end
 plan.wait_reason=nil
 plan.real_used=plan.real_used+dt;plan.game_used=plan.game_used+dt*scale
 if session.node.kind=='transition'then return waiting(plan,'transition_playing')end
 local auto_allowed=not plan.auto_restrictions or search().matches(session.node,plan.auto_restrictions)
 local earned=auto_allowed and credit_stage(session,plan)
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
  if timed then return waiting(plan,'duration_remaining')end
  if policy.type=='goals'then
   local stay=plan.completed_goals_manually and 0 or (plan.post_completion_stay_seconds or 0)
   if not plan.goals_reached_game_seconds then plan.goals_reached_game_seconds=plan.game_used end
   -- The native simulation clock governs the stay while authored responses run alongside it.
   if settled(session) and plan.game_used-plan.goals_reached_game_seconds>=stay then return finish(plan,'ok','goals_met')end
   plan.state='resolving'
   return waiting(plan,'completion_response_or_stay')
  end
  if not settled(session)then plan.state='resolving';return waiting(plan,'completion_response')end
  if plan.state~='waiting'then plan.state='waiting';return {event='plan_goals_met',reason='goals_satisfied'}end
  plan.wait_age=plan.wait_age+dt
  if plan.wait_age>=C.plan_wait_seconds then return finish(plan,'owner_expired','wait_expired')end
  return waiting(plan,'waiting_for_addon')
 end
 if not timed then
  for _,requirement in ipairs(plan.required_stages)do
   if not requirement.met and requirement.stage and requirement.stage<plan.stage then return finish(plan,'required_stage_unavailable')end
  end
 end
 if not settled(session)then return waiting(plan,'completion_response')end
 if not auto_allowed then
  local next_node,target=M.route(session,plan)
  if not next_node then return finish(plan,'scene_restricted')end
  plan.heading=target
  return {navigate=next_node,reason='auto_restriction'}
 end
 if plan.heading then
  local next_node=M.next_route_node(session)
  if next_node then return {navigate=next_node,reason='follow_planned_route'}end
  plan.heading=nil
 end
 if plan.stage_played and stage_due(session,plan)>plan.stage and(timed or not stage_bound_open(plan))then
  plan.stage,plan.stage_played=plan.stage+1,false
  local next_node,target=M.route(session,plan,true)
  plan.heading=target
  local reason=#plan.goals>0 and 'goal_progress_threshold' or 'duration_threshold'
  return {event='plan_stage_changed',navigate=next_node,reason=reason}
 end
 if not has_targets then return waiting(plan,timed and 'duration_or_stage_remaining' or 'waiting_for_addon')end
 local moved=false
 each_open(session,plan,function(goal,progress)
  local key=goal.participant_id..'|'..goal.task_id
  if progress>(plan.marks[key]or -1)+1e-6 then plan.marks[key],moved=progress,true end
 end)
 plan.stall_age=moved and 0 or plan.stall_age+dt
 if plan.stall_age>=C.plan_no_progress_seconds and not timed then return finish(plan,'no_progress')end
 local stuck=not advancing(session,plan,session.node)
 if not stuck and not wants_move(session,plan,session.node)then return waiting(plan,'goal_progress')end
 local here=not stuck and node_value(session,plan,session.node) or nil
 local next_node,target=M.route(session,plan,false,here)
 if next_node then
  plan.heading=target;return {navigate=next_node,reason=stuck and 'goal_cannot_progress_here' or 'better_goal_route'}
 end
 -- A timed plan runs its time and reports what it did not reach.
 if not stuck then return waiting(plan,'goal_progress')end
 if timed then return waiting(plan,'duration_remaining_without_goal_route')end
 if held(session,plan,session.node)then return waiting(plan,'task_rate_or_completion_on_hold')end
 if not goals_done then return finish(plan,'goal_unreachable')end
 return finish(plan,'required_stage_unavailable')
end

function M.rate_factor(session)
 local plan=session.plan
 return plan and plan.auto_mode and plan.task_progress_multiplier or 1
end
-- Auto-mode holds fulfilled tasks while the scene resolves or its add-on decides.
function M.frozen(session,participant_id,task_id)
 local plan=session.plan
 if not plan or not plan.auto_mode or(plan.state~='waiting'and plan.state~='resolving')then return false end
 local goal=goal_for(session,participant_id,task_id)
 return goal and (goal_state(session,goal)) or false
end
function M.locked(session)return session.plan~=nil and session.plan.auto_mode==true and session.plan.state~='finished'end

-- The animation ramp for this stage. Task rates stay on game time.
function M.speed_index(session)
 local plan=session.plan
 if not plan or not plan.auto_mode or not plan.auto_speed then return end
 local speeds=C.playback_speeds
 local start,finish,minimum
 if plan.auto_speed==true then
  if plan.stage_count==1 then return 2 end
  start,finish=speeds[1],speeds[#speeds]
 else
  start,finish,minimum=plan.auto_speed.start,plan.auto_speed.finish,plan.auto_speed.minimum
 end
 local target=start+(finish-start)*plan_fraction(plan)
 if minimum then target=math.max(target,minimum) end
 local closest=1
 for index=2,#speeds do
  if target<(speeds[index-1]+speeds[index])/2 then break end
  closest=index
 end
 return closest
end

-- Manual takeover keeps everything; turning it back on re-evaluates from the current state.
function M.set_auto(session,enabled)
 local plan=session.plan
 if not plan or plan.state=='finished'or plan.auto_mode==enabled then return false end
 plan.auto_mode,plan.heading=enabled,nil
 if enabled then
  plan.stall_age,plan.marks=0,{}
  if session.revision~=plan.handover_revision then plan.manual_revision=session.revision end
  if plan.manual_goals_pending and goals_met(session,plan)then
   plan.completed_goals_manually=true
   if requirements_met(plan)then plan.state='resolving' end
  end
  plan.manual_goals_pending=nil
 else
  plan.handover_revision=session.revision
  -- An already satisfied goal set keeps its original automatic stay.
  plan.manual_goals_pending=plan.skip_post_completion_stay_after_manual and not goals_met(session,plan) or nil
 end
 return true
end

function M.snapshot(session)
 local plan=session.plan
 if not plan then return nil end
 local goals=J.array({})
 for _,goal in ipairs(plan.goals)do
  local satisfied,progress,completed=goal_state(session,goal)
  goals[#goals+1]={participant_id=goal.participant_id,task_id=goal.task_id,requested=goal.completions,
   completed=completed,progress=progress,satisfied=satisfied}
 end
 local required=J.array({})
 for _,requirement in ipairs(plan.required_stages)do required[#required+1]={stage=requirement.stage,met=requirement.met}end
 return {auto_mode=plan.auto_mode,state=plan.state,outcome=plan.outcome,end_policy=V.copy(plan.end_policy),goals=goals,
  required_stages=required,stage=plan.stage,stage_count=plan.stage_count,task_progress_multiplier=plan.task_progress_multiplier,
  real_seconds=plan.real_used,game_seconds=plan.game_used,post_completion_stay_seconds=plan.post_completion_stay_seconds,route_uncertain=plan.route_uncertain==true}
end
return M

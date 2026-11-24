-- Autonomous plans: validation, feasibility, goals, caps, end policies, clocks and bounds.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local nodes={}
local task_registry=dofile('tests/support/task-registry.lua')
local registry=task_registry({charge={maximum=100}})
local data={nodes=nodes,tasks=registry}
package.loaded['SceneZOI.Settings']={task_multiplier=function()return 1 end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return data end}
local J=require('SceneZOI.Json');local Tasks=require('SceneZOI.Tasks');local Plan=require('SceneZOI.Plan');local C=require('SceneZOI.Config')
local function refused(args,expected)
 local ok,err=pcall(Plan.parse,args,registry.definitions,{'1','2'},{tags={},actions={}})
 assert(not ok and tostring(err):find(expected,1,true),'Expected '..expected..', got '..tostring(err))
end
local function node(id,tasks,edges,extra)
 local out={id=id,kind='loop',participants={lead={body='male'},partner={body='female'}},tracks={lead='a',partner='b'},anchor_participant='lead',navigation=J.array({}),tasks=tasks}
 for i,target in ipairs(edges or {})do out.navigation[i]={id='to.'..target,target=target}end
 for k,v in pairs(extra or {})do out[k]=v end
 nodes[id]=out
 return out
end
local function full(rate)return {charge={rate=rate or 10}}end
local function capped(rate,percent)return {charge={rate=rate or 10,cap_percent=percent}}end
node('hub',nil,{'light','both'},{starting_hub=true})
node('light',{lead=full(),partner=capped(10,50)},{'hub','both'})
node('both',{lead=full(),partner=full()},{'hub'})
node('still',{},{},{starting_hub=true})
node('explicit',{lead=full(),partner=full()},{},{content_rating='EXPLICIT'})
local people={{id='1',body='male'},{id='2',body='female'}}
local function row(id)return {scene_id=id,bindings={lead='1',partner='2'}}end
local function spec_of(args)return Plan.parse(args,registry.definitions,{'1','2'},{tags={},actions={}})end
local goal_lead={participant_id='1',task_id='charge'}
local goal_partner={participant_id='2',task_id='charge'}

-- Requests are validated before anything is held.
refused({goals={{participant_id='9',task_id='charge'}}},'participant_not_found')
refused({goals={{participant_id='1',task_id='nope'}}},'task_not_found')
refused({goals={goal_lead,goal_lead}},'Duplicate goal')
refused({goals={{participant_id='1',task_id='charge',completions=0}}},'Invalid')
refused({goals={{participant_id='1',task_id='charge',completions=1.5}}},'Invalid')
refused({},'An end policy is required')
refused({end_policy={type='goals'}},'Ending on goals requires goals')
refused({end_policy={type='duration'}},'Invalid')
refused({end_policy={type='duration',seconds=10,clock='wall'}},'Invalid plan clock')
refused({end_policy={type='duration',seconds=99999}},'Invalid')
refused({goals={goal_lead},task_progress_multiplier=0},'Invalid')
refused({goals={goal_lead},task_progress_multiplier=9},'Invalid')
refused({goals={goal_lead},stage_progress='average'},'Invalid stage progress')
refused({end_policy={type='duration',seconds=5},stage_progress='fastest'},'Stage progress requires goals')
assert(spec_of({goals={goal_lead}}).end_policy.type=='goals','Goals end on goals by default')
assert(spec_of({end_policy={type='duration',seconds=5}}).end_policy.clock=='game','Game time is the default clock')
assert(spec_of({goals={goal_lead}}).goals[1].completions==1,'One completion by default')

-- Feasibility looks at the authored graph from the entry.
local function picked(args,rows,restrictions)return Plan.pick_entry(data,spec_of(args),rows,people,restrictions or {})end
assert(picked({goals={goal_lead}},{row('hub')}).scene_id=='hub','A hub that leads to a finishing scene is viable')
local chosen=picked({goals={goal_lead,goal_partner}},{row('hub'),row('light'),row('both')})
assert(chosen.scene_id=='both','The entry that finishes every goal wins over a capped one')
local ok,err=pcall(picked,{goals={goal_lead}},{row('still')});assert(not ok and tostring(err):find('goal_unreachable',1,true),'Nothing can finish from here')
ok,err=pcall(picked,{goals={goal_lead}},{});assert(not ok and tostring(err):find('no_matching_scenes',1,true))
-- A restriction that removes the only finishing scene is a refusal, never relaxed.
for _,n in pairs(nodes)do n.content_rating=n.content_rating or 'GENERAL'end
ok,err=pcall(picked,{goals={goal_partner}},{row('light')},{allowed_content_ratings={'GENERAL','NOT_BOTH'},excluded_tags={}})
assert(ok,'Control: the unrestricted partner goal is reachable through both')
nodes.both.content_rating='EXPLICIT'
ok,err=pcall(picked,{goals={goal_partner}},{row('light')},{allowed_content_ratings={'GENERAL'}})
assert(not ok and tostring(err):find('goal_unreachable',1,true),'The cap cannot finish it and the finishing scene is ruled out')
nodes.both.content_rating='GENERAL'
assert(picked({end_policy={type='duration',seconds=5}},{row('still')}).scene_id=='still','A timed plan needs no task data')

local actions
local function session(args,start)
 local participants={{id='1',role='lead',body='male'},{id='2',role='partner',body='female'}}
 local start_node=nodes[start or 'hub']
 local s={token='s.1',revision=1,node=start_node,participants=participants,
  tasks=Tasks.new(registry,participants,start_node),session_restrictions={},preparing=false}
 local spec=spec_of(args);spec.seed=7
 s.plan=Plan.new(spec)
 actions={navigations=0}
 return s
end
local function step(s,count,dt,scale)
 for _=1,count do
  Tasks.update(s.tasks,s,dt*(scale or 1),function()end)
  local action=Plan.tick(s,dt,scale or 1)
  if action then
   if action.event then actions[#actions+1]=action.event end
   if action.stop then actions.stop=action.stop;return action end
   if action.navigate then
    s.node=assert(nodes[action.navigate],'A plan navigates to a declared playback node')
    s.revision=s.revision+1;actions.navigations=actions.navigations+1
   end
  end
 end
end
local frame=.016

-- A goal plan immediately leaves a node that moves nothing, then ends once the goal is met.
local s=session({goals={goal_lead}});assert(Plan.locked(s),'Manual navigation is refused while a plan drives')
step(s,1,frame);assert(s.node.id=='both'or s.node.id=='light','A motionless hub is left on the first tick')
step(s,30,1);assert(actions.stop=='ok'and s.plan.outcome=='goals_met')
local snap=Plan.snapshot(s);assert(snap.goals[1].satisfied and snap.goals[1].completed==1 and snap.goals[1].requested==1 and snap.state=='finished')
assert(not Plan.locked(s))

-- A cap stops a goal: the plan moves to a node that can finish it.
s=session({goals={goal_partner}},'light')
step(s,4,1);assert(s.node.id=='light'and s.tasks.participants['2'].charge.value==40)
step(s,1,1);assert(s.tasks.participants['2'].charge.value==50,'The cap holds')
assert(s.node.id=='both','Reassessed once the cap stopped the goal')
step(s,20,1);assert(actions.stop=='ok'and s.tasks.participants['2'].charge.completions==1)

-- Least-progressed first: at the hub both are at zero and the finishing node wins.
s=session({goals={goal_lead,goal_partner}});step(s,1,frame);assert(s.node.id=='both')

-- Repeated completions count, and progress is continuous across a reset.
s=session({goals={{participant_id='1',task_id='charge',completions=2}}},'both')
step(s,5,1);snap=Plan.snapshot(s);assert(math.abs(snap.goals[1].progress-.25)<.001,'Half a meter of a two-completion goal')
step(s,5,1);snap=Plan.snapshot(s);assert(snap.goals[1].completed==1 and math.abs(snap.goals[1].progress-.5)<.001 and not snap.goals[1].satisfied)
step(s,10,1);assert(actions.stop=='ok')
assert(s.tasks.participants['1'].charge.completions==2)

-- The multiplier changes how fast a goal fills, not the animation, and only under the plan.
s=session({goals={goal_lead},task_progress_multiplier=2},'both');step(s,3,1);assert(s.tasks.participants['1'].charge.value==60)
assert(Tasks.inspect(s.tasks,s)[1].plan_rate_multiplier==2)
s.plan.auto_mode=false;step(s,1,1);assert(s.tasks.participants['1'].charge.value==70,'A manual takeover removes the plan multiplier')

-- A stalled plan ends instead of playing forever. Decay never counts as progress.
s=session({goals={goal_lead}},'both');s.tasks.participants['1'].charge.value=100
local stalled
for _=1,math.floor(C.plan_no_progress_seconds)+2 do stalled=Plan.tick(s,1,1) or stalled end
assert(stalled.stop=='no_progress'and s.plan.outcome=='no_progress')
-- Caps and restrictions can leave nothing to do: end cleanly rather than switch forever.
s=session({goals={goal_lead}},'still');step(s,1,frame);assert(actions.stop=='goal_unreachable')
nodes.both.content_rating='EXPLICIT'
s=session({goals={goal_partner}},'light');s.session_restrictions={allowed_content_ratings={'GENERAL'}}
step(s,6,1);assert(actions.stop=='goal_unreachable','A restriction is never relaxed to rescue a run')
nodes.both.content_rating='GENERAL'

-- Clocks: at 3x a game-time plan finishes in a third of the real time; a real-time plan does not.
local function seconds_until_end(clock,scale)
 s=session({end_policy={type='duration',seconds=30,clock=clock}},'still')
 local used=0
 while not actions.stop and used<200 do step(s,1,.5,scale);used=used+.5 end
 return used
end
assert(seconds_until_end('game',1)==30 and seconds_until_end('real',1)==30)
assert(seconds_until_end('game',3)==10,'Game time at 3x takes a third as long')
assert(seconds_until_end('real',3)==30,'Real playback time ignores game speed')
assert(actions.stop=='ok'and s.plan.outcome=='duration_elapsed')
-- Neither clock runs while paused or preparing.
s=session({end_policy={type='duration',seconds=5}},'still')
step(s,20,1,0);assert(s.plan.game_used==0 and s.plan.real_used==0 and not actions.stop,'A pause is not playback')
s.preparing=true;step(s,20,1);s.preparing=false;assert(s.plan.game_used==0)
-- Time runs out first: unmet goals are reported.
s=session({goals={goal_lead},end_policy={type='duration',seconds=2}},'still');step(s,3,1)
assert(actions.stop=='ok'and s.plan.outcome=='duration_elapsed'and not Plan.snapshot(s).goals[1].satisfied)

-- Add-on ending: the milestone is published once, the fulfilled task stops, the loop holds.
s=session({goals={goal_lead},end_policy={type='addon'}},'both')
step(s,9,1);assert(#actions==0 and s.tasks.participants['1'].charge.completions==0)
step(s,1,1);assert(actions[1]=='plan_goals_met'and s.plan.state=='waiting')
step(s,3,1);assert(#actions==1,'The milestone is published once')
assert(s.tasks.participants['1'].charge.value==0 and Plan.frozen(s,'1','charge'),'A fulfilled task does not complete again')
assert(Tasks.inspect(s.tasks,s)[1].effective_rate==0)
assert(s.tasks.participants['2'].charge.value>0,'Others are unaffected')
local before=s.node;step(s,2,frame);assert(s.node==before and not actions.stop,'The last loop holds while the add-on decides')
-- An owner that never calls stop does not hold the scene forever.
step(s,math.floor(C.plan_wait_seconds)+2,1);assert(actions.stop=='owner_expired'and s.plan.outcome=='wait_expired')
-- An add-on plan with neither goals nor a timer stays where it is.
s=session({end_policy={type='addon'}},'still');step(s,2,frame);assert(s.node.id=='still'and not actions.stop)

-- A transition plays out: the clock counts it, nothing navigates or ends during it.
s=session({end_policy={type='duration',seconds=2}},'still');s.node={id='t',kind='transition',destination='still',participants=s.node.participants}
step(s,5,1);assert(not actions.stop and s.plan.game_used==5)
s.node=nodes.still;step(s,1,1);assert(actions.stop=='ok','It ends once the transition has resolved')
-- A completion response resolves first.
s=session({goals={goal_lead}},'both');s.completion_effects={motion={}};step(s,12,1);assert(not actions.stop,'Waits for the response')
s.completion_effects=nil;step(s,1,1);assert(actions.stop=='ok')

-- A fractional stay overlaps the response and follows changes to native game speed.
s=session({goals={goal_lead},post_completion_stay_seconds=2.5,skip_post_completion_stay_after_manual=true},'both')
s.completion_effects={motion={}}
step(s,5,1,2)
assert(s.plan.state=='resolving' and not actions.stop)
assert(Plan.snapshot(s).post_completion_stay_seconds==2.5)
local reached_game,reached_real=s.plan.game_used,s.plan.real_used
assert(reached_game==10 and reached_real==5)
assert(not Plan.tick(s,5,0),'Pause does not consume the stay')
Plan.set_auto(s,false)
assert(not Plan.tick(s,5,3),'Manual takeover does not consume the stay')
Plan.set_auto(s,true)
assert(s.plan.game_used==reached_game and s.plan.real_used==reached_real)
s.completion_effects=nil
assert(not Plan.tick(s,.5,3),'Half a second at 3x consumes 1.5 seconds of the stay')
assert(not Plan.tick(s,.75,1),'Switching back to 1x leaves a quarter second')
assert(Plan.tick(s,.25,1).stop=='ok' and s.plan.outcome=='goals_met')
assert(s.plan.game_used-reached_game==2.5 and s.plan.real_used-reached_real==1.5)
assert(s.tasks.participants['1'].charge.completions==1)
s=session({goals={goal_lead},post_completion_stay_seconds=2.5},'both');s.completion_effects={motion={}}
step(s,8,1,2);assert(s.plan.state=='resolving' and not actions.stop,'A longer response still finishes at higher game speed')
s.completion_effects=nil;assert(Plan.tick(s,.1,1).stop=='ok')
refused({goals={goal_lead},post_completion_stay_seconds=-1},'Invalid')
refused({goals={goal_lead},post_completion_stay_seconds=1,end_policy={type='addon'}},'Post-completion stay')
refused({goals={goal_lead},post_completion_stay_seconds=1,end_policy={type='duration',seconds=5}},'Post-completion stay')

-- The overall playback budget is separate from the stall timer.
s=session({end_policy={type='addon'}},'still');step(s,1,C.plan_max_playback_seconds+1);assert(actions.stop=='playback_budget_exceeded')
-- While a finished scene resolves its completion response, a fulfilled task must not complete again.
s=session({goals={goal_lead}},'both');s.completion_effects={motion={}};step(s,30,1)
assert(s.tasks.participants['1'].charge.completions==1 and s.plan.state=='resolving','No extra completion while waiting to end')
assert(Plan.set_auto(s,false) and not Plan.frozen(s,'1','charge'),'Manual control releases plan task holds')
step(s,10,1);assert(s.tasks.participants['1'].charge.completions==2 and not actions.stop)

-- Stages: the count is chosen once, from the requested range, and reported.
local function plan_spec(args)local spec=spec_of(args);spec.seed=11;return spec end
local spec=plan_spec({end_policy={type='addon'},stages={min=2,max=5}})
Plan.pick_entry(data,spec,{row('still')},people,{})
assert(spec.stage_count>=2 and spec.stage_count<=5,'A count from the range')
local chosen_count=spec.stage_count
Plan.pick_entry(data,spec,{row('still')},people,{});assert(spec.stage_count==chosen_count,'Chosen once and kept')
refused({end_policy={type='addon'},stages=0},'Invalid')
refused({end_policy={type='addon'},stages={min=4,max=2}},'Invalid')
local function staged(args,start,count)
 local out=session(args,start);out.plan.stage_count=count or 1
 return out
end
-- The slowest goal sets the stage, and at an exact boundary the next stage is due.
local function at(goal_a,goal_b)
 local out=staged({goals={goal_lead,goal_partner},stages=4},'both',4)
 out.tasks.participants['1'].charge.value=goal_a;out.tasks.participants['2'].charge.value=goal_b
 return out
end
s=at(80,35);step(s,2,.001);assert(s.plan.stage==2,'80% and 35% of their goals is stage 2')
s=at(90,25);step(s,2,.001);assert(s.plan.stage==2,'Exactly 25% means the next stage is due')
s=at(90,24.9);step(s,1,.001);assert(s.plan.stage==1)
-- The fastest goal can drive the speed and stage while the other goal is still open.
s=staged({goals={goal_lead,goal_partner},stages=4,stage_progress='fastest'},'both',4)
s.tasks.participants['2'].charge.value=25
step(s,1,.001)
assert(s.plan.stage==2 and Plan.speed_index(s)==2,'The leading partner sets the stage and speed')
s.tasks.participants['2'].charge.completions=1
for _=1,8 do step(s,1,.001)end
assert(s.plan.stage==4 and Plan.speed_index(s)==4 and not actions.stop,'One completion advances the stages while the other goal stays open')
-- Decay cannot move a stage back.
s=at(80,35);step(s,2,.001);assert(s.plan.stage==2);s.tasks.participants['2'].charge.value=1;step(s,3,.001);assert(s.plan.stage==2,'Once entered, a stage is kept')
-- Several boundaries at once are entered one at a time, each with a playing update.
s=at(99,99);local stages={}
for _=1,8 do step(s,1,.001);stages[#stages+1]=s.plan.stage end
assert(s.plan.stage==4,'Queued stages are all reached')
local jumps=0;for i=2,#stages do local d=stages[i]-stages[i-1];assert(d<=1,'One stage per playing update');jumps=jumps+d end
-- Required stages: a selector must have its loop actually play.
local function rated(id,rating,edges)node(id,{lead=full(1),partner=full(1)},edges,{content_rating=rating})end
rated('a','GENERAL',{'b','c'});rated('b','SUGGESTIVE',{'a','c'});rated('c','EXPLICIT',{'a','b'})
local suggestive={allowed_content_ratings={'SUGGESTIVE'}}
local explicit={allowed_content_ratings={'EXPLICIT'}}
ok,err=pcall(picked,{goals={goal_lead},required_stages={{match=suggestive}}},{row('still')})
assert(not ok,'A requirement nothing reachable can satisfy is refused')
refused({goals={goal_lead},required_stages={{stage=3,match=suggestive}},stages={min=2,max=4}},'required_stage_unavailable')
refused({goals={goal_lead},required_stages={{stage=2}}},'')
-- A requirement that restrictions rule out is a structured refusal.
ok,err=pcall(picked,{goals={goal_lead},required_stages={{match=explicit}}},{row('a')},{allowed_content_ratings={'GENERAL','SUGGESTIVE'}})
assert(not ok and tostring(err):find('required_stage_unavailable',1,true))
-- Credit comes from the loop playing in that stage, not from a transition or a repeat.
s=staged({goals={goal_lead},required_stages={{match=suggestive}}},'a')
assert(not s.plan.required_stages[1].met)
s.node=nodes.b;step(s,1,.5);assert(s.plan.required_stages[1].met,'Playing the matching loop earns it')
s=staged({goals={goal_lead},required_stages={{match=explicit}}},'a')
s.node={id='t',kind='transition',destination='c',content_rating='EXPLICIT',participants=s.node.participants};step(s,3,.5);assert(not s.plan.required_stages[1].met,'A transition earns nothing')
-- A goal met early still has to play what is required.
s=staged({goals={goal_lead},required_stages={{match=suggestive}}},'c');s.tasks.participants['1'].charge.value=99.9
step(s,1,1);assert(s.tasks.participants['1'].charge.completions==1 and not actions.stop,'Not done until the required stage has played')
assert(s.node.id=='b','It moves to the loop the requirement needs immediately')
step(s,1,.5);assert(actions.stop=='ok'and s.plan.outcome=='goals_met')
-- Fast progress does not pass a stage whose required loop has not played while there is a way to it: the stage
-- stays until that loop plays, then the next one is entered.
s=staged({goals={goal_lead,goal_partner},stages=3,required_stages={{stage=1,match=suggestive}}},'a',3)
s.tasks.participants['1'].charge.value=50;s.tasks.participants['2'].charge.value=50
step(s,1,frame)
assert(not actions.stop and s.plan.stage==1 and s.node.id=='b','Enter the required loop before advancing, even when the next stage is already due')
step(s,1,frame)
assert(s.plan.required_stages[1].met and s.plan.stage==2 and not actions.stop,'Playing the required loop lets the next stage begin')
-- With no way to the required loop, the safety stop still ends the plan.
node('island',{lead=full(1),partner=full(1)},{},{content_rating='GENERAL'})
s=staged({goals={goal_lead,goal_partner},stages=3,required_stages={{stage=1,match=suggestive}}},'island',3)
s.tasks.participants['1'].charge.value=50;s.tasks.participants['2'].charge.value=50
step(s,300,1);assert(actions.stop=='required_stage_unavailable','An unreachable required loop still ends the plan: '..tostring(actions.stop))
-- Preferences rank what is eligible, by the fraction of the chosen count.
local preference={{from=0,to=.4,match=suggestive},{from=.6,to=1,match=explicit}}
local early=plan_spec({goals={goal_lead},stages=4,stage_preferences=preference});early.stage_count=4
assert(Plan.pick_entry(data,early,{row('a'),row('b'),row('c')},people,{}).scene_id=='b','Early in the plan the early preference wins')
s=staged({goals={goal_lead,goal_partner},stages=4,stage_preferences=preference},'b',4);s.plan.stage=4
assert(Plan.route(s,s.plan)=='c','Late in the plan the late preference wins')
-- Ordered stage choices are stronger than goal score and fall through when needed.
local goals={goal_lead,goal_partner}
local ordered_start={{stage=1,matches={suggestive,explicit}}}
refused({goals=goals,stage_priorities={}},'Stage priorities need')
refused({goals=goals,stages=2,stage_priorities={{stage=2,matches={}}}},'needs at least one match')
refused({goals=goals,stages={min=1,max=2},stage_priorities={{stage=2,matches={explicit}}}},'Invalid numeric value')
refused({goals=goals,stage_priorities={ordered_start[1],ordered_start[1]}},'Duplicate stage priority')
node('priority.open',{lead=full(1),partner=capped(1,50)},{'c'},{content_rating='SUGGESTIVE'})
assert(picked({goals=goals,stage_priorities=ordered_start},{row('priority.open'),row('c')}).scene_id=='priority.open')
assert(picked({goals=goals,stage_priorities=ordered_start},{row('c'),row('a')}).scene_id=='c','Try the next match when the first has no candidates')
assert(picked({goals=goals,stage_priorities=ordered_start,required_stages={{stage=1,match=explicit}}},{row('b'),row('c')}).scene_id=='c',
 'An ordered preference cannot override a mandatory stage')

-- A different authored position wins within the best tier. The current loop
-- stays available even when the graph offers a lower-ranked unplayed loop.
rated('closing.first','EXPLICIT',{'closing.copy','closing.second','closing.fallback'})
rated('closing.copy','EXPLICIT',{'closing.first'})
rated('closing.second','EXPLICIT',{'closing.first'})
rated('closing.fallback','SUGGESTIVE',{'closing.first'})
local function last_stage(start)
 local out=staged({goals=goals,stages=4,stage_priorities={{stage=4,matches={explicit,suggestive}}},
  variety_groups={['closing.first']='position.one',['closing.copy']='position.one'}},start,4)
 out.plan.stage=3
 out.tasks.participants['1'].charge.value=75
 out.tasks.participants['2'].charge.value=75
 return out
end
s=last_stage('closing.first')
step(s,1,.01)
assert(s.plan.stage==4 and s.node.id=='closing.second','An unplayed position beats a different loop in a played position')
nodes['closing.first'].navigation={{id='fallback',target='closing.fallback'}}
s=last_stage('closing.first')
step(s,2,.01)
assert(s.plan.stage==4 and s.node.id=='closing.first' and actions.navigations==0,'Keep the only suitable closing loop')
node('priority.interlude',nil,{'closing.first'},{content_rating='SUGGESTIVE'})
nodes['closing.first'].navigation={{id='interlude',target='priority.interlude'}}
s=last_stage('closing.first')
s.plan.stage_priorities[1].matches={suggestive,explicit}
step(s,1,.01)
assert(s.node.id=='priority.interlude','A preferred stage loop can lead to another loop that completes the goals')
step(s,1,frame)
assert(s.node.id=='closing.first','Goal recovery leaves the interlude when it has played')

-- Preflight and playback require one directed route that covers both goals.
node('joint.hub',nil,{'joint.first','joint.last'})
node('joint.first',{lead=full(1)},{},{content_rating='SUGGESTIVE'})
node('joint.last',{partner=full(1)},{},{content_rating='EXPLICIT'})
ok,err=pcall(picked,{goals=goals},{row('joint.hub')})
assert(not ok and tostring(err):find('goal_unreachable',1,true),'Mutually exclusive one-way branches cannot be combined')
nodes['joint.first'].navigation={{id='finish.other',target='joint.last'}}
local joint_spec=spec_of({goals=goals})
assert(Plan.pick_entry(data,joint_spec,{row('joint.hub')},people,{}).scene_id=='joint.hub'and not joint_spec.route_uncertain,
 'A directed route can complete one goal and then the other')
s=session({goals=goals,stage_priorities={{stage=1,matches={explicit,suggestive}}}},'joint.hub')
step(s,1,frame)
assert(s.node.id=='joint.first','The preferred one-way dead end cannot strand an open goal')
s.tasks.participants['1'].charge.completions=1
step(s,1,frame)
assert(s.node.id=='joint.last','After the first goal, the route can enter the last loop')

-- Excluded intermediate nodes cannot be used to reach an allowed loop.
node('auto.hub',nil,{'auto.blocked','auto.finish'},{content_rating='GENERAL'})
node('auto.blocked',nil,{'auto.finish'},{content_rating='EXPLICIT'})
node('auto.finish',{lead=full(1),partner=full(1)},{'auto.hub'},{content_rating='GENERAL'})
local auto_filter={allowed_content_ratings={'GENERAL'}}
local auto_spec=spec_of({goals=goals,auto_restrictions=auto_filter})
assert(Plan.pick_entry(data,auto_spec,{row('auto.hub')},people,{}).scene_id=='auto.hub')
s=session({goals=goals,auto_restrictions=auto_filter},'auto.blocked')
step(s,1,.01)
assert(s.node.id=='auto.finish','Resuming Auto leaves the restricted manual loop via a permitted edge')
nodes['auto.hub'].navigation={{id='blocked',target='auto.blocked'}}
ok,err=pcall(Plan.pick_entry,data,auto_spec,{row('auto.hub')},people,{})
assert(not ok and tostring(err):find('goal_unreachable',1,true),'Auto-only restrictions apply to the complete route')
-- A stage change prefers a different loop, and keeps the current one when it is the only choice.
s=staged({goals={goal_lead,goal_partner},stages=2},'a',2)
s.tasks.participants['1'].charge.value=49;s.tasks.participants['2'].charge.value=49;step(s,2,1)
assert(s.plan.stage==2 and s.node.id~='a','A new stage plays a different loop')
s=session({end_policy={type='duration',seconds=10},stages=2},'still');s.plan.stage_count=2
step(s,12,.5);assert(s.plan.stage==2 and s.node.id=='still','The only loop is reused')
-- Nodes that only connect the route are bypassed when the stage changes.
node('x',{lead=full(1),partner=full(1)},{'h'});node('h',nil,{'x','y'});node('y',{lead=full(1),partner=capped(1,50)},{'h'})
s=staged({goals={goal_lead,goal_partner},stages=2},'x',2)
s.tasks.participants['1'].charge.value=49;s.tasks.participants['2'].charge.value=49
step(s,1,1);assert(s.plan.stage==2 and s.node.id=='y' and actions.navigations==1,'A route through the hub goes straight to the destination')
-- A timed plan with no goals divides its duration evenly across stages.
s=session({end_policy={type='duration',seconds=8},stages=4},'a');s.plan.stage_count=4
step(s,3,1);assert(s.plan.stage==2);step(s,2,1);assert(s.plan.stage==3,'Even division of the duration')
-- Each stage selects a player preset, including for older fractional profiles.
s=session({end_policy={type='addon'},stages=4},'still');s.plan.stage_count=4
for stage=1,4 do s.plan.stage=stage;assert(Plan.speed_index(s)==stage)end
s=session({end_policy={type='addon'}},'still');assert(Plan.speed_index(s)==2,'A single stage defaults to normal speed')
s=session({end_policy={type='addon'},stages=4,auto_speed={start=1,finish=1.3}},'still');s.plan.stage_count=4
assert(Plan.speed_index(s)==2);s.plan.stage=4;assert(Plan.speed_index(s)==3)
refused({end_policy={type='addon'},auto_speed={start=.1,finish=1}},'Invalid')
s=session({end_policy={type='addon'},auto_speed=false},'still');assert(Plan.speed_index(s)==nil,'The player can keep speed control')
-- Manual takeover: nothing automatic happens, the clock stops, and turning it back on re-evaluates.
s=session({goals={goal_lead},task_progress_multiplier=2,end_policy={type='duration',seconds=100}},'hub')
assert(Plan.set_auto(s,false)and not Plan.locked(s),'Off frees manual navigation')
assert(not Plan.set_auto(s,false),'A repeat changes nothing')
step(s,1,10);assert(s.node.id=='hub'and actions.navigations==0 and s.plan.game_used==0,'No automatic navigation and a stopped clock')
s.node=nodes.both;step(s,1,1);assert(s.tasks.participants['1'].charge.value==10,'No plan multiplier while manual')
assert(Plan.speed_index(s)==nil)
assert(Plan.set_auto(s,true)and Plan.locked(s));step(s,1,1);assert(s.tasks.participants['1'].charge.value==30 and s.plan.game_used==1,'Back on, the plan resumes')
-- Manual play can still finish a goal: resuming then applies the end policy.
s=session({goals={goal_lead}},'both');Plan.set_auto(s,false)
step(s,10,1);assert(s.tasks.participants['1'].charge.completions==1 and not actions.stop)
Plan.set_auto(s,true);step(s,1,.1);assert(actions.stop=='ok'and s.plan.outcome=='goals_met')

local manual_stay={goals={goal_lead,goal_partner},post_completion_stay_seconds=6,skip_post_completion_stay_after_manual=true}
s=session(manual_stay,'both')
s.tasks.participants['1'].charge.completions=1
assert(Plan.set_auto(s,false))
step(s,10,1);assert(s.tasks.participants['2'].charge.completions==1 and not actions.stop)
assert(Plan.set_auto(s,true))
assert(Plan.frozen(s,'2','charge'),'Resuming a completed plan holds the goal before task updates')
s.completion_effects={motion={}}
step(s,1,.1);assert(not actions.stop,'Re-enabling Auto still lets the completion response settle')
s.completion_effects=nil
s.node={id='t',kind='transition',destination='both',participants=s.node.participants}
step(s,1,.1);assert(not actions.stop,'Re-enabling Auto still lets a transition end')
s.node=nodes.both
step(s,1,.1);assert(actions.stop=='ok' and s.plan.outcome=='goals_met','The last goal completed in manual mode waives the stay')

s=session(manual_stay,'both')
assert(Plan.set_auto(s,false));step(s,5,1);assert(Plan.set_auto(s,true))
step(s,5,1);assert(not actions.stop,'Completing the goals after re-enabling Auto starts the ordinary stay')
step(s,6,1);assert(actions.stop=='ok')

s=session({goals={goal_lead,goal_partner},post_completion_stay_seconds=6},'both')
assert(Plan.set_auto(s,false));step(s,10,1);assert(Plan.set_auto(s,true))
step(s,1,1);assert(not actions.stop,'The stay is preserved for existing callers')
step(s,6,1);assert(actions.stop=='ok')
-- A meter held at its maximum still needs a real completion: the plan waits, within the no-progress window.
s=session({goals={goal_lead}},'both');s.tasks.participants['1'].charge.value=100
for _=1,math.floor(C.plan_no_progress_seconds)-2 do assert(not Plan.tick(s,1,1),'A completion hold is not a dead end') end
assert(s.tasks.participants['1'].charge.completions==0 and s.node.id=='both')
local waited;for _=1,10 do waited=Plan.tick(s,1,1) or waited end
assert(waited and waited.stop=='no_progress','A hold that never lifts still ends')
-- Unequal rates: the slowest goal sets the stage.
node('uneven',{lead=full(20),partner=full(5)},{})
s=staged({goals={goal_lead,goal_partner},stages=4},'uneven',4);step(s,5,1)
assert(s.tasks.participants['1'].charge.completions==1 and s.tasks.participants['2'].charge.value==25 and s.plan.stage==2)
-- A required loop must connect to where the goals can finish.
node('gate',nil,{'dead','fin'},{starting_hub=true});node('dead',{},{},{content_rating='SUGGESTIVE'});node('fin',{lead=full(),partner=full()},{'dead'})
node('gate2',nil,{'dead2','fin2'},{starting_hub=true});node('dead2',{},{},{content_rating='SUGGESTIVE'});node('fin2',{lead=full(),partner=full()},{})
ok,err=pcall(picked,{goals={goal_lead},required_stages={{match=suggestive}}},{row('gate2')})
assert(not ok and tostring(err):find('required_stage_unavailable',1,true),'Two dead ends cannot both be played')
assert(pcall(picked,{goals={goal_lead},required_stages={{match=suggestive}}},{row('gate')}),'Finishing first and then going there is viable')
-- It finishes the goal first when the required loop has no way back.
s=staged({goals={goal_lead},required_stages={{match=suggestive}}},'gate');step(s,1,frame)
assert(s.node.id=='fin','A dead-end requirement waits for the goal')
step(s,9,1);assert(s.node.id=='fin')
step(s,1,1);assert(s.tasks.participants['1'].charge.completions==1 and s.node.id=='dead','It moves to the required scene as soon as the goal completes')
step(s,1,.1);assert(actions.stop=='ok'and s.plan.outcome=='goals_met')
-- Reachable only through a completion route: possible, not provable, and reported as such.
node('door',{lead=capped(10,50),partner=capped(10,50)},{},{task_completion_routes={charge={lead='late'}}});node('late',{lead=full(),partner=full()},{})
spec=plan_spec({goals={goal_lead}});assert(Plan.pick_entry(data,spec,{row('door')},people,{}).scene_id=='door'and spec.route_uncertain==true)
-- With neither goals nor a timer the plan cannot pass its first stage.
refused({end_policy={type='addon'},stages=2,required_stages={{stage=2,match=suggestive}}},'required_stage_unavailable')
-- Authored responses resolve before anything moves on.
s=session({goals={goal_lead}});s.completion_effects={shakes={['1']={}}};step(s,1,frame);assert(s.node.id=='hub','A shake holds navigation')
s.completion_effects=nil;s.voice_responses={channels={['1']={}}};step(s,1,frame);assert(s.node.id=='hub','A voice response holds navigation')
s.voice_responses=nil;step(s,1,frame);assert(s.node.id~='hub')
s=session({goals={goal_lead},end_policy={type='addon'}},'both');s.completion_effects={motion={}};step(s,12,1)
assert(#actions==0 and s.plan.state=='resolving','The milestone waits for the response')
s.completion_effects=nil;step(s,1,1);assert(actions[1]=='plan_goals_met')
-- A timed plan runs its time, whatever its goals are doing, and reports what it did not reach.
s=session({goals={goal_lead},end_policy={type='duration',seconds=120}},'still');step(s,110,1);assert(not actions.stop,'Past the stall window and still playing')
step(s,11,1);assert(actions.stop=='ok'and s.plan.outcome=='duration_elapsed'and not Plan.snapshot(s).goals[1].satisfied)
-- The longest allowed duration ends as a success, not as a blown budget.
s=session({end_policy={type='duration',seconds=C.plan_max_playback_seconds,clock='real'}},'still');step(s,1,C.plan_max_playback_seconds+1)
assert(actions.stop=='ok'and s.plan.outcome=='duration_elapsed')
-- A capped goal gets a loop that can move it, even while another goal is still advancing.
s=session({goals={goal_lead,goal_partner}},'light');step(s,6,1);assert(s.node.id=='both','Reassessed for the goal the cap stopped')
-- A required loop is visited before the final completion where possible.
s=staged({goals={goal_lead},required_stages={{match=suggestive}}},'a');step(s,1,frame)
assert(s.node.id=='b'and s.tasks.participants['1'].charge.completions==0,'The required loop comes first')
-- Split goals must not send the planner back and forth as their relative progress changes.
node('focus.lead',{lead=full()},{'focus.partner'})
node('focus.partner',{partner=full()},{'focus.lead'})
s=session({goals={goal_lead,goal_partner}},'focus.lead')
step(s,60,frame)
assert(actions.navigations==0 and s.node.id=='focus.lead','Hold the useful loop until its goal is complete')
step(s,10,1)
assert(s.node.id=='focus.partner' and actions.navigations==1,'Advance immediately once the remaining goal needs a different loop')
-- Any goal rising resets the stall timer, even while another one decays.
s=session({goals={goal_lead,goal_partner}},'both')
for i=1,65 do s.tasks.participants['1'].charge.value=i;s.tasks.participants['2'].charge.value=60-i*.9;assert(not Plan.tick(s,1.4,1)or actions.stop==nil) end
assert(s.plan.state=='running','A rising goal is progress')
-- Taking over clears a route in progress, and a loop chosen by hand earns no stage credit.
s=session({goals={goal_lead}});s.plan.heading='both';Plan.set_auto(s,false);assert(s.plan.heading==nil)
s=staged({goals={goal_lead},required_stages={{match=suggestive}}},'a');Plan.set_auto(s,false);s.node=nodes.b;s.revision=s.revision+1;Plan.set_auto(s,true);step(s,1,.1)
assert(not s.plan.required_stages[1].met,'Credit comes through auto-mode entry')
print('Plans passed: validation, feasibility, routes out, entry choice, caps, holds, unequal rates, responses, stall and unreachable ends, clocks, pause, add-on ending and bounds.')

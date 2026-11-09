-- Autonomous plans: validation, feasibility, goals, caps, end policies, clocks and bounds.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local nodes={}
package.loaded['SceneZOI.Settings']={task_multiplier=function()return 1 end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {nodes=nodes}end}
local J=require('SceneZOI.Json');local Tasks=require('SceneZOI.Tasks');local Plan=require('SceneZOI.Plan');local C=require('SceneZOI.Config')
local function refused(args,expected)
 local ok,err=pcall(Plan.parse,args,{charge={maximum=100}},{'1','2'})
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
local defs={charge={maximum=100,initial=0,decay=0}}
local people={{id='1',body='male'},{id='2',body='female'}}
local function row(id)return {scene_id=id,bindings={lead='1',partner='2'}}end
local function spec_of(args)return Plan.parse(args,defs,{'1','2'})end
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
assert(spec_of({goals={goal_lead}}).end_policy.type=='goals','Goals end on goals by default')
assert(spec_of({end_policy={type='duration',seconds=5}}).end_policy.clock=='game','Game time is the default clock')
assert(spec_of({goals={goal_lead}}).goals[1].completions==1,'One completion by default')

-- Feasibility looks at the authored graph from the entry.
local function picked(args,rows,restrictions)return Plan.pick_entry({nodes=nodes},spec_of(args),rows,people,restrictions or {})end
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
 local s={token='s.1',node=nodes[start or 'hub'],participants=participants,tasks=Tasks.new(defs,participants),session_restrictions={},preparing=false}
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
    local target
    for _,edge in ipairs(s.node.navigation)do if edge.id==action.navigate then target=edge.target end end
    s.node=assert(nodes[target],'A plan navigates only along authored edges');actions.navigations=actions.navigations+1
   end
  end
 end
end
local dwell=C.plan_min_dwell_seconds

-- A goal plan leaves a node that moves nothing, then ends once the goal is met.
local s=session({goals={goal_lead}});assert(Plan.locked(s),'Manual navigation is refused while a plan drives')
step(s,1,dwell+.1);assert(s.node.id=='both'or s.node.id=='light','A motionless hub is left after the dwell')
step(s,30,1);assert(actions.stop=='ok'and s.plan.outcome=='goals_met')
local snap=Plan.snapshot(s);assert(snap.goals[1].satisfied and snap.goals[1].completed==1 and snap.goals[1].requested==1 and snap.state=='finished')
assert(not Plan.locked(s))

-- Minimum dwell: nothing moves on before it.
s=session({goals={goal_lead}});step(s,1,dwell*.5);assert(s.node.id=='hub'and actions.navigations==0,'Rapid switching is avoided')

-- A cap stops a goal: the plan moves to a node that can finish it.
s=session({goals={goal_partner}},'light')
step(s,4,1);assert(s.node.id=='light'and s.tasks.participants['2'].charge.value==40)
step(s,1,1);assert(s.tasks.participants['2'].charge.value==50,'The cap holds')
assert(s.node.id=='both','Reassessed once the cap stopped the goal')
step(s,20,1);assert(actions.stop=='ok'and s.tasks.participants['2'].charge.completions==1)

-- Least-progressed first: at the hub both are at zero and the finishing node wins.
s=session({goals={goal_lead,goal_partner}});step(s,1,dwell+.1);assert(s.node.id=='both')

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
s=session({goals={goal_lead}},'still');s.plan.dwell=-1e9
step(s,math.floor(C.plan_no_progress_seconds)+2,1);assert(actions.stop=='no_progress'and s.plan.outcome=='no_progress')
-- Caps and restrictions can leave nothing to do: end cleanly rather than switch forever.
s=session({goals={goal_lead}},'still');step(s,1,dwell+.1);assert(actions.stop=='goal_unreachable')
nodes.both.content_rating='EXPLICIT'
s=session({goals={goal_partner}},'light');s.session_restrictions={allowed_content_ratings={'GENERAL'}}
step(s,6,1);step(s,1,dwell);assert(actions.stop=='goal_unreachable','A restriction is never relaxed to rescue a run')
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
local before=s.node;step(s,2,dwell);assert(s.node==before and not actions.stop,'The last loop holds while the add-on decides')
-- An owner that never calls stop does not hold the scene forever.
step(s,math.floor(C.plan_wait_seconds)+2,1);assert(actions.stop=='owner_expired'and s.plan.outcome=='wait_expired')
-- An add-on plan with neither goals nor a timer stays where it is.
s=session({end_policy={type='addon'}},'still');step(s,2,dwell);assert(s.node.id=='still'and not actions.stop)

-- A transition plays out: the clock counts it, nothing navigates or ends during it.
s=session({end_policy={type='duration',seconds=2}},'still');s.node={id='t',kind='transition',destination='still',participants=s.node.participants}
step(s,5,1);assert(not actions.stop and s.plan.game_used==5)
s.node=nodes.still;step(s,1,1);assert(actions.stop=='ok','It ends once the transition has resolved')
-- A completion response resolves first.
s=session({goals={goal_lead}},'both');s.completion_effects={motion={}};step(s,12,1);assert(not actions.stop,'Waits for the response')
s.completion_effects=nil;step(s,1,1);assert(actions.stop=='ok')

-- The overall playback budget is separate from the stall timer.
s=session({end_policy={type='addon'}},'still');step(s,1,C.plan_max_playback_seconds+1);assert(actions.stop=='playback_budget_exceeded')
print('Plans passed: validation, feasibility, entry choice, caps, repeated completions, stall and unreachable ends, clocks, pause, add-on ending and bounds.')

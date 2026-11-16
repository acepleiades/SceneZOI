package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Data=require('SceneZOI.TaskData')
local Tasks=require('SceneZOI.Tasks')
local Plan=require('SceneZOI.Plan')
local Control=require('SceneZOI.AddonControl')
local V=require('SceneZOI.DataValidation')
package.loaded['SceneZOI.Traits']={matches=function(rule,person)return rule.body==person.body end}
local function doc(owner,maximum)
 return {owner=owner,source='Text/'..owner,data={schema_version=1,id='charge',label='Charge',maximum=maximum}}
end
local docs={doc('alpha',10),doc('beta',20),doc('scenezoi',30),doc('gamma',10)}
local registry=Data.compile({by_kind={scene_task=docs}})
local function node(owner,id,tasks,edges)
 local n={_owner=owner,id=id,kind='loop',participants={lead={body='male'}},navigation=edges or {},tasks=tasks or {},tracks={lead='a'},anchor_participant='lead',
  _task_keys={},content_rating='GENERAL'}
 if tasks then n._task_keys.charge=Data.resolve(registry,n,'charge')end
 return n
end
local task={lead={charge={rate=5}}}
local a=node('alpha','alpha.loop',task,{{id='cross',target='beta.loop'}})
local b=node('beta','beta.loop',task)
local c=node('extra','extra.loop',task)
local shared=node('gamma','gamma.loop',task)
assert(registry.variants[a._task_keys.charge].maximum==10 and registry.variants[b._task_keys.charge].maximum==20)
assert(registry.variants[c._task_keys.charge].maximum==30 and c._task_keys.charge==registry.defaults.charge)
assert(a._task_keys.charge==shared._task_keys.charge,'Equal copies share progress')
for _, definitions in ipairs({{docs[2],docs[1]}, {docs[1],docs[2]}}) do
 local conflicts=Data.compile({by_kind={scene_task=definitions}})
 assert(Data.resolve(conflicts,c,'charge')=='alpha:charge','Pack ID order decides the fallback')
 assert(conflicts.definitions.charge==conflicts.variants['alpha:charge'],'Discovery and the final fallback agree')
 assert(V.equal(conflicts.conflicts,{{id='charge',owners={'alpha','beta'},fallback='alpha'}}))
end
local no_core=Data.compile({by_kind={scene_task={docs[2],docs[1]}}})
local explicit={_owner='extra',task_providers={charge='beta'}}
local missing={_owner='extra',task_providers={charge='missing'}}
local key,reason=Data.resolve(no_core,explicit,'charge')
assert(key=='beta:charge' and not reason,'An available dependency takes precedence over the final fallback')
key,reason=Data.resolve(no_core,missing,'charge')
assert(not key and reason=='task_provider_unavailable','A missing explicit dependency is reported')
assert(Data.resolve(registry,explicit,'charge')==registry.defaults.charge,'SceneZOI takes precedence over an explicit provider')
assert(Data.resolve(no_core,b,'charge')=='beta:charge','A pack keeps using its own definition')
key,reason=Data.resolve(no_core,c,'absent')
assert(not key and reason=='task_not_found')
local same=Data.compile({by_kind={scene_task={docs[4],docs[1]}}})
assert(Data.resolve(same,c,'charge')=='charge' and #same.conflicts==0,'Equivalent definitions share one meter')
local people={{id='1',role='lead',body='male'}}
local session,completed
local function tick(seconds)
 Tasks.update(session.tasks,session,seconds,function(event)completed[#completed+1]=event end)
end
local Session=require('SceneZOI.Session')
local function spec_for(count)
 return Plan.parse({goals={{task_id='charge',participant_id='1',completions=count}}},registry.definitions,{'1'})
end
local nodes={}
local function entry(n)return {scene_id=n.id,bindings={lead='1'}}end

-- Cap the entry and use an explicit missing dependency to exercise a parked goal.
local function scene(owner,id,rate,cap,edges)
 local n=node(owner,id,rate and {lead={charge={rate=rate,cap_percent=cap}}},edges)
 n._task_keys.charge=rate and Data.resolve(no_core,n,'charge') or nil
 nodes[id]=n
 return n
end
local first=scene('alpha','alpha.capped',4,50,{{id='forward',target='extra.hub'}})
local neutral=scene('extra','extra.hub',nil,nil,{{id='left',target='alpha.full'},{id='right',target='beta.full'}})
neutral.task_providers=missing.task_providers
local left=scene('alpha','alpha.full',5,100,{{id='back',target=neutral.id}})
local right=scene('beta','beta.full',2,100,{{id='back',target=neutral.id}})
local capped=scene('beta','beta.capped',2,50,{{id='finish',target=right.id}})
local fallback=scene('extra','extra.fallback',5,100)
local bad=scene('extra','extra.unresolved',5,100)
bad.task_providers,bad._task_keys.charge=missing.task_providers,nil
local data={nodes=nodes,tasks=no_core}
local spec=spec_for(2)
assert(Plan.pick_entry(data,spec,{entry(first)},people,{}).scene_id==first.id,'Another provider can finish a capped entry goal')
assert(Plan.pick_entry(data,spec,{entry(neutral)},people,{}).scene_id==neutral.id,'Separate providers at a hub are valid routes')
assert(Plan.pick_entry(data,spec,{entry(fallback)},people,{}).scene_id==fallback.id,'A third pack can start a goal with the fallback definition')
local ok,err=pcall(Plan.pick_entry,data,spec,{entry(bad)},people,{})
assert(not ok and tostring(err):find('task_provider_unavailable',1,true),'An unresolved-only route reports its missing dependency')
neutral.navigation={{id='right',target=right.id}}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return data end}

-- Tag providers and give the destination an authored initial the handoff must supersede.
no_core.variants['alpha:charge'].completion_event='alpha_done'
no_core.variants['alpha:charge'].decay=1
no_core.variants['beta:charge'].completion_event='beta_done'
no_core.variants['beta:charge'].initial=7
local function start(n,count,definitions)
 definitions=definitions or no_core
 session=Session.new({node=n,participants=V.copy(people),participant_ids={'1'},token='provider-test'})
 session.preparing=false
 if count then session.plan=Plan.new(spec_for(count))end
 session.tasks=Tasks.new(definitions.variants,session.participants,definitions,n)
 completed={}
end
local function visit(n)
 Session.change_node(session,n,{},1,{})
 local count=#completed
 tick(10)
 assert(#completed==count,'Preparing the destination cannot accrue a completion')
 session.preparing=false
end
local function progress()
 return Tasks.progress(session.tasks,session)['1'].charge
end
local function goal()
 return Plan.snapshot(session).goals[1]
end
local function near(actual,expected)
 assert(math.abs(actual-expected)<1e-6, tostring(actual)..' expected '..expected)
end

start(left)
assert(not session.plan and not session.addon_id, 'Manual sessions have no add-on or plan')
tick(1)
assert(progress().value==5)
visit(right)
assert(progress().value==10,'A manual scene change carries 50 percent into the new definition')
tick(5)
assert(#completed==1 and completed[1].task.completion_event=='beta_done' and progress().completions==1)
tick(3)
visit(neutral);tick(30)
assert(not progress(),'An unresolved scene hides a parked manual meter')
visit(left)
near(progress().value,3)
assert(progress().completions==1,'Manual handoffs keep the completion count')
tick(2)
assert(#completed==2 and completed[2].task.completion_event=='alpha_done' and completed[2].task.completion_index==2)

start(neutral)
visit(right)
assert(progress().value==7 and progress().completions==0,'An unresolved entry uses the first available definition’s initial value')

start(first,2)
tick(1)
assert(progress().value==4);near(goal().progress,.2)
visit(neutral);tick(20)
assert(not progress());near(goal().progress,.2)
visit(right)
assert(progress().value==8,'40 percent becomes 8 out of 20, independent of the destination initial')
tick(2)
assert(progress().value==12)
visit(first);tick(1)
assert(progress().value==6,'A lower cap stops gains and preserves the earned 60 percent')
local edge,target=Plan.route(session,session.plan)
assert(edge=='forward' and target==right.id,'Route scoring considers a different provider through a neutral hub')
visit(neutral);visit(right);tick(4)
assert(#completed==1 and completed[1].task.completion_event=='beta_done' and completed[1].task.completion_index==1)
assert(goal().completed==1 and not goal().satisfied)
assert(Plan.set_auto(session,false))
visit(left);assert(progress().completions==1);tick(2)
assert(#completed==2 and completed[2].task.completion_event=='alpha_done' and completed[2].task.completion_index==2)
assert(goal().completed==2 and goal().satisfied,'Manual takeover and a provider change preserve the goal total')
assert(Plan.set_auto(session,true))
session.plan.post_completion_stay_seconds=2.5
assert(not Plan.tick(session,0.5,1) and session.plan.state=='resolving')
assert(not Plan.tick(session,0.5,1),'A crossed-provider goal keeps the configured stay even without a response')
session.completion_effects={motion={}}
visit(right);tick(15)
assert(#completed==2 and goal().satisfied and progress().value==0,'A fulfilled resolving goal stays frozen after a provider change')
assert(not Plan.tick(session,2.5,1),'The plan waits while a completion response is still active')
session.completion_effects=nil
assert(Plan.tick(session,0.5,1).stop=='ok' and session.plan.outcome=='goals_met')

start(a,1,registry)
tick(1)
visit(c)
assert(progress().value==15,'The framework definition is the fallback and receives the same meter fraction')
tick(3)
assert(#completed==1 and completed[1].task_key==registry.defaults.charge and goal().satisfied)

start(right,1)
tick(1)
local fraction=progress().value/20
visit(fallback)
near(progress().value,10*fraction)
tick(2)
assert(#completed==1 and completed[1].task_key=='alpha:charge' and goal().satisfied)

-- Auxiliary tasks still carry progress when the plan targets another task.
local alpha_focus,beta_focus=doc('alpha',40),doc('beta',80)
alpha_focus.data.id,beta_focus.data.id='focus','focus'
local with_focus=Data.compile({by_kind={scene_task={docs[1],docs[2],alpha_focus,beta_focus}}})
local function extra_task(n)
 n=V.copy(n)
 n.tasks.lead.focus={rate=4}
 n._task_keys.focus=Data.resolve(with_focus,n,'focus')
 return n
end
start(extra_task(left),1,with_focus)
tick(1)
visit(extra_task(right))
local active=Tasks.progress(session.tasks,session)['1']
assert(active.focus.value==8 and active.charge.value==10,'Both goal and auxiliary meters preserve their own percentages')

-- Public task controls use the task ID, with or without an autonomous goal.
package.loaded['SceneZOI.Runtime']={api_session=function()return session end,is_addon_owner=function()return false end}
local services=require('SceneZOI.AddonServices')
local owner={GetEntityId=function()return {Value=1}end}
Control.register(Control.key('fixture','client','1'),{'tasks'})
local function api(op,args)
 args.session_id=session.token
 local handled,value=services.execute(owner,{addon_id='fixture',client_id='client',operation=op,arguments=args})
 assert(handled);return value
end
for _,autonomous in ipairs({false,true})do
 start(left,autonomous and 1 or nil)
 api('set_task_controls',{participant_id='1',task_id='charge',rate_multiplier=0.5,completion_hold=true})
 api('set_task_progress',{participant_id='1',task_id='charge',value=10})
 visit(capped);tick(1)
 local info=api('get_task_state',{})
 local meter=info.participants[1]
 assert(info.definitions.charge.maximum==20 and meter.value==20 and meter.completion_hold)
 assert(meter.addon_rate_multiplier==0.5 and meter.completions==0,'Controls and completion count stay attached to the task')
 api('set_task_controls',{participant_id='1',task_id='charge',rate_multiplier=1,completion_hold=false})
 tick(1);assert(#completed==0,'A carried full meter does not complete on a lower cap')
 if autonomous then
  assert(Plan.route(session,session.plan)=='finish','A carried full meter can route to an uncapped scene')
 end
 visit(right)
 assert(#completed==0)
 tick(1)
 assert(#completed==1 and completed[1].task.completion_event=='beta_done' and progress().completions==1)
 if autonomous then assert(goal().satisfied)end
end
print('Task providers passed: pack precedence, deterministic fallback, cross-pack route feasibility, normalized carry, manual and autonomous handoffs, unresolved hubs, caps, live controls, and single completion credit.')

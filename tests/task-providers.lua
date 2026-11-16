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
local hub=node('scenezoi','scenezoi.hub',nil,{{id='one',target=a.id},{id='two',target=b.id}})
assert(registry.variants[a._task_keys.charge].maximum==10 and registry.variants[b._task_keys.charge].maximum==20)
assert(registry.variants[c._task_keys.charge].maximum==30 and c._task_keys.charge==registry.defaults.charge)
assert(a._task_keys.charge==shared._task_keys.charge,'Equal copies share progress')
local no_core=Data.compile({by_kind={scene_task={docs[2],docs[1]}}})
local unresolved,reason=Data.resolve(no_core,c,'charge')
assert(not unresolved and reason=='task_ambiguous')
assert(Data.resolve(no_core,{_owner='extra',task_providers={charge='beta'}},'charge')=='beta:charge')
local people={{id='1',role='lead',body='male'}}
local session={token='scoped',participants=people,node=a,clock={},addon_controls={}}
session.tasks=Tasks.new(registry.variants,people,registry)
Control.init(session)
local completed={}
local function tick(seconds)
 Tasks.update(session.tasks,session,seconds,function(event)completed[#completed+1]=event end)
end
tick(1)
assert(Tasks.progress(session.tasks,session)['1'].charge.value==5)
session.node=b;tick(2)
assert(Tasks.progress(session.tasks,session)['1'].charge.value==10)
session.node=a
assert(Tasks.progress(session.tasks,session)['1'].charge.value==5,'Navigation keeps distinguishable progress')
local spec=Plan.parse({goals={{task_id='charge',participant_id='1'}}},registry.definitions,{'1'})
local data={nodes={[a.id]=a,[b.id]=b,[c.id]=c,[hub.id]=hub},tasks=registry}
local function entry(n)return {scene_id=n.id,bindings={lead='1'}}end
assert(Plan.pick_entry(data,spec,{entry(a)},people,{}).scene_id==a.id)
assert(spec.goals[1].task_key==a._task_keys.charge)
session.plan=Plan.new(spec)
session.node=b;tick(2)
assert(completed[1].task.id=='charge'and completed[1].task.maximum==20)
assert(not Plan.snapshot(session).goals[1].satisfied,'The other definition cannot satisfy the bound goal')
session.node=a;tick(1)
assert(Plan.snapshot(session).goals[1].satisfied and completed[2].task.maximum==10)
local ok,err=pcall(Plan.pick_entry,data,V.copy(spec),{entry(hub)},people,{})
assert(not ok and tostring(err):find('task_ambiguous',1,true),'Neutral hub with two finishable variants needs a provider')
hub.navigation[#hub.navigation+1]={id='three',target=c.id}
spec=Plan.parse({goals={{task_id='charge',participant_id='1'}}},registry.definitions,{'1'})
assert(Plan.pick_entry(data,spec,{entry(hub)},people,{}).scene_id==hub.id)
assert(spec.goals[1].task_key==c._task_keys.charge)
print('Task providers passed: pack first, framework fallback, explicit dependency, equal copies, independent navigation counters and pinned legacy goals.')

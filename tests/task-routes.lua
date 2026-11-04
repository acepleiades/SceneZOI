package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local R=require('SceneZOI.TaskRoutes');local D=require('SceneZOI.SceneData')
local roles={lead={body='male'},other={body='male'},helper={body='female'}}
local function node(id,kind)
 return {id=id,label=id,kind=kind or 'loop',duration=10,fps=60,participants=V.copy(roles),anchor_participant='lead',tracks={lead='/Test/A.A',other='/Test/A.A',helper='/Test/B.B'},navigation={}}
end
local origin=node('test.origin');origin.task_completion_routes={lead={charge='test.finish'},other={training='test.other'}}
local finish=node('test.finish','transition');finish.destination='test.idle'
local other=node('test.other');local idle=node('test.idle')
local function compile(nodes)return D.compile({{source='test',data={schema_version=3,id='test',nodes=nodes,extensions={}}}})end
local data=compile({origin,finish,other,idle});assert(#data.warnings==0 and data.nodes[origin.id].task_completion_routes.lead.charge==finish.id)
local wrong=V.copy(finish);wrong.participants.helper.body='male';data=compile({origin,wrong,other,idle})
assert(data.nodes[origin.id]and not data.nodes[origin.id].task_completion_routes.lead.charge and #data.warnings>0,'Bad routes isolated without hiding current scene')
for _,bad in ipairs({false,{unknown={charge=finish.id}},{lead={charge=4}},{lead={charge='bad id'}}})do assert(not pcall(R.validate,bad,roles))end
local a,b,c={id='1',role='lead'},{id='2',role='other'},{id='3',role='helper'}
local s={token='session',revision=2,node=origin,participants={b,c,a},bindings={lead=a,other=b,helper=c}}
local function payload(person,id)return {participant_id=person.id,participant_role=person.role,task={id=id,completed=true,completion_index=1}}end
local first=assert(R.candidate(s,payload(a,'charge')));local second=assert(R.candidate(s,payload(b,'training')))
assert(not R.candidate(s,payload(c,'charge'))and not R.candidate(s,payload(a,'training')),'Exact participant role and task must match')
local fake=payload(a,'charge');fake.participant_id='2';assert(not R.candidate(s,fake),'Repeated bodies must not substitute another participant')
assert(R.select(s,{second,first}).participant_id=='1'and R.select(s,{first,second}).participant_id=='1','Tie selection must be independent of actor iteration order')
s.revision=3;assert(not R.select(s,{first}));s.revision=2
s.node=V.copy(origin);s.node.id='test.changed';assert(not R.select(s,{first}));s.node=origin
for _,flag in ipairs({'preparing','stopping','ended'})do s[flag]=true;assert(not R.candidate(s,payload(a,'charge'))and not R.select(s,{first}));s[flag]=nil end
s.node=finish;assert(not R.candidate(s,payload(a,'charge'))and not R.select(s,{first}));s.node=origin
local E=require('SceneZOI.Events');local captured,packet
E.subscribe('task_route_selected',function(event)captured=event;event.task_route.target='mutated' end)
E.subscribe('task_route_selected',function(event)assert(event.task_route.target=='test.finish')end)
inzoi={message={send_to_client=function(_,_,raw)packet=raw end}}
E.emit('task_route_selected',{id='session',node_id=origin.id,revision=2,event_index=1,speed_index=2,task_route=first})
E.flush();assert(captured)
assert(captured.task_route.target=='mutated'and first.target=='test.finish'and captured.task_route.participant_id=='1')
print('Task routes passed: per-role/per-task matching, repeated-body identities, target validation/isolation, deterministic ties, stale revision/node guards, preparation/Exit/transition locks and copied event details.')

-- Registry integration removes only routes whose task is not currently registered.
local snapshot={by_kind={scene_pack={{source='pack',data={schema_version=3,id='test',nodes={origin,finish,other,idle},extensions={}}}}}}
package.loaded['SceneZOI.DataFiles']={get=function()return snapshot end}
inzoi.cli={execute=function()return true end}
local C=require('SceneZOI.Catalog');local registry=C.refresh()
assert(registry.nodes[origin.id]and not registry.nodes[origin.id].task_completion_routes.lead.charge and #registry.warnings==2)
snapshot=V.copy(snapshot);snapshot.by_kind.scene_task={{source='charge',data={schema_version=1,id='charge',label='Charge',maximum=10}}}
registry=C.refresh();assert(registry.nodes[origin.id].task_completion_routes.lead.charge==finish.id and not registry.nodes[origin.id].task_completion_routes.other.training)
local target=C.task_destination(registry.nodes[origin.id],first);assert(target.id==finish.id)
print('Task route registry passed: absent tasks isolated; valid independent task declarations enable exact registered IDs.')

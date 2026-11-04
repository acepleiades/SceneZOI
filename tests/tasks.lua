package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local D=require('SceneZOI.TaskData');local T=require('SceneZOI.Tasks')
local function def(id,max)return D.validate({schema_version=1,id=id,label=id,maximum=max or 90,decay=2,completion_event='finished',display={body_colors={male='#112233',female='#aabbcc'}}})end
local a,b,c={id='1',role='lead',body='female',task_name='Alice'},{id='2',role='other',body='male',task_name='Bob'},{id='3',role='helper',body='female',task_name='Carol'}
local s={node={id='neutral.activity',participants={lead={body='female'},other={body='male'},helper={body='female'}},tasks={lead={charge={rate=1}},other={charge={rate=.5,cap_percent=50}},helper={charge={rate=0}}}},participants={a,b,c}}
local events={};local function emit(payload)events[#events+1]=payload end
local t=T.new({charge=def('charge'),training=def('training',180)},s.participants)
local function tick(dt)T.update(t,s,dt or 1,emit)end
tick(20);assert(t.participants['1'].charge.value==20 and t.participants['2'].charge.value==10 and t.participants['3'].charge.value==0)
tick(70);assert(#events==1 and events[1].task.value==90 and events[1].task.completed and events[1].participant_id=='1'and events[1].task.completion_event=='finished')
assert(t.participants['1'].charge.value==0 and t.participants['2'].charge.value==45)
tick(100);assert(#events==2 and t.participants['2'].charge.value==45 and events[2].task.completion_index==2,'Repeated completion and cap')
tick(0);assert(#events==2,'Paused/zero time cannot emit duplicates')
tick(10);s.node={id='neutral.idle',participants=s.node.participants};tick(2)
assert(t.participants['1'].charge.value==6 and t.participants['2'].charge.value==41,'Progress must persist across transitions and decay')
s.node.tasks={lead={charge={rate=0}},other={charge={rate=-5}},helper={training={rate=2}}};tick(2)
assert(t.participants['1'].charge.value==6 and t.participants['2'].charge.value==31 and t.participants['3'].training.value==4,'Explicit zero holds, negative decreases and multiple tasks coexist')
s.preparing=true;tick(100);s.preparing=false;assert(t.participants['2'].charge.value==31)
s.stopping=true;tick(100);s.stopping=false;assert(t.participants['2'].charge.value==31)
s.node.tasks.lead.charge={rate=1,cap_percent=5};tick(1);assert(t.participants['1'].charge.value==6,'Entering a lower cap must not truncate existing progress')
s.node.tasks={};tick(100);assert(#T.snapshot(t,s)==0,'Zero omitted task indicators disappear')
s.node.tasks={lead={charge={rate=0}},other={charge={rate=-1}}};local rows=T.snapshot(t,s)
a.outfit_name=require('SceneZOI.Protocol').encode('Alice Updated');rows=T.snapshot(t,s)
assert(#rows==1 and rows[1].participant_name=='Alice Updated' and rows[1].color=='#aabbcc','Only explicit hold remains visible at zero')
s.node.tasks={lead={charge={rate=45},training={rate=90}}};tick(1);rows=T.snapshot(t,s)
assert(rows[1].percent==50 and rows[2].percent==50,'Configured maximum is independent of percentage')
s.node.tasks.lead.missing={rate=100};tick(1);tick(1);assert(#t.warnings==1,'Unknown task warns once and leaves scene functioning')
assert(events[#events].task.completion_index>=1)
local initial=def('full');initial.initial=90
local full=T.new({full=initial},s.participants);local fullEvents=0
T.update(full,s,1,function()fullEvents=fullEvents+1 end);assert(fullEvents==3 and full.participants['1'].full.value==0,'Initial maximum completes before automatic decay')
local copied=V.copy(t.definitions);copied.charge.maximum=3;assert(t.definitions.charge.maximum==90,'Session definitions are captured')
assert(not pcall(D.validate,{schema_version=1,id='bad',label='bad',maximum=0}))
for _,v in ipairs({0/0,math.huge,-1})do local x=def('bad');x.initial=v;assert(not pcall(D.validate,x))end
assert(not pcall(D.directives,{lead={charge={rate=1,cap_percent=101}}},s.node.participants))
local data=D.compile({by_kind={scene_task={{source='a',data=def('ok')},{source='b',data={schema_version=1,id='bad',label='bad',maximum=-1}},{source='c',data=def('ok',12)}}}})
assert(data.definitions.ok.maximum==90 and #data.warnings==2,'Malformed/conflicting contributions isolated')
-- Event observers receive independent snapshots after the update; failures cannot duplicate completions.
local E=require('SceneZOI.Events');local got=0
E.subscribe('task_completed',function(e)got=got+1;e.task.id='mutated';error('observer failure')end)
E.subscribe('task_completed',function(e)assert(e.task.id=='charge')end)
for i=1,70 do E.emit('task_completed',{task={id='charge'},event_index=i})end
assert(got==0);E.flush();assert(got==64);E.flush();assert(got==70,'Burst completions must not be discarded')
print('Tasks passed: independent repeated-body owners, caps, decay, zero hold, negative rates, simultaneous types, transitions, pause/preparation, percentages, completion/reset/repeat, invalid definitions/references and isolated deferred events.')

local observed
local handle=E.subscribe('task_completed',function(event)observed=event end)
E.emit('task_completed',{id='session.1',event_index=1,node_id='neutral.activity',revision=1,speed_index=2,
 participant_id='123',participant_role='caster',participants={},task={id='charge',completion_event='ready',completion_index=1}})
E.flush();assert(observed.participant_id=='123'and observed.task.id=='charge'and observed.task.completion_event=='ready')
E.unsubscribe(handle)

package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Clock=require('SceneZOI.Clock');local V=require('SceneZOI.DataValidation');local S=require('SceneZOI.SceneData');local T=require('SceneZOI.Tasks')
local function node(id,kind,destination)
 local v={id=id,label=id,kind=kind,duration=10,fps=60,anchor_participant='lead',participants={lead={body='male'},other={body='male'},helper={body='female'}},tracks={lead='/Test/A.A',other='/Test/A.A',helper='/Test/B.B'},navigation={}}
 if kind=='transition'then v.destination=destination end;return v
end
local a=node('test.a','loop');a.navigation={{id='change',target='test.t'}}
local t=node('test.t','transition','test.b');local b=node('test.b','loop')
local function compile(nodes)return S.compile({{source='pack',data={schema_version=3,id='test',nodes=nodes,extensions={}}}})end
local data=compile({a,t,b});assert(#data.warnings==0 and data.nodes['test.t'].destination=='test.b')
for _,edit in ipairs({function(x)x.destination=nil end,function(x)x.destination=x.id end,function(x)x.navigation={{id='bad',target='test.b'}}end,function(x)x.starting_hub=true end,function(x)x.hub='test.hub'end})do
 local x=V.copy(t);edit(x);assert(not pcall(S.node,x,'test'))
end
local x=V.copy(b);x.destination='test.a';assert(not pcall(S.node,x,'test'))
local missing=V.copy(t);missing.destination='other.missing';data=compile({a,missing,b})
assert(not data.nodes['test.t']and #data.nodes['test.a'].navigation==0 and #data.warnings>0,'Invalid automatic route isolated before incoming links')
local incompatible=V.copy(b);incompatible.participants.helper.body='male';data=compile({a,t,incompatible});assert(not data.nodes['test.t'])
local second=node('test.second','transition','test.t');x=V.copy(t);x.destination=second.id;data=compile({a,x,second,b});assert(not data.nodes['test.t']and not data.nodes['test.second'],'Automatic cycles rejected')
x=V.copy(t);x.destination=second.id;second.destination=b.id;data=compile({a,x,second,b});assert(data.nodes['test.second']and data.nodes['test.t'],'Finite chains supported')
-- Integrated scene seconds, not a wall-clock deadline. Changes preserve accumulated time.
for _,index in ipairs({1,2,3,4})do
 local c=Clock.new();c:select(index);local scale=({.5,1,1.5,2})[index]
 c:advance(10/scale-.01,1);assert(not c:finished(10,'transition'))
 c:advance(.02,1);assert(c:finished(10,'transition')and c:position(10,'transition')>9.99 and c:position(10,'transition')<10)
 assert(not c:finished(10,'loop')and c:position(10)<1,'Existing loop modulo remains unchanged')
end
local c=Clock.new();c:advance(4,1);c:select(4);c:advance(100,0);assert(c.elapsed==4)
c:advance(1,1);assert(c.elapsed==6);c:advance(1,2);assert(c:finished(10,'transition')and c.elapsed==10)
c:advance(100,4);assert(c:position(10,'transition')>9.99 and c:position(10,'transition')<10,'Large overshoot never wraps')
-- Task progression, decay, holds and negative rates all freeze for any roster.
local people={};for role in pairs(t.participants)do people[#people+1]={id=role,role=role}end
local session={node=t,participants=people};t.tasks={lead={charge={rate=100}},other={charge={rate=-100}},helper={charge={rate=0}}}
local progress=T.new({charge={maximum=90,initial=20,decay=2},omitted={maximum=90,initial=20,decay=2}},people)
T.update(progress,session,100,function()error('Task completed during transition')end)
for _,p in ipairs(people)do assert(progress.participants[p.id].charge.value==20 and progress.participants[p.id].omitted.value==20)end
print('Transitions passed: validation/isolation, repeated-body rosters, finite chains/cycles, native/scene speed changes, pause, clamped final pose, unchanged looping and all-task freeze.')

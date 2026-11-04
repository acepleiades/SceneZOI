package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local J=require('SceneZOI.Json')
local C=require('SceneZOI.AddonControl');local Tasks=require('SceneZOI.Tasks');local Search=require('SceneZOI.SceneSearch')
package.loaded['SceneZOI.Traits']={matches=function(r,p)return r.body==p.body end}
local node={id='test.hub',kind='loop',participants={giving={body='male'},receiving={body='male'}},navigation={},
 actions={{type='hug',actor='giving',target='receiving',performer='giving'}},content_rating='GENERAL',tasks={giving={['test.energy']={rate=1}},receiving={['test.energy']={rate=2}}}}
local roster={{id='1',body='male',role='giving'},{id='2',body='male',role='receiving'}}
local bindings=assert(Search.bind(node,roster,{giving='2',receiving='1'}));assert(bindings.giving=='2'and bindings.receiving=='1')
assert(not Search.bind(node,roster,{giving='1',receiving='1'}));assert(not Search.bind(node,roster,{giving='3'}))
local s={token='session.test',node=node,participants=roster,revision=1,clock={session_elapsed=0},addon_controls={}}
C.init(s);s.tasks=Tasks.new({['test.energy']={label='Energy',maximum=10,initial=0}},roster)
local events={};local function tick(dt)Tasks.update(s.tasks,s,dt,function(e)events[#events+1]=e end)end
C.register('a',{'tasks','presentation','speed'});C.register('b',{'tasks','presentation'})
local a=C.layer(s,'a');local b=C.layer(s,'b')
a.tasks['1|test.energy']={completion_hold=true,rate_multiplier=2}
b.tasks['1|test.energy']={completion_hold=true,rate_multiplier=.5}
tick(12);assert(s.tasks.participants['1']['test.energy'].value==10 and #events==1,'Only the unheld participant completes')
a.tasks['1|test.energy'].completion_hold=false;tick(1);assert(s.tasks.participants['1']['test.energy'].completions==0,'Another add-on still holds completion')
b.tasks['1|test.energy'].completion_hold=false;tick(0);assert(s.tasks.participants['1']['test.energy'].completions==0)
s.preparing=true;tick(1);s.preparing=false;tick(1);assert(s.tasks.participants['1']['test.energy'].completions==1 and events[#events].task.completed)
a.voice_mutes['1']=true;b.voice_mutes['1']=true
a.expressions['1']={context='a'};C.touch(a);b.expressions['1']={context='b'};C.touch(b)
assert(C.expression(s,'1').context=='b');C.release(s,'b');assert(C.muted(s,'1')and C.expression(s,'1').context=='a')
C.renew('a');C.tick(11,s);assert(C.muted(s,'1'));C.tick(1,s);assert(not C.muted(s,'1')and C.expression(s,'1')==nil)
assert(not pcall(C.authorize,s,'observer','tasks',false),'Subscribing grants no write permission')
C.sample(s,3,0);assert(s.playing_seconds==0);s.preparing=true;C.sample(s,2,1);s.preparing=false;C.sample(s,4,2)
assert(s.playing_seconds==4 and s.playing_game_seconds==8 and s.peak_content_rating=='GENERAL')
node=V.copy(node);node.id='test.next';node.content_rating='EXPLICIT';s.node=node;s.revision=2;C.enter(s);C.sample(s,1,1)
node.content_rating='GENERAL';C.sample(s,1,1);assert(s.peak_content_rating=='EXPLICIT'and #s.addon_played==2)
local facts=C.facts(s);facts.visited_scenes[1].node_id='bad';assert(s.addon_history[1].node_id=='test.hub')
C.ended(s,{id=s.token,result_facts=C.facts(s)});assert(C.result(s.token).result_facts.playing_seconds==6)
for i=1,33 do C.ended({token='other.'..i},{id='other.'..i})end;assert(C.result(s.token)==nil)
local Data=require('SceneZOI.AddonData')
local annotation={['author.mod']={enabled=true,values=J.array({1,'text',J.null}),nested={weight=.5}}}
Data.validate(annotation);assert(not pcall(Data.validate,{not_namespaced={}}));assert(not pcall(Data.validate,{['author.mod']=function()end}))
assert(not pcall(Data.validate,{['author.mod']={huge=string.rep('x',8192)}}))
local nested={};local top=nested;for i=1,10 do nested.x={};nested=nested.x end
assert(not pcall(Data.validate,{['author.mod']=top}))
local Effects=require('SceneZOI.AddonEffects');local p=roster[1];p.outfit_items={top={enabled=true}}
C.register('a',{'outfits'});C.register('b',{'outfits'})
Effects.outfit(s,'a','1','top',false);Effects.outfit(s,'b','1','top',true)
local changes={};local function apply(person,item,enabled)changes[#changes+1]=enabled;person.outfit_items[item].enabled=enabled end
Effects.tick(s,.1,apply);assert(#changes==0)
C.release(s,'b');Effects.tick(s,.1,apply);assert(p.outfit_items.top.enabled==false)
C.release(s,'a');Effects.tick(s,.1,apply);assert(p.outfit_items.top.enabled==true,'Last override release restores its session baseline')
Effects.outfit(s,'a','1','top',false);Effects.tick(s,.1,apply)
Effects.player_outfit(s,'1','top',true);p.outfit_items.top.enabled=true;C.release(s,'a');Effects.tick(s,.1,apply);assert(p.outfit_items.top.enabled)
local rows=Tasks.inspect(s.tasks,s);assert(#rows==2 and rows[1].maximum==10 and rows[1].percent~=nil)
print('Add-on controls: explicit same-body bindings, independent holds/mutes/expressions, expiry, real task completion, actual-play results, retention, inert annotation bounds and clothing restoration passed.')

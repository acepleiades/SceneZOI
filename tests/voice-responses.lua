package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local D=require('SceneZOI.VoiceData');local RD=require('SceneZOI.VoiceResponseData')
local set=D.validate('voice_set',{schema_version=1,id='test.voice',label='Voice',body='female',archetype='test',context='talk',clips={'/Test/Normal.Normal'},volume=.8,gap=.1,
 responses={Complete={clips={'/Test/Complete.Complete'}},Answer={clips={'/Test/Answer.Answer'}}}})
assert(set.responses.complete and set.responses.answer)
local library={sets={[set.id]=set}}
package.loaded['SceneZOI.VoiceLibrary']={get=function()return library end}
local plays,volumes={},{};local fail_play,fail_destroy=false,false
local N={}
function N.rate(r)return math.max(1,math.min(2,r))end
function N.load(path)if path:find('Missing')then error('missing optional clip')end;return {path=path,duration=path:find('Normal')and 1 or 2}end
function N.create(v,actor,spec,category)v.category=category;v.component=v.component or {};v.owner=actor.id;v.component.volume=spec.volume;v.destroyed=false end
function N.position(bindings,sources)return bindings[sources[1].participant].actor.point end
function N.move(v,p)v.point=p end
function N.volume(v,x)v.component.volume=x;volumes[v.owner]=x end
function N.pause(v,x)v.paused=x end
function N.tune(v,r,p)v.rate=N.rate(r);v.requested=r;v.paused=p end
function N.play(v,clip,point,r)
 v.clip=clip;v.point=point;v.stopped=false;N.tune(v,r,false)
 if fail_play then fail_play=false;error('partial Play')end
 plays[#plays+1]={owner=v.owner,path=clip.path}
end
function N.stop(v)v.stopped=true;v.remaining=nil end
function N.destroy(v)if fail_destroy then fail_destroy=false;error('retry destroy')end;N.stop(v);v.destroyed=true;v.component=nil end
function N.finished(v)return not v.remaining or v.remaining<=0 end
package.loaded['SceneZOI.SoundNative']=N
local Voice=require('SceneZOI.Voices');local R=require('SceneZOI.VoiceResponses')
local people,bindings={},{}
for i=1,3 do
 local p={id=tostring(i),role='actor'..i,body='female',expression_body='female',voice_body='female',voice_loaded=true,
 voice_profile={archetype='test',sets={talk=set.id}},actor={id=tostring(i),point={X=i}}}
 people[i]=p;bindings[p.role]=p
end
local node={voices={},task_completion_voices={actor1={charge={{participant='actor1',context='talk',response='complete',fade_out=.25,priority=10}}},
 actor2={charge={{participant='actor1',context='talk',response='answer',fade_out=.25,priority=20}}},actor3={charge={{participant='actor3',context='talk',response='complete'}}}}}
for role in pairs(bindings)do node.voices[role]={context='talk'}end
local session={participants=people,bindings=bindings,node=node,revision=1,clock={game_elapsed=0,scale=1,index=2}}
local function audio()
 local v=Voice.load();v.node=session.node;Voice.prepare(v,session);Voice.enter(v);return v
end
local voices=audio();local response={};R.prepare(response,session);R.enter(response)
local function payload(i,index)return {participant_role=people[i].role,participant_id=people[i].id,task={id='charge',completed=true,completion_index=index or 1}}end
local function step(real,scale)
 session.clock.scale=scale or 1;session.clock.game_elapsed=session.clock.game_elapsed+real*session.clock.scale
 Voice.sample(voices);R.sample(response)
end
local normal=voices.owners['1'].audio.emitters[1].voices[1]
R.trigger(response,{payload(2),payload(1),payload(3)})
assert(response.channels['1'].item.response=='answer'and #response.channels['1'].queue==0 and response.channels['3'])
R.trigger(response,{payload(1)});assert(#response.channels['1'].queue==0,'Duplicate/lower priority completion must not enqueue again')
step(.125);assert(math.abs(normal.component.volume-.4)<1e-8 and not normal.stopped,'Normal clip must fade rather than hard-cut')
step(.125);assert(normal.stopped and response.plays==2 and response.channels['1'].voice.component.volume==.8)
assert(response.channels['1'].voice.category=='female_voice','One-shot responses must use the speaker set volume channel')
local shot=response.channels['1'].voice
session.clock.index=4;people[1].actor.point={X=100};step(.5,.1)
assert(shot.point.X==100 and shot.rate==1 and math.abs(shot.remaining-1.5)<1e-8,'Spatial response obeys normal-rate slow-motion audio policy, not scene speed')
step(10,0);assert(shot.paused and math.abs(shot.remaining-1.5)<1e-8,'Pause freezes one-shot')
session.preparing=true;Voice.guard(voices);R.guard(response);assert(shot.paused)
session.preparing=false;step(1.51);assert(not response.channels['1']and not response.channels['3'])
assert(response.plays==2,'Higher priority partner response suppresses simultaneous own response');step(.01);assert(normal.component.volume==.8 and not normal.remaining,'Normal emitter restores volume then waits its configured gap')
step(.11);assert(normal.remaining and not normal.stopped,'Continuous voice resumes normally')
R.trigger(response,{payload(1,2)});step(.25);assert(response.channels['1'].stage=='playing')
local own=response.channels['1'].voice
R.trigger(response,{payload(2,2)});assert(response.channels['1'].stage=='replacing')
step(.125);assert(math.abs(own.component.volume-.4)<1e-7 and not own.stopped,'Priority interruption must fade the current own response')
step(.125);assert(response.channels['1'].item.response=='answer'and own.destroyed,'Partner reaction preempts own response')
R.leave_node(response);Voice.leave_node(voices);Voice.restore(voices)
session.revision=2;session.node={voices=node.voices};voices=audio();R.prepare(response,session);R.enter(response)
assert(response.channels['1']and not voices.owners['1'],'Active one-shot survives prepared navigation without continuous overlap')
step(2.01);step(.01);assert(voices.owners['1'],'Arrival voice context starts after response ends')
-- Silence/live set changes cancel the response and never borrow another archetype.
session.node=node;R.trigger(response,{payload(1,3)});step(.25);people[1].voice_profile.sets.talk=nil;step(.01)
assert(not response.channels['1']and not voices.owners['1'])
people[1].voice_profile.sets.talk=set.id;step(.01)
set.responses.complete.clips={'/Test/Missing.Missing'};R.trigger(response,{payload(1,4)})
assert(not response.channels['1']and response.error and voices.owners['1'],'Missing optional asset must not interrupt normal voice')
set.responses.complete.clips={'/Test/Complete.Complete'}
R.trigger(response,{payload(1,5)});fail_play=true;step(.25);assert(response.channels['1'].failed)
step(.01);step(.01);assert(not response.channels['1']and voices.owners['1'].audio.active,'Partial play must clean up and release channel')
R.trigger(response,{payload(1,6)});step(.25);fail_destroy=true;assert(not pcall(R.restore,response));assert(response.channels['1'])
R.restore(response);R.restore(response);Voice.restore(voices)
for _,bad in ipairs({{responses={a={clips={}}}},{responses={a={clips={'code()'}}}},{responses={a={clips={'/A/A.A'},callback='run'}}},
 {responses={A={clips={'/A/A.A'}},a={clips={'/A/B.B'}}}}})do
 local x=V.copy(set);for k,v in pairs(bad)do x[k]=v end;assert(not pcall(D.validate,'voice_set',x))
end
assert(not pcall(RD.validate,{actor1={charge={{participant='absent',context='talk',response='complete'}}}},bindings))
assert(not pcall(RD.validate,{actor1={charge={{participant='actor1',context='talk',response='complete',fade_out=-1}}}},bindings))
print('Voice responses passed: named set groups, 0.25s fade, own/partner routing, priority suppression/preemption, no overlap/replay, 3 independent participants, spatial slow-motion/pause timing, continuous resume, navigation, live silence, missing assets, partial play and retryable cleanup.')

-- Public add-on mutes: native playback, prepared handoffs and diagnostic isolation.
R.restore(response);Voice.restore(voices)
session.node=node;voices=audio();response={};R.prepare(response,session)
local Control=require('SceneZOI.AddonControl')
Control.layer(session,'muter').voice_mutes['1']=true
Voice.sample(voices)
assert(not voices.owners['1'].audio.emitters[1].voices[1].remaining,'Live mute must stop its owned emitter')
assert(voices.owners['2'].audio.emitters[1].voices[1].remaining,'Live mute must leave another participant playing')
local muted_plays=0;for _,event in ipairs(plays)do if event.owner=='1'then muted_plays=muted_plays+1 end end
Voice.leave_node(voices);Voice.enter(voices)
local entered_plays=0;for _,event in ipairs(plays)do if event.owner=='1'then entered_plays=entered_plays+1 end end
assert(entered_plays==muted_plays,'Re-entering a muted voice must not briefly play then stop a clip')
R.trigger(response,{payload(1,99)})
assert(not response.channels['1'],'A muted completion must not schedule audio')
assert(not response.error,'Intentional muting must not report a missing voice response')
Control.release(session,'muter');step(.11);step(.11)
assert(voices.owners['1'].audio.emitters[1].voices[1].remaining,'Releasing mute must allow normal voice scheduling')
R.restore(response);Voice.restore(voices)
print('Actual voice engine mute, other-owner independence, completion suppression and warning isolation passed')

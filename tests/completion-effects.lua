package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Motion=require('SceneZOI.MotionResponse')
local D=require('SceneZOI.CompletionData')
local C=require('SceneZOI.Clock')
local function close(a,b,e)assert(math.abs(a-b)<(e or 1e-7),tostring(a)..' != '..tostring(b))end
local timing={cycles_per_second=1,peak_phase=.5}
local profile={repeats=2,recovery=.4}
local s=Motion.new(profile,timing,10,0)
-- Reference profile: 40% approach, 20% hold, 40% recovery; 4 s per authored second.
close(Motion.advance(s,1.6),7/15);close(s.position,7/15)
close(Motion.advance(s,.4),1/30);close(s.position,.5)
close(Motion.advance(s,.4),1/30);close(s.position,8/15)
close(Motion.advance(s,1.6),7/15);close(s.position,1)
close(Motion.advance(s,4),1);assert(s.stage=='recovery')
close(Motion.advance(s,.4),.3);assert(s.stage=='done')
-- Exact integration must not depend on frame size or number of wrap boundaries.
local one=Motion.new(profile,timing,10,9.72);local many=Motion.new(profile,timing,10,9.72)
Motion.advance(one,12.3)
for i=1,1230 do Motion.advance(many,.01)end
close(one.position,many.position,1e-6);assert(one.stage==many.stage)
-- A nonzero declared peak phase shifts the synchronization boundary with it.
local offset=Motion.new({repeats=1},{cycles_per_second=1,peak_phase=.25},10,.1)
close(offset.wait,.65);Motion.advance(offset,.65+2);close(offset.position,1.25)
-- Uneven marker spacing and wrap: minima must reach the actual authored marker.
local irregular={peak_times={.3,1.1,2.7}}
local cycle=Motion.cycle(irregular,4,0)
close(cycle.start,.7);close(cycle.peak,1.1);close(cycle.finish,1.9)
local marked=Motion.new({repeats=2},irregular,4,0)
Motion.advance(marked,.7+(1.1-.7)/.25);close(marked.position,1.1)
local nextloop=Motion.cycle(irregular,4,3.9);assert(nextloop.start>=3.9 and nextloop.peak>4)
-- Fallback does not require timing, remains smooth and restores the prior baseline.
local fallback=Motion.new({fallback_duration=6,recovery=.4},nil,10,2)
Motion.advance(fallback,6.4);close(fallback.position,3.8);assert(fallback.stage=='done')
for _,bad in ipairs({{cycles_per_second=0},{cycles_per_second=1,peak_times={1}},
 {peak_times={1,1}},{peak_times={10}},{peak_times={2,1}},{cycles_per_second=1.01}})do
 assert(not pcall(D.timing,bad,10))
end
local roles={a={body='female'},b={body='female'},c={body='male'}}
assert(not pcall(D.responses,{unknown={charge={enabled=true,slowdown={}}}},roles,'loop'))
assert(not pcall(D.responses,{a={charge={enabled=true,slowdown={}}}},roles,'transition'))
assert(not pcall(D.responses,{a={charge={enabled=true,slowdown={low_speed=.8,high_speed=.2}}}},roles,'loop'))
assert(not pcall(D.responses,{a={charge={enabled=true,shake={bones={{bone='a',child='a'}}}}}},roles,'loop'))
local calls={apply={},restore={}};local fail=false
package.loaded['SceneZOI.BoneOscillation']={
 apply=function(o,spec,angle)if fail then fail=false;error('optional body rebuild')end;calls.apply[o.participant.id]=angle end,
 restore=function(o)calls.restore[o.participant.id]=true end}
local E=require('SceneZOI.CompletionEffects')
local people={{id='1',role='a'},{id='2',role='b'},{id='3',role='c'}}
local session={token='test',revision=1,clock=C.new(),duration=10,participants=people,bindings={},node={id='example.loop',kind='loop',movement_timing=timing,completion_responses={}}}
local shake={delay=.5,duration=6,bursts=3,duty_cycle=.7,frequency_hz=18,amplitude_degrees=1.25,bones={{bone='thigh_l',child='calf_l'}}}
for _,p in ipairs(people)do session.bindings[p.role]=p;session.node.completion_responses[p.role]={charge={enabled=true,slowdown=profile,shake=shake}}end
local ctx={};E.prepare(ctx,session)
local function payload(i,index)return {participant_id=tostring(i),participant_role=people[i].role,task={id='charge',completed=true,completion_index=index or 1}}end
E.trigger(ctx,{payload(3),payload(2),payload(1)})
assert(ctx.source=='1|charge'and ctx.starts==3 and ctx.shakes['1']and ctx.shakes['2']and ctx.shakes['3'],'Shared arbitration with independent 3+ owners')
local original=ctx.motion;E.trigger(ctx,{payload(1)});assert(ctx.motion==original and ctx.starts==3,'No duplicate completion effects')
local game=0
-- Scene speed changes modify the baseline, without losing synchronized clip phase.
for i=1,400 do
 local dt=.01;local scale=i<=20 and 0 or 2
 if i==120 then session.clock:select(4)end
 local modifier=E.multiplier(ctx,dt,scale);session.clock:advance(dt,scale,modifier);E.sample(ctx)
 game=game+dt*scale
end
close(session.clock.game_elapsed,game);assert(session.clock.index==4 and not ctx.motion)
assert(next(ctx.shakes)==nil and calls.restore['1']and calls.restore['2']and calls.restore['3'])
E.trigger(ctx,{payload(2,2)});assert(ctx.motion and ctx.source=='2|charge')
local age=ctx.motion.age;local elapsed=session.clock.elapsed
local modifier=E.multiplier(ctx,10,0);session.clock:advance(10,0,modifier);E.sample(ctx)
close(ctx.motion.age,age);close(session.clock.elapsed,elapsed)
session.preparing=true;E.trigger(ctx,{payload(3,2)});assert(ctx.starts==4,'No effects during preparation')
session.preparing=false;E.leave_node(ctx);assert(not ctx.motion and next(ctx.shakes)==nil and session.clock.modifier==1)
session.node.kind='transition';E.trigger(ctx,{payload(3,2)});assert(ctx.starts==4)
session.node.kind='loop';E.trigger(ctx,{payload(3,2)});assert(ctx.starts==5)
session.clock.game_elapsed=session.clock.game_elapsed+1;fail=true;E.sample(ctx);E.sample(ctx)
assert(ctx.shakes['3']==nil and ctx.error,'Optional native failure isolated and cleanup retried')
close(E.angle(shake,.5),0)
local _,done=E.angle(shake,6.5);assert(done)
local female={duration=3,bursts=1,duty_cycle=1,delay=.5}
local _,finished=E.angle(female,3.5);assert(finished)
print('Completion effects passed: Harem-style exact phase profile, uniform/irregular markers/wrap, fallback, frame-size invariance, native/scene speed changes and pause, 3 independent owners, arbitration, dedup, repeat, navigation/Exit and optional failure cleanup.')

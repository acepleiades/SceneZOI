package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local plays,created,destroyed,stops={},0,0,0
local unavailable=false;local fail_destroy=false;local fail_stop=false
local N={}
function N.load(path)if unavailable then error('unavailable')end;return {path=path,duration=1,asset={}}end
function N.point(bindings,spec)return assert(bindings[spec.participant].actor.points[spec.bones[1]],'missing point')end
function N.position(bindings,sources)
 local x,y,z=0,0,0
 for _,source in ipairs(sources)do local p=N.point(bindings,source);x,y,z=x+p.X,y+p.Y,z+p.Z end
 return {X=x/#sources,Y=y/#sources,Z=z/#sources}
end
function N.create(v,actor,spec)if not v.component then created=created+1;v.component={owner=actor.id};v.destroyed=false end end
function N.move(v,p)v.position=p end
function N.pause(v,value)v.paused=value end
function N.tune(v,requested,pause)v.requested=requested;v.rate=math.max(1,math.min(4,requested));v.paused=pause;return v.rate end
function N.play(v,clip,p,requested)
 v.stopped=false;v.clip=clip;N.move(v,p);N.tune(v,requested,false)
 plays[#plays+1]={path=clip.path,owner=v.component.owner,rate=v.rate}
end
function N.stop(v)
 if fail_stop then fail_stop=false;error('stop retry')end
 if not v.stopped then stops=stops+1 end;v.stopped=true;v.remaining=nil
end
function N.destroy(v)
 if v.destroyed then return end
 if fail_destroy then fail_destroy=false;error('destroy retry')end
 N.stop(v);v.destroyed=true;v.component=nil;destroyed=destroyed+1
end
function N.finished(v)return not v.remaining or v.remaining<=0 end
package.loaded['SceneZOI.SoundNative']=N
local variants={}
for _,speed in ipairs({.5,1,1.5,2})do variants[#variants+1]={scene_speed=speed,clips={'v'..speed..'a','v'..speed..'b'}}end
local test_catalog={sound_sets={test={default={clips={'one','two','three'}}},variants={variants=variants}}}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return test_catalog end}
local S=require('SceneZOI.Sfx')
local function point(role,bone)return {participant=role,component='body',bones={bone}}end
local p={a={id='1',actor={id='1',points={root={X=0,Y=0,Z=0}}}},b={id='2',actor={id='2',points={hand={X=10,Y=0,Z=0}}}},c={id='3',actor={id='3',points={hand={X=10,Y=0,Z=0}}}}}
local function impact(role)return {mode='bone_distance',owner=role,sound_set='variants',source={point('a','root'),point(role,'hand')},distance={from=point(role,'hand'),to=point('a','root')},max_voices=2}end
local node={sfx={first=impact('b'),second=impact('c'),ambience={mode='continuous',owner='a',sound_set='test',source={point('a','root')},max_voices=1},other={mode='continuous',owner='c',sound_set='variants',source={point('c','hand')},max_voices=1}}}
local session={bindings=p,clock={session_elapsed=0,game_elapsed=0,scale=1,effective=1,index=2},revision=1}
local ctx=S.load(node);ctx.node=node;assert(S.prepare(ctx,session));S.enter(ctx)
assert(#plays==2,'Continuous emitters must start independently')
local by={};for _,e in ipairs(ctx.emitters)do by[e.id]=e end
local function sample(time,distance)
 local c=session.clock
 c.game_elapsed=c.game_elapsed+(time-c.session_elapsed)/({.5,1,1.5,2})[c.index]
 c.session_elapsed=time
 if distance then p.b.actor.points.hand.X=distance;p.c.actor.points.hand.X=distance end
 S.sample(ctx)
end
sample(.05,8);sample(.10,6);sample(.15,6.02);sample(.20,8)
assert(by.first.plays==1 and by.second.plays==1,'Each close distance minimum must trigger its own emitter')
assert(by.first.voices[1].component.owner=='2'and by.second.voices[1].component.owner=='3','Repeated-body owners were conflated')
assert(by.first.voices[1].position.X==4,'The source must be the contact midpoint')
sample(.25,6);sample(.30,8);sample(.40,9)
assert(by.first.plays==1,'Cooldown must prevent jitter/repeated impacts')
sample(.45,6);sample(.50,8);assert(by.first.plays==2)
local count=#plays;session.clock.scale=0;session.clock.effective=0
for _=1,30 do S.sample(ctx)end
assert(#plays==count and by.ambience.voices[1].paused,'Pause must hold all owned audio without replaying')
session.clock.scale=1;session.clock.effective=1;S.sample(ctx);assert(not by.ambience.voices[1].paused)
local oldGeneric=by.ambience.plays;local oldVariants=by.other.plays
session.clock.index=3;session.clock.scale=2;session.clock.effective=3;sample(.55,6)
assert(by.other.plays==oldVariants+1,'A speed-specific continuous source must switch to its new bucket')
assert(by.ambience.voices[1].requested==2,'Generic clips must use native-game speed only')
assert(by.ambience.plays==oldGeneric,'Generic continuous sources must retain their playing clip on speed changes')
assert(by.other.voices[1].clip.path:find('v1.5',1,true)and by.other.voices[1].rate==2,'Selected variants must scale by game time independently of their scene bucket')
sample(.75,8);assert(by.first.last_path:find('v1.5',1,true))
local before=by.ambience.plays
session.preparing=true;S.guard(ctx);assert(by.ambience.voices[1].paused)
-- A rebuild can radically move the sampled bones while the scene pose is held.
p.b.actor.points.hand.X=2;p.c.actor.points.hand.X=2
session.preparing=false;S.prepare(ctx,session);S.enter(ctx)
assert(by.ambience.plays==before and not by.ambience.voices[1].paused,'Outfit preparation restarted a continuous clip')
local impacts=by.first.plays;sample(.80,8);assert(by.first.plays==impacts,'Rebuild recovery invented a closest approach')
-- High rates obey the native pitch cap and budget actual clip playback time.
session.clock.scale=8;session.clock.effective=16;session.clock.index=4;sample(.90,6)
assert(by.ambience.voices[1].rate==4 and by.ambience.voices[1].requested==8)
for i=1,16 do sample(.90+i*.10,i%2==0 and 8 or 6)end
assert(#by.first.voices<=2 and #by.second.voices<=2,'Triggered polyphony grew without bound')
-- Every continuous source avoids repeating its own immediately preceding clip.
local seen={}
for _,event in ipairs(plays)do
 if event.owner=='1'then assert(seen.generic~=event.path,'Continuous randomization repeated immediately');seen.generic=event.path end
end
S.leave_node(ctx);count=#plays;sample(4,6);assert(#plays==count,'Leaving a node kept triggering audio')
fail_destroy=true;assert(not pcall(S.restore,ctx));S.restore(ctx);S.restore(ctx)
assert(created==destroyed,'Owned audio leaked or cleanup was duplicated')
-- An optional missing set cannot prevent other valid emitters or scene entry.
unavailable=true
local missing=S.load(node);missing.node=node;S.prepare(missing,session);S.enter(missing)
assert(by.ambience and #missing.emitters==4)
count=#plays;S.sample(missing);assert(#plays==count)
unavailable=false;session.clock.session_elapsed=10;session.clock.game_elapsed=10;S.sample(missing)
assert(#plays>count,'Missing optional audio did not recover after its bounded retry')
fail_stop=true;assert(not pcall(S.restore,missing));S.restore(missing)
assert(created==destroyed)
-- At requested rate 8 and native cap 4, a 1-second clip lasts 2 native-game
-- seconds. Scheduling by requested rate would incorrectly cut it off at 1.
session.clock={session_elapsed=0,game_elapsed=0,scale=8,effective=16,index=4}
local capped=S.load({sfx={ambience=node.sfx.ambience}})
S.prepare(capped,session);S.enter(capped)
local started=#plays
session.clock.game_elapsed=1.9;S.sample(capped)
assert(#plays==started,'A capped clip was restarted before its actual duration')
session.clock.game_elapsed=2.1;S.sample(capped)
assert(#plays==started+1,'A completed capped clip did not continue')
S.restore(capped);assert(created==destroyed)
-- Subtle cyclic motion must not disappear at high frame rates. Every
-- individual frame moves less than the configured 1 mm reversal threshold.
for _,fps in ipairs({45,144})do
 local spec=impact('b')
 local slow=S.load({sfx={contact=spec}})
 session.clock={session_elapsed=0,game_elapsed=0,scale=1,effective=1,index=2}
 p.b.actor.points.hand.X=10.2
 S.prepare(slow,session);S.enter(slow)
 for i=1,6*fps do
  session.clock.session_elapsed=i/fps;session.clock.game_elapsed=i/fps
  p.b.actor.points.hand.X=10+.2*math.cos(2*math.pi*i/fps)
  S.sample(slow)
 end
 assert(slow.emitters[1].plays==6,'Sub-frame motion lost closest approaches at '..fps..' FPS')
 S.restore(slow);assert(created==destroyed)
end
-- Scene speed selects variants but never changes clip rate or the kiss gap.
-- Native-game speed changes both, including mid-clip updates and pause.
for _,index in ipairs({1,2,3,4})do
 session.clock={session_elapsed=0,game_elapsed=0,scale=1,effective=({.5,1,1.5,2})[index],index=index}
 local stable=S.load({sfx={ambience=node.sfx.ambience,other=node.sfx.other}})
 S.prepare(stable,session);S.enter(stable)
 for _,emitter in ipairs(stable.emitters)do assert(emitter.voices[1].requested==1,'Scene speed changed clip pitch')end
 local initial=#plays
 session.clock.game_elapsed=.9;session.clock.session_elapsed=.9*session.clock.effective;S.sample(stable)
 assert(#plays==initial,'Scene speed shortened a continuous clip')
 session.clock.game_elapsed=1.1;session.clock.session_elapsed=1.1*session.clock.effective;S.sample(stable)
 assert(#plays==initial+2,'Scene speed stretched a continuous clip')
 session.clock.scale=2;session.clock.effective=2*({.5,1,1.5,2})[index];S.sample(stable)
 for _,emitter in ipairs(stable.emitters)do assert(emitter.voices[1].requested==2,'Native-game speed did not retime active clip')end
 S.restore(stable);assert(created==destroyed)
end
for _,scale in ipairs({.1,.5,.999})do
 session.clock={session_elapsed=0,game_elapsed=0,scale=scale,effective=scale,index=2}
 local slow=S.load({sfx={ambience=node.sfx.ambience}});S.prepare(slow,session);S.enter(slow)
 local emitter=slow.emitters[1];local voice=emitter.voices[1];assert(voice.rate==1)
 local started=emitter.plays;session.clock.game_elapsed=.75*scale;S.sample(slow)
 assert(math.abs(voice.remaining-.25)<.00001 and emitter.plays==started,'Slow motion must not stretch audio duration')
 session.clock.scale=0;S.sample(slow);assert(voice.paused and math.abs(voice.remaining-.25)<.00001)
 session.clock.scale=scale;session.clock.game_elapsed=1.01*scale;S.sample(slow)
 assert(emitter.plays==started+1 and voice.rate==1,'Continuous clips must finish/recycle normally')
 S.restore(slow);assert(created==destroyed)
end
print('SFX passed: closest approach/plateau/cooldown, four simultaneous emitters, repeated-body ownership, midpoint sources, speed buckets, shared pause/rates, capped pitch timing, bounded polyphony, outfit holds, optional recovery and retryable cleanup.')

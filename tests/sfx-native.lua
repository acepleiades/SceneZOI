package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local count,dead,fail={},false,false
local function bump(k)count[k]=(count[k]or 0)+1 end
local actor={}
function actor:AddComponentByClass(class,manual,transform,deferred)
 assert(class=='audio'and manual and not deferred);bump('create')
 local c={alive=true}
 function c:SetUISound(value)assert(value==false);self.ui=value end
 function c:AdjustAttenuation(value)
  assert(value.bAttenuate and value.bSpatialize and value.AttenuationShape==0)
  assert(value.AttenuationShapeExtents.X==70 and value.FalloffDistance==600)
  self.attenuation=value
  if fail then fail=false;error('partial configure failure')end
 end
 function c:SetVolumeMultiplier(v)self.volume=v end
 function c:K2_SetWorldLocation(p)self.position=p end
 function c:SetPitchMultiplier(v)self.rate=v;bump('pitch')end
 function c:SetPaused(v)self.paused=v end
 function c:SetSound(asset)assert(asset.alive);self.sound=asset end
 function c:Play(start)assert(start==0);self.playing=true;bump('play')end
 function c:IsPlaying()return self.playing end
 function c:Stop()bump('stop');if dead then dead=false;error('retry Stop')end end
 function c:K2_DestroyComponent(owner)assert(owner==actor);self.alive=false;bump('destroy')end
 return c
end
local wave={alive=true,Duration=1.7,IsA=function(_,cls)return cls=='wave'end}
UE={UObject={Load=function(path)
 if path=='/Script/Engine.Default__AudioSettings'then return {GlobalMinPitchScale=.4,GlobalMaxPitchScale=2}end
 bump('load');return wave
end},USoundWave={StaticClass=function()return 'wave'end},UAudioComponent={StaticClass=function()return 'audio'end},
UKismetSystemLibrary={IsValid=function(obj)return obj~=nil and obj.alive end},
FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FTransform=function()return {}end,FSoundAttenuationSettings=function()return {}end}
package.loaded['SceneZOI.GazeNative']={target=function(binding)return binding.position end}
local N=require('SceneZOI.SoundNative')
local spec={volume=.6,attenuation={radius_cm=70,falloff_cm=600}}
local clip=N.load('/Test/Sound.Sound');assert(clip.duration==1.7)
local pos=N.position({a={position={X=2,Y=4,Z=6}},b={position={X=4,Y=6,Z=8}}},{{participant='a'},{participant='b'}})
assert(pos.X==3 and pos.Y==5 and pos.Z==7)
local v={};fail=true;assert(not pcall(N.create,v,actor,spec));assert(v.component and not v.configured,'Partial component ownership lost')
N.create(v,actor,spec);assert(count.create==1 and v.configured)
assert(v.component.bAllowSpatialization and v.component.ui==false and v.component.volume==.6)
N.volume(v,.25);assert(v.component.volume==.25)
N.play(v,clip,pos,8);assert(v.rate==2 and v.requested==8 and v.limit_source=='native'and v.component.rate==2)
N.tune(v,8,true);assert(v.component.paused and count.pitch==1)
for _,scale in ipairs({.001,.1,.5,.999,1})do
 N.tune(v,scale,false);assert(v.component.rate==1 and v.rate==1 and not v.component.paused,'Positive slow motion must retain normal audio pitch')
end
N.tune(v,.1,true);assert(v.component.paused and v.rate==1,'Pause stays separate from audio rate')
N.tune(v,.1,false);assert(not v.component.paused and v.rate==1)
N.tune(v,1.5,false);assert(v.rate==1.5,'Native fast-forward remains supported')
v.remaining=-.05;assert(not N.finished(v),'Estimated expiry must not truncate a native clip still playing')
assert(v.tail_waits==1);assert(not N.finished(v)and v.tail_waits==1)
N.pause(v,true);v.remaining=-3;assert(not N.finished(v),'Pause must never trigger completion/watchdog')
N.pause(v,false);assert(N.finished(v),'Broken never-finishing audio must be bounded')
v.remaining=-.05;v.component.playing=false;assert(N.finished(v),'A natural native finish releases the voice')
v.component.playing=true;v.component.IsPlaying=nil;assert(N.finished(v),'Unavailable native state retains the timer fallback')
v.component.IsPlaying=function(self)return self.playing end
dead=true;assert(not pcall(N.destroy,v));assert(not v.destroyed,'Failed stop abandoned ownership')
N.destroy(v);N.destroy(v);assert(count.destroy==1)
-- Recreated components must receive settings and pitch even when the old voice
-- had cached the same values. Invalid old components are not mutated.
N.create(v,actor,spec);N.play(v,clip,pos,1);assert(v.component.rate==1 and v.configured)
local old=v.component;old.alive=false
N.create(v,actor,spec);assert(v.component~=old and v.configured);N.play(v,clip,pos,1);assert(v.component.rate==1)
local stale=wave;wave.alive=false;wave={alive=true,Duration=1.7,IsA=function()return true end}
UE.UKismetSystemLibrary.IsValid=function(obj)if obj==stale then error('unknown tombstone validity')end;return obj~=nil and obj.alive end
N.play(v,clip,pos,1);assert(count.load==5 and clip.asset==wave,'Collected asset was not reloaded')
N.destroy(v);assert(count.destroy==2 and count.create==3)
print('Native SFX passed: moving world midpoint, owned spatial components, attenuation, pause/native pitch bounds, partial setup, stale component/asset recovery and retryable owned cleanup.')

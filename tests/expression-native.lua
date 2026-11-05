package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local head,current,fail_stop
local now=0
UE={UKismetSystemLibrary={IsValid=function(v)return v~=nil and not v.dead end},
    UGameplayStatics={GetTimeSeconds=function()return now end}}
package.loaded["SceneZOI.GazeNative"]={head=function()return head end}
local function instance()
    local i={montages={},stopped={},other={}}
    function i:GetName()return {}end
    function i:PlaySlotAnimationAsDynamicMontage(asset,slot,blend)
        assert(slot=="DefaultSlot");local montage={asset=asset};self.montages[montage]=true;return montage
    end
    function i:Montage_SetPlayRate(m,rate)assert(rate==0)end
    function i:Montage_SetPosition(m,p)assert(self.montages[m]);m.position=p end
    function i:Montage_IsActive(m)
        if self.query_error then error("temporary native query failure") end
        return self.montages[m]
    end
    function i:Montage_Stop(blend,m)
        assert(m~=self.other,"Stopped unrelated playback")
        if fail_stop then fail_stop=false;error("cleanup failure")end
        self.stopped[m]=(self.stopped[m] or 0)+1;self.montages[m]=nil
    end
    return i
end
current=instance()
local asset={GetName=function()return "/Game/Characters/SKM_Female_Base"end}
head={GetAnimInstance=function()return current end,GetSkeletalMeshAsset=function()return asset end}
local N=require("SceneZOI.ExpressionNative")
local owner={actor={Mesh=head},body="male"}
assert(N.body(owner)=="female","Use the actual skeletal appearance instead of role or biology")
assert(N.bind(owner));local original=current
local a={asset={},sample=0};N.play(owner,a,.25);local first=owner.montage
local b={asset={},sample=2};N.play(owner,b,.25)
assert(owner.montage~=first and original.stopped[first]==1)
assert(owner.instance==original)
N.hold(owner)
assert(#owner.leases==2,"A montage that is blending out must remain owned until its blend deadline")
now=1;original.query_error=true
local ok=pcall(N.hold,owner);original.query_error=false
assert(ok and #owner.leases==2,"A failed query must not retire live ownership")
-- Cleanup has to retry a transient native call instead of assuming destruction.
local getName=original.GetName;original.GetName=function()error("temporary name query failure")end
fail_stop=true;assert(not pcall(N.stop,owner));original.GetName=getName
N.stop(owner)
assert((original.stopped[first] or 0)>=2,"Cleanup forgot the outgoing owned montage")
N.play(owner,b,.25)
current=instance();N.hold(owner)
assert(owner.instance==current and owner.clip==b and owner.montage.position==2)
fail_stop=true;assert(not pcall(N.stop,owner));N.stop(owner)
for _,lease in ipairs(owner.leases)do assert(lease.released)end
assert(not owner.clip and not owner.montage)
-- Retirement follows native world time, so a paused blend stays owned. Once
-- completed, many selections must not accumulate a session's entire history.
local bounded={actor=owner.actor}
N.play(bounded,a,.25);N.play(bounded,b,.25)
for _=1,50 do N.hold(bounded) end
assert(#bounded.leases==2,"A paused native blend was retired early")
for _=1,100 do
    now=now+1;N.hold(bounded)
    assert(#bounded.leases==1,"Completed blends accumulated ownership")
    N.play(bounded,a,.25)
end
N.stop(bounded)
local dying={actor=owner.actor};N.play(dying,a,0)
dying.instance.dead=true;N.stop(dying);dying.instance.dead=false
assert(not dying.clip,"Destroyed instances must not block cleanup")
print("Expression native passed: skeletal body, owned head montage, replacement-instance recovery, held pose and retryable complete cleanup.")

-- Native dynamic montages can be collected while their animation instance lives.
-- With no validity helper exposed, the typed argument rejection proves the stale handle.
local stale={actor=owner.actor};N.play(stale,a,0)
local valid=UE.UKismetSystemLibrary.IsValid
UE.UKismetSystemLibrary.IsValid=function()error("validity helper unavailable")end
local stop=stale.instance.Montage_Stop
stale.instance.Montage_Stop=function(_,_,m)
    if m==stale.montage then error("bad argument #2 to 'Montage_Stop' (object needed but got nil or incompatible value)")end
end
assert(pcall(N.stop,stale),"Collected owned montages blocked Exit cleanup")
assert(not stale.clip)
stale.instance.Montage_Stop=stop;UE.UKismetSystemLibrary.IsValid=valid

-- Ordinary native face clips retain blink motion; authored fixed poses do not.
local moving={actor=owner.actor}
local animated={asset={},sample=0,duration=3,animated=true}
N.play(moving,animated,0,0);N.hold(moving,1);assert(moving.position==1)
N.hold(moving,1);N.hold(moving);assert(moving.position==1,'Pause/guard must not advance facial time')
N.hold(moving,4.5);assert(moving.position==1.5,'Facial clips loop without freezing their blink frames')
current=instance();N.hold(moving,5);assert(moving.position==2 and moving.montage.position==2,'Head replacement must preserve facial time')
N.stop(moving)
N.play(moving,{asset={},sample=2,duration=3,animated=false},0,0);N.hold(moving,5);assert(moving.position==2,'Explicit sample must remain held')
N.stop(moving)
print('Facial motion passed: advancing/looping native clips, pause, held guards, replacement recovery and explicit fixed poses.')

-- Reproduce native automatic fade near the end while sampled time loops.
-- A strong mood is visible whenever that fade drops our owned face weight.
current=instance();local montage_count=0
local play=current.PlaySlotAnimationAsDynamicMontage
function current:PlaySlotAnimationAsDynamicMontage(asset,slot,blend)
 montage_count=montage_count+1;local m=play(self,asset,slot,blend);m.bEnableAutoBlendOut=true;return m
end
local set_position=current.Montage_SetPosition
function current:Montage_SetPosition(m,position)
 set_position(self,m,position)
 if m.bEnableAutoBlendOut and position>=2.65 then self.montages[m]=nil end
end
local face={actor=owner.actor};N.play(face,{asset={},sample=0,duration=3,animated=true},.35,0)
for frame=1,900 do N.hold(face,frame/30);assert(current.montages[face.montage],'Automatic blend exposed the native mood pose')end
assert(montage_count==1 and not face.montage.bEnableAutoBlendOut,'A looping expression must stay owned through every end window')
local owned=face.montage;N.stop(face);assert(not current.montages[owned],'Explicit Exit must still stop the owned face')
print('Facial end-fade regression passed: 10 loops with a competing mood fallback, no automatic fade/replay, and explicit release.')

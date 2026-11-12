local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
local active, rates, positions = {}, {}, {}
local foreign, now
local play_order, stop_order, order = {}, {}, 0
local reject_play=false
local instance = {}
function instance:PlaySlotAnimationAsDynamicMontage(asset,slot,blend_in,blend_out,rate,loops)
    assert(slot=="DefaultSlot" and blend_in==0 and blend_out==0)
    if reject_play then return nil end
    local montage={asset=asset};active[montage]=true
    order=order+1;play_order[montage]=order
    return montage
end
function instance:Montage_SetPlayRate(montage,rate) rates[montage]=rate end
function instance:Montage_SetPosition(montage,position) positions[montage]=position end
function instance:GetCurrentActiveMontage() return foreign end
function instance:Montage_IsActive(montage) return active[montage] or false end
function instance:Montage_Stop(blend_out,montage)
    assert(blend_out==0);active[montage]=nil
    order=order+1;stop_order[montage]=order
end
local unrelated={};active[unrelated]=true
local mesh={}
function mesh:GetAnimationMode() return 0 end
function mesh:GetAnimInstance() return instance end
function mesh:GetRelativeTransform() return {} end
function mesh:PlayAnimation() error("The game's animation instance must never be replaced") end
function mesh:SetAnimInstanceClass() error("The game's animation instance must never be recreated") end
local movement={MovementMode=1,CustomMovementMode=0}
function movement:StopMovementImmediately() end
function movement:DisableMovement() self.MovementMode=0 end
function movement:SetMovementMode(mode,custom) self.MovementMode,self.CustomMovementMode=mode,custom end
local actor={Mesh=mesh,CharacterMovement=movement,collision=true,transform={}}
function actor:GetTransform() return self.transform end
function actor:GetActorEnableCollision() return self.collision end
function actor:SetActorEnableCollision(value) self.collision=value end
local attached={};function actor:GetAttachedActors() return attached end
local placements = 0
function actor:K2_SetActorTransform(value)
    placements = placements + 1
    self.transform = value
end
local focused=false
local controller={ChangeUIInputMode=function(self,mode,force) assert(mode==1 and force);focused=true end}
UE={UObject={Load=function()return "carried"end},AStaticMeshActor={StaticClass=function()return "mesh"end},
    UGameplayStatics={GetPlayerController=function() return controller end, GetRealTimeSeconds=function() return now end},
    UWidgetBlueprintLibrary={SetFocusToGameViewport=function() assert(focused) end},
    UKismetMathLibrary={InvertTransform=function(t) return t end,ComposeTransforms=function(_,anchor) return anchor end,
        NearlyEqual_TransformTransform=function(a,b) return a == b end}}
inzoi={EB1UIInputMode={CursorMode=1},cli={execute=function()end}}
local Native=require("SceneZOI.Native")
do
    local overlay = {}
    local load, cli = UE.UObject.Load, inzoi.cli.execute
    UE.UObject.Load=function(path)
        assert(path=="/Game/Reading/ReadMontage.ReadMontage")
        return overlay
    end
    inzoi.cli.execute=function(command)
        assert(command=="data.table_get alias=AnimCharacter row=Read")
        return true,"",[[{"characterAnimConfigList":[{"animInfoList":[{"animation":"/Game/Reading/ReadMontage.ReadMontage"}]}]}]]
    end
    active[overlay]=true
    local record=Native.capture(actor)
    assert(Native.cut_task_overlays(record,"Read:OtherMontage")==0 and active[overlay])
    assert(Native.cut_task_overlays(record,"Read:ReadMontage")==1 and not active[overlay] and active[unrelated])
    assert(Native.cut_task_overlays(record,"Read:ReadMontage")==0)
    UE.UObject.Load, inzoi.cli.execute = load, cli
end
for _=1,20 do
    local record=Native.capture(actor)
    Native.enter(record,{}, {})
    assert(mesh:GetAnimInstance()==instance and mesh:GetAnimationMode()==0)
    assert(movement.MovementMode==0 and not actor.collision)
    assert(rates[record.montage]==0)
    local placements_at_entry = placements
    Native.sample(record,1.5);assert(positions[record.montage]==1.5 and placements==placements_at_entry)
    actor.transform = {} -- Native gameplay or another mod moved the actor.
    Native.sample(record,1.6)
    assert(placements==placements_at_entry+1 and actor.transform==record.desired and positions[record.montage]==1.6)
    Native.sample(record,1.7);assert(placements==placements_at_entry+1)
    local original_transform = record.transform
    local first_montage = record.montage
    Native.stop_track(record)
    assert(not active[first_montage] and active[unrelated])
    Native.rebind(record)
    Native.enter(record,{}, {})
    assert(record.transform == original_transform and record.movement_mode == 1,
        "A node change overwrote the session restoration state")
    Native.restore(record);Native.restore(record)
    assert(not active[record.montage] and active[unrelated])
    assert(mesh:GetAnimInstance()==instance and movement.MovementMode==1 and actor.collision)
end
local function prop(class,socket,hidden)
    local object={bHidden=hidden}
    function object:IsA(wanted) return class==wanted end
    function object:GetAttachParentSocketName() return socket end
    function object:SetActorHiddenInGame(value)
        if self.fail_restore and not value then error("injected prop restoration failure") end
        self.bHidden=value
    end
    return object
end
local book=prop("carried","SOC_catch_r_FX",false)
local phone=prop("mesh","SOC_catch_l_FX",false)
local already_hidden=prop("mesh","SOC_catch_r_FX",true)
local child=prop("character","SOC_catch_l_FX",false)
local backpack=prop("mesh","spine_03",false)
attached={book,phone,already_hidden,child,backpack}
local held_record=Native.capture(actor)
Native.enter(held_record,{}, {})
assert(book.bHidden and phone.bHidden and already_hidden.bHidden and not child.bHidden and not backpack.bHidden)
local hidden_before_destruction=phone.bHidden
phone.bHidden=nil
setmetatable(phone,{__index=function()error("destroyed actor")end})
book.fail_restore=true
assert(not pcall(Native.restore,held_record) and actor.collision,"A failed prop restore must leave other restoration independent")
book.fail_restore=false
Native.restore(held_record)
assert(not book.bHidden and already_hidden.bHidden and hidden_before_destruction and next(held_record.hidden_hand_props)==nil)
attached={}
-- Exit after an outfit rebuild but before the next node has begun playback.
local record=Native.capture(actor)
Native.enter(record,{}, {})
Native.stop_track(record)
local previous=instance
instance=setmetatable({}, {__index=previous})
Native.restore(record)
assert(mesh:GetAnimInstance()==instance and movement.MovementMode==1 and actor.collision and active[unrelated],
    "Early Exit during appearance rebuilding must preserve the new game-owned instance and restore movement")
-- Same-instance handoff must install the new player before stopping the old one.
record=Native.capture(actor)
local old_asset,anchor={},{}
Native.enter(record,old_asset,anchor);Native.sample(record,2.75)
local old_montage=record.montage
local original_transform,original_mode=record.transform,record.movement_mode
for _=1,20 do
    assert(Native.hold(record,anchor))
    assert(record.montage==old_montage and active[old_montage] and positions[old_montage]==2.75 and rates[old_montage]==0)
end
local next_asset={}
Native.enter(record,next_asset,anchor)
assert(play_order[record.montage]<stop_order[old_montage] and not active[old_montage] and active[record.montage])
assert(record.transform==original_transform and record.movement_mode==original_mode and active[unrelated])

-- A game-owned instance rebuild must reacquire the exact outgoing pose without
-- modifying the restoration snapshot or leaving a detached scene player.
Native.sample(record,1.25)
old_montage=record.montage
previous=instance
instance=nil
assert(not Native.hold(record,anchor),"An absent animation instance must block the handoff")
instance=setmetatable({}, {__index=previous})
assert(Native.hold(record,anchor))
assert(record.instance==instance and record.asset==next_asset and positions[record.montage]==1.25)
assert(not active[old_montage] and active[record.montage] and record.between_nodes)
assert(record.transform==original_transform and record.movement_mode==original_mode)
old_montage=record.montage
active[old_montage]=nil
assert(Native.hold(record,anchor) and record.montage~=old_montage and positions[record.montage]==1.25,
    "A rebuild that clears montages on the same instance must recover the held pose")
reject_play=true
old_montage=record.montage
assert(not pcall(Native.enter,record,{},anchor) and record.montage==old_montage and active[old_montage],
    "A rejected target track must not discard ownership of the outgoing player")
reject_play=false
-- Early Exit between a rebuild and the next hold still cleans the old owner.
record.between_nodes=true
previous=instance;instance=setmetatable({}, {__index=previous})
Native.restore(record)
assert(not active[old_montage] and active[unrelated] and movement.MovementMode==1 and actor.collision)
-- Native avoidance may preempt one track. Resume at the shared position
-- without touching foreign tracks or recapturing the restoration snapshot.
record=Native.capture(actor)
local asset={}
Native.enter(record,asset,anchor)
original_transform=record.transform
local function interrupt(name)
    active[record.montage]=nil
    foreign={GetName=function()return name end}
end
now=0
for i=1,3 do
    local prior=record.montage
    interrupt("ANIM_F_Avoid_L45_Interaction_Montage")
    Native.sample(record,1.25)
    assert(record.montage~=prior and record.asset==asset and positions[record.montage]==1.25)
    assert(record.transform==original_transform and active[unrelated])
end
interrupt("ANIM_F_Avoid_positive_Reaction_B_Interaction_Montage")
assert(not pcall(Native.sample,record,1.5),"Persistent preemption must still take the failure path")
now=2.1
Native.sample(record,1.5)
interrupt("ANIM_F_SomeOther_Interaction_Montage")
Native.sample(record,1.6)
assert(positions[record.montage]==1.6,"Any other clip is taken back too")
Native.restore(record)
-- Whatever takes the slot is taken back, whoever the player controls, within the same bound.
local function take_back(name)
    local prior=record.montage
    interrupt(name)
    Native.sample(record,2.5)
    assert(record.montage~=prior and record.asset==asset and positions[record.montage]==2.5,'The track resumes at the shared position')
end
local function emptied()
    local prior=record.montage
    active[record.montage]=nil;foreign=nil
    Native.sample(record,2.5)
    assert(record.montage~=prior and positions[record.montage]==2.5,'An empty slot resumes at the shared position')
end
now=10
for _,control in ipairs({'npc','controlled'})do
    record=Native.capture(actor);record.control=control;record.id='7'
    Native.enter(record,asset,anchor)
    now=now+10
    take_back('ANIM_M_BroomTray_Use_Interaction_Montage')
    assert(active[unrelated],'Only the scene track is touched')
    take_back('ANIM_F_Clap_Stand_Montage')
    take_back('ANIM_F_turn_R_90_Locomotion_Montage')
    interrupt('ANIM_M_Something_Else_Montage')
    assert(not pcall(Native.sample,record,2.6),'A game that keeps taking the slot still ends the scene')
    now=now+3
    Native.enter(record,asset,anchor)
    emptied()
    active[record.montage]=nil;foreign=nil
    now=now+0.1
    Native.sample(record,2.5)
    now=now+3
    for count=1,8 do take_back('ANIM_F_Clap_Stand_Montage');now=now+3 end
    Native.restore(record)
end
print("Track recovery passed: any clip or empty slot, on any Zoi, at the shared position, with a repeat limit but no cap over a scene.")

Native.release_input(actor)
print("Native adapter checks passed: original animation instance preserved across 20 sessions; only owned montages stopped; movement/collision restored; game input routing used.")
print("Native handoff checks passed: no empty-slot preparation interval, exact pose hold, game-owned instance replacement/recovery, rejected target and early Exit cleanup.")

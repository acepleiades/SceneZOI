-- Queue ownership must stop a backlog without waiting for every queued task.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local Json=require('SceneZOI.Json')
local restored=0
package.loaded['SceneZOI.Outfit']={borrowable=function()end,recover=function()end,apply=function()end,restore=function()restored=restored+1 end}
package.loaded['SceneZOI.Wardrobe']={capture=function()end,inventory=function()return 'inventory'end}
package.loaded['SceneZOI.SceneData']={simulation=function(n)return n end}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
local replies,owners={},{}
local clear_failure,cancel_failure=false,false
inzoi={EB2ComponentType={Appearance=1,Autonomy=2,Interaction=3,Posture=4},EB1HandType={LeftHand=0,RightHand=1},EB1GenderType={Female=1,Male=2},
 cli={execute=function(c)
  local o=owners[c:match('entity_id=(%d+)')]
  if c=='entity.get_possessed'then return true,'','{"entity_id":1}'end
  if c:match('^interaction.clear_queue')then
   assert(not c:find('cancel_current=true',1,true),'Let the current task finish its normal cancellation')
   if clear_failure then clear_failure=false;return false,'Injected queue clear failure'end
   o.queued=0;o.clears=o.clears+1;return true
  end
  if c:match('^interaction.cancel')then
   assert(o.queued==0,'Clear the waiting backlog before cancelling the current task')
   if cancel_failure then cancel_failure=false;return false,'Injected cancellation failure'end
   o.cancels=o.cancels+1;o.cancel_delay=2;return true
  end
  if c:match('^motion.get_current') then
   return true,'',Json.encode({playing=#o.motions>0,motions=o.motions})
  end
  if c:match('^motion.stop') then
   assert(not o.playing,'Native fallback stop must wait for cancellation')
   o.stopped[#o.stopped+1]=assert(c:match(' anim_id=([%w_]+)$'),'Stop only a specific motion')
   return true
  end
  error('Unexpected command '..c)
 end},message={send_to_client=function(id,kind,packet)if kind=='SceneZOI.Reply'then replies[id.Value]=packet end end}}
local function owner(id)
 local o={id=id,queued=0,playing=false,current=1,clears=0,cancels=0,collision=true,motions={},stopped={},grabs={},stopped_grabs={},restored_grabs={},grab_ids={},
  AutonomyOption={AutonomyEnable={Value=true,bFollowParent=true}}}
 function o:GetEntityId()return {Value=self.id}end
 function o:GetComponent(t)
  if t==1 then return {GetAppearanceSetting=function()return {Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}end}end
  if t==3 then return {IsQueueEmpty=function()return self.queued==0 end,GetCurrentInteractionQueueId=function()return self.current end}end
  if t==4 then return {
    GetCurrentGrabObject=function(_,hand)return self.grabs[hand]end,
    GetGrabState=function(_,hand)return {EntityId={Value=self.grabs[hand]},GrabId=self.grab_ids[hand] or "Hold"}end,
    StopGrabLoopAnimation=function(_,hand)self.stopped_grabs[#self.stopped_grabs+1]=hand end,
    SetGrabId=function(_,hand,id)
        self.grab_ids[hand]=id
        if id~="None" then self.restored_grabs[#self.restored_grabs+1]=hand end
    end,
  }end
  return {OnAutonomyOptionChanged=function()end,SendAutonomyEnablePacket=function()end}
 end
 function o:GetAutonomyOption()return self.AutonomyOption end
 function o:GetLocation()return UE.FVector(0,0,0)end
 function o:GetRotation()return UE.FRotator(0,0,0)end
 function o:IsCollisionEnabled()return self.collision end
 function o:SetCollisionEnabled(v)self.collision=v;self.collision_writes=(self.collision_writes or 0)+1 end
 function o:SetLocationAndRotationOnlySimul()self.position_writes=(self.position_writes or 0)+1 end
 function o:IsPlayingInteraction()return self.playing end
 function o:IsAutonomyEnable()return self.AutonomyOption.AutonomyEnable.Value end
 function o:RefreshAutonomyOptionCache()self.autonomy_refreshes=(self.autonomy_refreshes or 0)+1 end
 owners[tostring(id)]=o;return o
end
local M=assert(loadfile('modkit/SceneZOI_93C44199/workspace/lua/B2/Zoi/SceneZOI.lua'))()
local node={id='test.idle',participants={lead={body='female'}}}
local function start(s,o,token)
 M.on_lua_message(s,o,'SceneZOI.Prepare',P.pack(token,'1',node.id,1,'0','lead',P.encode(Json.encode(node))))
 M.on_lua_message(s,o,'SceneZOI.Commit',P.pack(token))
end
local function tick(s,o)
 if o.cancel_delay then
  o.cancel_delay=o.cancel_delay-1
  if o.cancel_delay==0 then
   o.cancel_delay=nil;o.playing=false
   if o.queued>0 then o.queued=o.queued-1;o.current=o.current+1;o.playing=true end
  end
 end
 M.on_tick(s,o,.1)
end
local function release(s,o,token)
 M.on_lua_message(s,o,'SceneZOI.Release',P.pack(token))
 assert(not s.lease and o.collision and o.AutonomyOption.AutonomyEnable.Value and o.AutonomyOption.AutonomyEnable.bFollowParent)
end
local s,o={},owner(1);M.on_begin(s,o)
M.on_lua_message(s,o,'SceneZOI.Prepare',P.pack('abort-snapshot','1',node.id,1,'0','lead',P.encode(Json.encode(node))))
release(s,o,'abort-snapshot')
assert(not o.position_writes and not o.collision_writes and not o.autonomy_refreshes,
 'Abort before commit must not restore unmodified native properties')
start(s,o,'abort-commit')
assert(not s.lease.ready)
release(s,o,'abort-commit')
assert(not o.position_writes and not o.collision_writes and o.autonomy_refreshes==2,
 'Abort after commit restores autonomy while leaving unowned position and collision alone')
o.playing=true;o.queued=30;start(s,o,'backlog')
assert(o.queued==0 and o.cancels==1,'A backlog must be cleared before interruption, not drained one task at a time')
assert(s.lease and not s.lease.ready and not o.AutonomyOption.AutonomyEnable.Value)
tick(s,o);assert(not s.lease.ready and o.cancels==1,'Do not mark ready during asynchronous cancellation or spam cancel')
for _=1,4 do tick(s,o)end
assert(s.lease.ready and not o.playing and not o.collision)
-- New commands and autonomy changes during playback must not escape scene ownership.
M.on_lua_message(s,o,'SceneZOI.Anchor',P.pack('backlog',1,2,3,0,0,0))
o.AutonomyOption.AutonomyEnable.Value=true
o.AutonomyOption.AutonomyEnable.bFollowParent=true
o.queued=5;tick(s,o)
assert(o.queued==0 and o.cancels==1 and not o:IsAutonomyEnable() and not o.AutonomyOption.AutonomyEnable.bFollowParent)
local refreshes=o.autonomy_refreshes
tick(s,o)
assert(o.autonomy_refreshes==refreshes,'Do not send redundant autonomy packets while the lease is held')
o.playing=true;o.current=2;o.queued=3;tick(s,o)
assert(o.queued==0 and o.cancels==2,'Cancel a different current task even if the lease was already ready')
tick(s,o);assert(o.cancels==2);tick(s,o);tick(s,o)
release(s,o,'backlog')
-- A single talk interaction still follows normal cancellation and becomes ready.
o.playing=true;o.current=3;start(s,o,'talk');for _=1,5 do tick(s,o)end
assert(s.lease.ready and o.cancels==3);release(s,o,'talk')
-- Waiting-only queues cannot start between idle preparation samples.
o.queued=40;start(s,o,'waiting');tick(s,o)
assert(s.lease.ready and o.queued==0);release(s,o,'waiting')
-- Task cleanup follows the native group and interruption flag, independent of animation names.
o.motions={
 {anim_id='MovingChair_Sit',group='PostureGroup',non_interruptible=false},
 {anim_id='Dish_Eat_Stand',group='UpperGroup',non_interruptible=false},
 {anim_id='Snack_Eat_Stand',group='DefaultGroup',non_interruptible=false},
 {anim_id='ReadingLoop',montage_id='ReadMontage',group='UpperGroup',non_interruptible=false},
 {anim_id='Other_Arm_Action',group='LeftArmGroup',non_interruptible=false},
 {anim_id='NativeProtected',montage_id='ProtectedMontage',group='RightArmGroup',non_interruptible=true},
 {anim_id='Unclassified',group='UpperGroup'},
}
o.grabs={[0]=9,[1]=12}
o.playing=true;o.current=4;o.queued=3;start(s,o,'task-overlays')
assert(o.queued==0,'Clear the backlog even while the current montage cut is pending')
assert(#o.stopped==0 and #o.stopped_grabs==0 and o.cancels==3)
assert(replies[1]==P.pack("task-overlays","overlay_cut","ReadingLoop:ReadMontage",1))
M.on_lua_message(s,o,"SceneZOI.OverlayCut",P.pack("task-overlays",2))
o.AutonomyOption.AutonomyEnable.Value=true
tick(s,o);assert(o.cancels==3,"A stale revision must not unblock the cut")
assert(not o:IsAutonomyEnable(),'Disable autonomy again if it is re-enabled during preparation')
M.on_lua_message(s,o,"SceneZOI.OverlayCut",P.pack("task-overlays",1))
tick(s,o);assert(o.cancels==4,"Cancel after the targeted client cut")
for _=1,5 do tick(s,o)end
assert(s.lease.ready and table.concat(o.stopped,",")=="Dish_Eat_Stand,ReadingLoop,Other_Arm_Action")
assert(table.concat(o.stopped_grabs,",")=="0,1" and o.grab_ids[0]=="None" and o.grab_ids[1]=="None")
assert(s.lease.save_snapshot.grab_poses[2].id=="12")
o.AutonomyOption.AutonomyEnable.Value=true
tick(s,o);assert(not o:IsAutonomyEnable(),'A ready participant still waits for the scene anchor')
assert(#o.stopped==3 and #o.stopped_grabs==2,'Do not repeatedly stop the same leftover motion')
o.grabs[0]=13
release(s,o,'task-overlays')
assert(#o.restored_grabs==1 and o.restored_grabs[1]==1,'Restore only the same carried object')
o.motions={};o.grabs={};o.grab_ids={}
-- Missing client delivery falls through to native cancellation on a short deadline.
o.playing=true;o.current=5
o.motions={{anim_id="ReadingLoop",montage_id="ReadMontage",group="UpperGroup",non_interruptible=false}}
start(s,o,"cut-timeout")
tick(s,o);assert(o.cancels==4)
for _=1,6 do tick(s,o) end
assert(s.lease.ready and o.cancels==5 and o.stopped[#o.stopped]=="ReadingLoop")
release(s,o,"cut-timeout")
o.motions={}
-- Save recovery restores the original grip only for the same still-held object.
local recovery=require("SceneZOI.SaveRecovery")
local saved={version=1,token="saved",collision=true,local_value=true,follow_parent=true,outfit=false,
 location={0,0,0},rotation={0,0,0},furniture={},grab_poses={{hand=1,id="22",pose="Hold"}}}
o.grabs[1]=22;o.grab_ids[1]="None"
s.lease=recovery.lease(saved);tick(s,o)
assert(not s.lease and o.grab_ids[1]=="Hold")
saved.grab_poses[2]={hand=1,id="23",pose="Other"}
assert(not pcall(recovery.lease,saved))
o.grabs={};o.grab_ids={}
-- Failures restore independent ownership rather than leave autonomy disabled.
o.queued=4;clear_failure=true;start(s,o,'clear-failure')
assert(not s.lease and replies[1]:find('|rejected|prepare_error|',1,true))
assert(o.AutonomyOption.AutonomyEnable.Value and o.AutonomyOption.AutonomyEnable.bFollowParent)
o.queued=0;o.playing=true;o.current=4;cancel_failure=true;start(s,o,'cancel-failure')
assert(not s.lease and o.AutonomyOption.AutonomyEnable.Value)
o.playing=false
-- Lease expiry cleans up even without an Exit message.
start(s,o,'expired');M.on_tick(s,o,7)
assert(not s.lease and o.AutonomyOption.AutonomyEnable.Value)
assert(restored>=6)
print('Participant tasks passed: backlog, delayed/single cancellation, waiting/new work, independent restoration, failure and lease expiry.')


-- Snapshot capture is non-mutating; the UI acknowledgement is the mutation gate.
o.AutonomyOption.AutonomyEnable.Value=false;o.AutonomyOption.AutonomyEnable.bFollowParent=true
M.on_lua_message(s,o,'SceneZOI.Prepare',P.pack('captured','1',node.id,1,'0','lead',P.encode(Json.encode(node))))
assert(s.lease and not s.lease.committed and o.collision and o.AutonomyOption.AutonomyEnable.bFollowParent)
local record=s.lease.save_snapshot;assert(record.collision and not record.local_value and record.follow_parent)
assert(record.body_merge.base and not record.body_merge.final and record.outfit)
M.on_lua_message(s,o,'SceneZOI.Commit',P.pack('captured'));tick(s,o);assert(s.lease.ready and not o.collision)
local prior_position_writes=o.position_writes or 0
M.on_lua_message(s,o,'SceneZOI.Anchor',P.pack('captured',1,2,3,0,0,0))
assert(o.position_writes==prior_position_writes+1,'The simulation moves the Zoi once an anchor arrives')
M.on_lua_message(s,o,'SceneZOI.Release',P.pack('captured'));assert(not s.lease and o.collision)
assert(o.position_writes==prior_position_writes+2,'Release restores the position the simulation had changed')
-- Simulate stale native fields loaded from the snapshot, then replay only original owned values.
o.collision=false;o.AutonomyOption.AutonomyEnable.bFollowParent=false
local loaded={};M.on_begin(loaded,o)
M.on_lua_message(loaded,o,'SceneZOI.Recover',P.pack('restore.1',P.encode(Json.encode(record))))
assert(not loaded.lease and o.collision and not o.AutonomyOption.AutonomyEnable.Value and o.AutonomyOption.AutonomyEnable.bFollowParent)
local count=restored;M.on_lua_message(loaded,o,'SceneZOI.Recover',P.pack('restore.1',P.encode(Json.encode(record))))
assert(restored==count,'Duplicate recovery must not replay completed restoration')
print('Save leases passed: no mutation before UI cache, original false/inherited flags, body layout, stale-field recovery and duplicate acknowledgement.')

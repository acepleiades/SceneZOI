-- Queue ownership must stop a backlog without waiting for every queued task.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local Json=require('SceneZOI.Json')
local restored=0
package.loaded['SceneZOI.Outfit']={borrowable=function()end,recover=function()end,apply=function()end,restore=function()restored=restored+1 end}
package.loaded['SceneZOI.Wardrobe']={capture=function()end,inventory=function()return 'inventory'end}
package.loaded['SceneZOI.SceneData']={simulation=function(n)return n end}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
local replies,owners,waits,overlay_requests={},{},{},{}
local clear_failure,cancel_failure=false,false
inzoi={EB2ComponentType={Appearance=1,Autonomy=2,Interaction=3,Posture=4},EB1HandType={LeftHand=0,RightHand=1},EB1GenderType={Female=1,Male=2},EB1ActionType={PlayLoopAnim=20},
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
   assert(o.queued==0,'Clear the waiting backlog before stopping a motion')
   local anim_id=assert(c:match(' anim_id=([%w_]+)$'),'Stop only a specific motion')
   o.stopped[#o.stopped+1]=anim_id
   if not o.defer_stop then
    for index,motion in ipairs(o.motions) do
     if motion.anim_id==anim_id then table.remove(o.motions,index);break end
    end
   end
   return true
  end
  error('Unexpected command '..c)
 end},message={send_to_client=function(id,kind,packet)
    if kind~='SceneZOI.Reply' then return end
    local fields=P.unpack(packet)
    if fields and fields[2]=='prepare_wait' then
        waits[#waits+1]=fields
    else
        replies[id.Value]=packet
        if fields and fields[2]=='overlay_cut' then overlay_requests[#overlay_requests+1]=fields end
    end
 end}}
local function owner(id)
 local o={id=id,queued=0,playing=false,current=1,clears=0,cancels=0,collision=true,motions={},stopped={},grabs={},stopped_grabs={},restored_grabs={},grab_ids={},
  AutonomyOption={AutonomyEnable={Value=true,bFollowParent=true}}}
 function o:GetEntityId()return {Value=self.id}end
 function o:GetComponent(t)
  if t==1 then return {GetAppearanceSetting=function()return {Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}end}end
  if t==3 then return {IsQueueEmpty=function()return self.queued==0 end,GetCurrentInteractionQueueId=function()return self.current end,
    GetCurrentActionType=function()
        self.current_reads=(self.current_reads or 0)+1
        assert(not self.cancel_delay, 'Capture the action before native cancellation')
        return 20
    end,
    GetCurrentInteractionBagId=function()return 'HasBook_Book_Read'end,
    GetCurrentInteractionId=function()return 'NativeCurrentInteraction'end}end
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
 function o:IsAutonomyEnable()return self.force_autonomy or self.AutonomyOption.AutonomyEnable.Value end
 function o:RefreshAutonomyOptionCache()self.autonomy_refreshes=(self.autonomy_refreshes or 0)+1 end
 owners[tostring(id)]=o;return o
end
local M=assert(loadfile('modkit/SceneZOI_93C44199/workspace/lua/B2/Zoi/SceneZOI.lua'))()
local node={id='test.idle',participants={lead={body='female'}}}
local function start(s,o,token)
 M.on_lua_message(s,o,'SceneZOI.Prepare',P.pack(token,'1',node.id,1,'0','lead',P.encode(Json.encode(node))))
 M.on_lua_message(s,o,'SceneZOI.Commit',P.pack(token))
end
local function tick(s,o,dt)
 if o.cancel_delay then
  o.cancel_delay=o.cancel_delay-1
  if o.cancel_delay==0 then
   o.cancel_delay=nil;o.playing=false
   if o.queued>0 then o.queued=o.queued-1;o.current=o.current+1;o.playing=true end
  end
 end
 M.on_tick(s,o,dt or .1)
end
local function release(s,o,token)
 M.on_lua_message(s,o,'SceneZOI.Release',P.pack(token))
 assert(not s.lease and o.collision and o.AutonomyOption.AutonomyEnable.Value and o.AutonomyOption.AutonomyEnable.bFollowParent)
end
local function overlay_request(token,details)
 local request=assert(overlay_requests[#overlay_requests])
 assert(request[1]==token and request[2]=='overlay_cut' and tonumber(request[4]) and tonumber(request[5]))
 if details then assert(request[3]==details) end
 return request
end
local function approve_overlays(s,o,request,matches,revision,scan_id)
 M.on_lua_message(s,o,'SceneZOI.OverlayCut',P.pack(
  request[1],revision or request[4],scan_id or request[5],matches))
end
local function overlay_detail(motion)
 return motion.anim_id..':'..motion.montage_id..':'..motion.group
end
local s,o={},owner(1);M.on_begin(s,o)
M.on_lua_message(s,o,'SceneZOI.Prepare',P.pack('abort-snapshot','1',node.id,1,'0','lead',P.encode(Json.encode(node))))
release(s,o,'abort-snapshot')
assert(not o.position_writes and not o.collision_writes and not o.autonomy_refreshes,
 'Abort before commit must not restore unmodified native properties')
start(s,o,'abort-commit')
assert(not s.lease.ready)
assert(waits[#waits][3]=='confirming_idle')
release(s,o,'abort-commit')
assert(not o.position_writes and not o.collision_writes and o.autonomy_refreshes==2,
 'Abort after commit restores autonomy while leaving unowned position and collision alone')
o.playing=true;o.queued=30;start(s,o,'backlog')
assert(o.queued==0 and o.cancels==1,'A backlog must be cleared before interruption, not drained one task at a time')
assert(s.lease and not s.lease.ready and not o.AutonomyOption.AutonomyEnable.Value)
assert(waits[#waits-1][3]=='awaiting_commit')
local waiting=waits[#waits]
assert(waiting[1]=='backlog' and waiting[3]=='interaction_cancelling' and waiting[5]=='1')
assert(waiting[6]=='PlayLoopAnim' and waiting[7]=='HasBook_Book_Read')
local wait_count=#waits
tick(s,o);assert(not s.lease.ready and o.cancels==1,'Do not mark ready during asynchronous cancellation or spam cancel')
assert(#waits==wait_count and o.current_reads==1,'Do not poll or send the same diagnostic every tick')
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
-- B2 reports active, interruptible motions. B1 decides which are task overlays
-- from native declarations, even when the group also contains ordinary posture.
local phone={anim_id='UseSmartPhone_Sofa_L_1',montage_id='ANIM_F_Sofa_SelfAct_b_Phone_L_StartLoopEnd_Interaction_Montage',
 group='PostureGroup',non_interruptible=false}
local eating={anim_id='Dish_Eat_Stand',montage_id='ANIM_F_Dish_Eat_Stand_StartLoopEnd_Interaction_Montage',
 group='DefaultGroup',non_interruptible=false}
local chair={anim_id='SitChair',montage_id='SitChairMontage',group='PostureGroup',non_interruptible=false}
local avoidance={anim_id='Sidestep',montage_id='SidestepMontage',group='DefaultGroup',non_interruptible=false}
local reading={anim_id='ReadingLoop',montage_id='ReadMontage',group='UpperGroup',non_interruptible=false}
local protected_grip={anim_id='DishStand',montage_id='DishStandMontage',group='RightArmGroup',non_interruptible=true}
local unclassified={anim_id='Unclassified',montage_id='NoFlagMontage',group='UpperGroup'}
local invalid={anim_id='Unsafe+ID',montage_id='BadMontage',group='UpperGroup',non_interruptible=false}
o.motions={chair,phone,protected_grip,eating,avoidance,reading,unclassified,invalid}
o.grabs={[0]=9,[1]=12}
o.playing=true;o.current=4;o.queued=3;start(s,o,'task-overlays')
assert(o.queued==0,'Clear the backlog even while the current montage cut is pending')
assert(#o.stopped==0 and #o.stopped_grabs==0 and o.cancels==3)
local request=overlay_request('task-overlays',
 table.concat({overlay_detail(chair),overlay_detail(phone),overlay_detail(eating),overlay_detail(avoidance),overlay_detail(reading)},'+'))
assert(request[6]=='NativeCurrentInteraction','Expected current interaction ID, got '..tostring(request[6]))
approve_overlays(s,o,request,overlay_detail(phone),tonumber(request[4])+1)
approve_overlays(s,o,request,overlay_detail(phone),nil,tonumber(request[5])+1)
o.AutonomyOption.AutonomyEnable.Value=true
tick(s,o)
assert(o.cancels==3 and #o.stopped==0,'Only the outstanding revision and scan may approve a cut')
assert(not o:IsAutonomyEnable(),'Disable autonomy again if it is re-enabled during preparation')
approve_overlays(s,o,request,table.concat({overlay_detail(phone),overlay_detail(eating),overlay_detail(reading)},'+'))
for _=1,6 do tick(s,o) end
assert(s.lease.ready and o.cancels==4 and table.concat(o.stopped,',')=='UseSmartPhone_Sofa_L_1,Dish_Eat_Stand,ReadingLoop')
local retained={}
for _,motion in ipairs(o.motions) do retained[#retained+1]=motion.anim_id end
assert(table.concat(retained,',')=='SitChair,DishStand,Sidestep,Unclassified,Unsafe+ID',
 'Keep ordinary posture, avoidance, the protected grip, and invalid or unknown native motions')
assert(table.concat(o.stopped_grabs,',')=='0,1' and o.grab_ids[0]=='None' and o.grab_ids[1]=='None')
assert(s.lease.save_snapshot.grab_poses[2].id=='12')
o.AutonomyOption.AutonomyEnable.Value=true
tick(s,o);assert(not o:IsAutonomyEnable(),'A ready participant still waits for the scene anchor')
assert(#o.stopped==3 and #o.stopped_grabs==2,'Do not stop the same leftover motion twice')

-- A new task overlay can appear while the SceneZOI montage is already playing.
M.on_lua_message(s,o,'SceneZOI.Anchor',P.pack('task-overlays',1,2,3,0,0,0))
local late={anim_id='FoldTowel',montage_id='TowelFoldMontage',group='PostureGroup',non_interruptible=false}
o.motions={chair,late};o.defer_stop=true
tick(s,o,.3)
local late_request=overlay_request('task-overlays',overlay_detail(late))
assert(late_request[5]~=request[5] and s.lease.ready,'Late scans do not block the playing scene')
approve_overlays(s,o,late_request,overlay_detail(late))
local requests=#overlay_requests
local late_stops=#o.stopped
assert(late_stops==4 and o.stopped[late_stops]==late.anim_id)
for _=1,3 do tick(s,o,.3) end
assert(#overlay_requests==requests and #o.stopped==late_stops,'Do not cut a still-reported occurrence twice')
o.motions={chair};tick(s,o,.3)
o.motions={chair,late};tick(s,o,.3)
local fresh_request=overlay_request('task-overlays',overlay_detail(late))
assert(fresh_request[5]~=late_request[5],'A new occurrence is eligible for a new cut')
approve_overlays(s,o,late_request,overlay_detail(late))
assert(#o.stopped==late_stops)
approve_overlays(s,o,fresh_request,overlay_detail(late))
assert(#o.stopped==late_stops+1)
o.grabs[0]=13
release(s,o,'task-overlays')
assert(#o.restored_grabs==1 and o.restored_grabs[1]==1,'Restore only the same carried object')
o.motions={};o.grabs={};o.grab_ids={};o.defer_stop=false

o.motions={chair}
start(s,o,'no-conflicts')
approve_overlays(s,o,overlay_request('no-conflicts',overlay_detail(chair)),'none')
for _=1,3 do tick(s,o) end
assert(s.lease.ready and #o.stopped==late_stops+1 and o.motions[1]==chair,
 'A negative decision ends the entry wait without stopping ordinary posture')
release(s,o,'no-conflicts')

-- No client decision is not permission to stop a native motion.
o.playing=true;o.current=5;o.motions={reading}
local stop_count=#o.stopped
start(s,o,'cut-timeout')
overlay_request('cut-timeout',overlay_detail(reading))
tick(s,o);assert(o.cancels==4)
for _=1,6 do tick(s,o) end
assert(s.lease.ready and o.cancels==5 and #o.stopped==stop_count and o.motions[1]==reading)
release(s,o,'cut-timeout')

-- An ACK must never stop a motion B2 did not submit, including a protected ID.
o.motions={chair,protected_grip};stop_count=#o.stopped
start(s,o,'out-of-scope-cut')
request=overlay_request('out-of-scope-cut',overlay_detail(chair))
approve_overlays(s,o,request,overlay_detail(protected_grip))
for _=1,7 do tick(s,o) end
assert(s.lease.ready and #o.stopped==stop_count and #o.motions==2)
release(s,o,'out-of-scope-cut')

-- A motion that became protected while the client was approving it stays native.
o.motions={phone}
start(s,o,'stale-motion-cut')
request=overlay_request('stale-motion-cut',overlay_detail(phone))
local changed={anim_id=phone.anim_id,montage_id=phone.montage_id,group=phone.group,non_interruptible=true}
o.motions={changed}
approve_overlays(s,o,request,overlay_detail(phone))
for _=1,3 do tick(s,o) end
assert(s.lease.ready and #o.stopped==stop_count and o.motions[1]==changed)
release(s,o,'stale-motion-cut')

-- A native ID can address multiple montages; exact client approval of one must
-- not cause the simulation to stop a different one sharing that ID.
local shared={anim_id=phone.anim_id,montage_id=chair.montage_id,group=chair.group,non_interruptible=false}
o.motions={phone,shared}
start(s,o,'shared-animation-id')
request=overlay_request('shared-animation-id',overlay_detail(phone)..'+'..overlay_detail(shared))
approve_overlays(s,o,request,overlay_detail(phone))
assert(#o.stopped==stop_count)
for _=1,3 do tick(s,o) end
release(s,o,'shared-animation-id')
o.motions={phone,shared}
start(s,o,'changed-animation-variant')
request=overlay_request('changed-animation-variant',overlay_detail(phone)..'+'..overlay_detail(shared))
o.motions={shared}
approve_overlays(s,o,request,overlay_detail(phone))
assert(#o.stopped==stop_count and o.motions[1]==shared)
for _=1,3 do tick(s,o) end
release(s,o,'changed-animation-variant')

-- Native stop may return before the motion finishes its ending section.
local function start_delayed_overlay(token,motion)
 local previous=#o.stopped
 o.motions={motion};o.defer_stop=true
 start(s,o,token)
 local request=overlay_request(token,overlay_detail(motion))
 assert(request[6]=='none','An already idle participant has no current interaction provenance')
 approve_overlays(s,o,request,overlay_detail(motion))
 assert(#o.stopped==previous+1 and o.stopped[#o.stopped]==motion.anim_id)
 return previous+1
end
local stopped=start_delayed_overlay('delayed-overlay',eating)
for _=1,2 do tick(s,o) end
assert(not s.lease.ready and #o.stopped==stopped and waits[#waits][3]=='overlay_cut')
o.motions={}
for _=1,2 do tick(s,o) end
assert(s.lease.ready and #o.stopped==stopped)
release(s,o,'delayed-overlay')

stopped=start_delayed_overlay('persistent-overlay',phone)
for _=1,3 do tick(s,o) end
assert(not s.lease.ready and #o.stopped==stopped)
for _=1,4 do tick(s,o) end
assert(s.lease.ready and #o.stopped==stopped and #o.motions==1,
 'Finish preparation once the short grace expires, even if the native motion is still reported')
release(s,o,'persistent-overlay')

stopped=start_delayed_overlay('paused-overlay',phone)
for _=1,4 do tick(s,o,0) end
assert(s.lease.ready and #o.stopped==stopped and #o.motions==1,
 'A paused native end section must allow readiness after the acknowledged render cut and native stop')
release(s,o,'paused-overlay')
o.motions={};o.defer_stop=false
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

-- A B2-only reload loses the participant lease but the live B1 host still owns the original.
local reloaded={};M.on_begin(reloaded,o)
o.collision=false;o.AutonomyOption.AutonomyEnable.bFollowParent=false
M.on_lua_message(reloaded,o,'SceneZOI.Release',P.pack('captured','restore',P.encode(Json.encode(record))))
assert(not reloaded.lease and o.collision and o.AutonomyOption.AutonomyEnable.bFollowParent, tostring(reloaded.lease)..':'..tostring(o.collision)..':'..tostring(o.AutonomyOption.AutonomyEnable.bFollowParent))
local release_writes=o.position_writes
M.on_lua_message(reloaded,o,'SceneZOI.Release',P.pack('captured','restore',P.encode(Json.encode(record))))
assert(o.position_writes==release_writes,'A duplicate Exit cannot restore the same position twice')

-- Message callbacks must own the same suppression as the simulation tick.
local changing, actor = {}, owner(2)
M.on_begin(changing, actor)
local function prepare_node(token, revision)
    M.on_lua_message(changing, actor, "SceneZOI.Prepare",
        P.pack(token, "2", node.id, revision, "0", "lead", P.encode(Json.encode(node))))
end
local function enable_autonomy()
    actor.AutonomyOption.AutonomyEnable.Value = true
    actor.AutonomyOption.AutonomyEnable.bFollowParent = true
end
local token = "back"
start(changing, actor, token)
tick(changing, actor)
assert(changing.lease.ready)
enable_autonomy()
prepare_node(token, 2)
assert(changing.lease.ready and changing.lease.revision == 2
    and not actor:IsAutonomyEnable() and not actor.AutonomyOption.AutonomyEnable.bFollowParent,
    "A Back transition must restore suppression before acknowledging the next scene, even without a character tick")
release(changing, actor, token)

token = "back-native-override"
start(changing, actor, token)
tick(changing, actor)
actor.force_autonomy = true
prepare_node(token, 2)
assert(not changing.lease.ready and actor:IsAutonomyEnable(),
    "Do not acknowledge readiness if the native effective value remains enabled")
local autonomy_wait = waits[#waits]
assert(autonomy_wait[3] == "autonomy_enabled" and autonomy_wait[8] == "0"
    and autonomy_wait[9] == "0" and autonomy_wait[10] == "2",
    "Make the remaining native override visible in preparation diagnostics")
actor.force_autonomy = false
enable_autonomy()
M.on_lua_message(changing, actor, "SceneZOI.Commit", P.pack(token))
assert(changing.lease.ready and not actor:IsAutonomyEnable(),
    "A commit retry must restore suppression on its own")
release(changing, actor, token)

-- The reporter's Zoi was already playing, with both option fields off and the
-- native query still on. Back must wait for actual tasks to settle on that lease.
token = "anchored-native-override"
start(changing, actor, token)
tick(changing, actor)
assert(changing.lease.ready)
M.on_lua_message(changing, actor, "SceneZOI.Anchor", P.pack(token, 1, 2, 3, 0, 0, 0))
actor.force_autonomy = true
local refreshes_before_back = actor.autonomy_refreshes
prepare_node(token, 2)
assert(changing.lease.ready and changing.lease.revision == 2 and actor:IsAutonomyEnable(),
    "A conflicting native autonomy query must not stall Back for an anchored idle Zoi")
assert(actor.autonomy_refreshes == refreshes_before_back,
    "Do not repeatedly rewrite an individual setting that is already off during the scene")

enable_autonomy()
actor.playing, actor.queued = true, 3
local cancels_before_back = actor.cancels
prepare_node(token, 3)
assert(not changing.lease.ready and actor.queued == 0 and actor.cancels == cancels_before_back + 1)
assert(not actor.AutonomyOption.AutonomyEnable.Value and not actor.AutonomyOption.AutonomyEnable.bFollowParent)
tick(changing, actor)
assert(not changing.lease.ready, "Keep waiting while an anchored participant is cancelling a task")
tick(changing, actor)
tick(changing, actor)
assert(changing.lease.ready and not actor.playing)
release(changing, actor, token)
actor.force_autonomy = false
print("Scene transitions preserve participant suppression, wait for tasks, and restore original settings on Exit.")

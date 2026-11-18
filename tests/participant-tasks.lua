-- Queue ownership must stop a backlog without waiting for every queued task.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local Json=require('SceneZOI.Json')
local restored, real_seconds=0, 10000
local original_time=os.time
os.time=function()return math.floor(real_seconds)end
package.loaded['SceneZOI.Outfit']={borrowable=function()end,recover=function()end,apply=function()end,restore=function()restored=restored+1 end}
package.loaded['SceneZOI.Wardrobe']={capture=function()end,inventory=function()return 'inventory'end}
package.loaded['SceneZOI.SceneData']={simulation=function(n)return n end}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
local replies,owners,waits,overlay_requests={},{},{},{}
local global_autonomy = true
local native_bubble_calls = 0
local clear_failure,cancel_failure=false,false
inzoi={EB2ComponentType={Appearance=1,Autonomy=2,Interaction=3,Posture=4},EB1HandType={LeftHand=0,RightHand=1},EB1GenderType={Female=1,Male=2},EB1ActionType={PlayLoopAnim=20},
 -- Native thought/speech presentation stays under the game's control through
 -- preparation, playback, failed starts and restoration.
 FB2Script_SpeechBubble=setmetatable({},{__index=function(_,name)
  return function()
   native_bubble_calls=native_bubble_calls+1
   error('Participant lifecycle called a native bubble function: '..name)
  end
 end}),
 EB1AutonomyOptionType={AutonomyEnable=1},
 getB2Manager=function(name)
  assert(name=='FB2AutonomyOptionManager')
  return {ResolveToggleOption=function(_,actor,kind)
   assert(kind==1)
   if actor.force_resolved~=nil then return actor.force_resolved end
   local option=actor.AutonomyOption.AutonomyEnable
   if option.bFollowParent then return global_autonomy end
   return option.Value
  end}
 end,
 FB1EntityId=function()return {}end,
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
  return {OnAutonomyOptionChanged=function(_,enabled)
    self.autonomy_notified=enabled
   end,
   SendAutonomyEnablePacket=function(_,enabled,play_sound)
    assert(enabled==self.autonomy_notified and play_sound==false)
    self.autonomy_packet=enabled
   end}
 end
 function o:GetAutonomyOption()return self.AutonomyOption end
 function o:GetLocation()return UE.FVector(0,0,0)end
 function o:GetRotation()return UE.FRotator(0,0,0)end
 function o:IsCollisionEnabled()return self.collision end
 function o:SetCollisionEnabled(v)self.collision=v;self.collision_writes=(self.collision_writes or 0)+1 end
 function o:SetLocationAndRotationOnlySimul()self.position_writes=(self.position_writes or 0)+1 end
 function o:IsPlayingInteraction()return self.playing end
 function o:IsAutonomyEnable()
  -- The native activity eligibility query is independent of the policy toggle.
  -- Notifying a policy change must not magically alter eligibility in this mock.
  if self.activity_eligible~=nil then return self.activity_eligible end
  return self.AutonomyOption.AutonomyEnable.Value
 end
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

-- An initially acquired idle NPC remains activity-eligible even when its actual
-- autonomy policy is off. Require the normal two idle observations, not false
-- eligibility, and never feed that true eligibility back into notifications.
local eligible, eligible_actor = {}, owner(7)
eligible_actor.activity_eligible = true
M.on_begin(eligible, eligible_actor)
start(eligible, eligible_actor, 'initial-policy-off-eligible')
assert(not eligible.lease.ready and eligible.lease.idle_ticks==1,
    'A disabled policy must not skip the initial stable-idle observation barrier')
assert(eligible_actor.autonomy_notified==false and eligible_actor.autonomy_packet==false
    and eligible.lease.autonomy_requested==false and eligible.lease.autonomy_notified==false,
    'Notify the false policy while the independent native eligibility query stays true')
tick(eligible, eligible_actor)
assert(eligible.lease.ready and eligible_actor:IsAutonomyEnable()
    and eligible.lease.idle_ticks==2 and eligible.lease.autonomy_disable_attempts==1,
    'Initial acquisition can finish with true eligibility and a confirmed disabled policy, without repeated suppression')
release(eligible, eligible_actor, 'initial-policy-off-eligible')
assert(eligible_actor.autonomy_notified and eligible_actor.autonomy_packet and eligible_actor:IsAutonomyEnable(),
    'An inherited enabled policy must resume after release')

-- Restoring the local value is insufficient when it inherits a disabled parent.
global_autonomy = false
local inherited, inherited_actor = {}, owner(8)
inherited_actor.activity_eligible = true
M.on_begin(inherited, inherited_actor)
start(inherited, inherited_actor, 'inherited-autonomy-off')
tick(inherited, inherited_actor)
assert(inherited.lease.ready)
release(inherited, inherited_actor, 'inherited-autonomy-off')
assert(inherited_actor.AutonomyOption.AutonomyEnable.Value==true
    and inherited_actor.AutonomyOption.AutonomyEnable.bFollowParent==true
    and inherited_actor.autonomy_notified==false and inherited_actor:IsAutonomyEnable(),
    'Release must restore inheritance and notify its resolved false parent policy')
global_autonomy = true

local independent, independent_actor = {}, owner(9)
independent_actor.AutonomyOption.AutonomyEnable.Value = false
independent_actor.AutonomyOption.AutonomyEnable.bFollowParent = false
M.on_begin(independent, independent_actor)
start(independent, independent_actor, 'individual-autonomy-off')
tick(independent, independent_actor)
assert(independent.lease.ready)
M.on_lua_message(independent, independent_actor, 'SceneZOI.Release', P.pack('individual-autonomy-off'))
assert(not independent.lease and not independent_actor.AutonomyOption.AutonomyEnable.Value
    and not independent_actor.AutonomyOption.AutonomyEnable.bFollowParent
    and independent_actor.autonomy_notified==false and not independent_actor:IsAutonomyEnable(),
    'An independently disabled original policy must remain disabled after Exit')

local unresolved, unresolved_actor = {}, owner(10)
unresolved_actor.activity_eligible, unresolved_actor.force_resolved = true, true
M.on_begin(unresolved, unresolved_actor)
start(unresolved, unresolved_actor, 'initial-policy-still-on')
tick(unresolved, unresolved_actor)
assert(not unresolved.lease.ready and unresolved.lease.idle_ticks>=2
    and not unresolved_actor.AutonomyOption.AutonomyEnable.Value
    and not unresolved_actor.AutonomyOption.AutonomyEnable.bFollowParent
    and waits[#waits][3]=='autonomy_enabled',
    'Idle tasks and false local fields cannot bypass an enabled resolved policy')
release(unresolved, unresolved_actor, 'initial-policy-still-on')
unresolved_actor.force_resolved = nil

local busy, busy_actor = {}, owner(11)
busy_actor.activity_eligible, busy_actor.playing, busy_actor.queued = true, true, 2
M.on_begin(busy, busy_actor)
start(busy, busy_actor, 'initial-eligible-busy')
assert(not busy.lease.ready and busy_actor.queued==0 and busy_actor.cancels==1)
tick(busy, busy_actor)
assert(not busy.lease.ready and busy_actor.playing, 'Policy confirmation cannot bypass asynchronous task cancellation')
tick(busy, busy_actor)
assert(not busy.lease.ready and not busy_actor.playing and busy.lease.idle_ticks==1)
tick(busy, busy_actor)
assert(busy.lease.ready and busy_actor:IsAutonomyEnable() and busy.lease.idle_ticks==2,
    'An eligible NPC needs two idle observations after its current task finishes')
release(busy, busy_actor, 'initial-eligible-busy')
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
start(s,o,'expired');real_seconds=real_seconds+7;M.on_tick(s,o,7)
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

-- Body-only acquisition must preserve the journal barrier and send its layout
-- to B1 even when no clothing directive changes the sparse outfit signature.
local real_outfit=assert(loadfile('modkit/SceneZOI_93C44199/workspace/lua/B2/SceneZOI/Outfit.lua'))()
inzoi.EB1ChangeOutfitReason={Script=2}
local stub_outfit=package.loaded['SceneZOI.Outfit']
local old_apply,old_restore=stub_outfit.apply,stub_outfit.restore
stub_outfit.apply,stub_outfit.restore,stub_outfit.keep_unmerged=real_outfit.apply,real_outfit.restore,real_outfit.keep_unmerged
local body_actor=owner(50)
local native_component=body_actor.GetComponent
local appearance={setting={Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false},Outfit={ActiveStyleList={}}},refreshes=0,writes=0}
function appearance:GetAppearanceSetting()return self.setting end
function appearance:SetAppearanceSetting(value)self.setting=value;self.writes=self.writes+1 end
function appearance:RefreshAppearance()self.refreshes=self.refreshes+1 end
function body_actor:GetComponent(kind)if kind==inzoi.EB2ComponentType.Appearance then return appearance end return native_component(self,kind)end
local body_state={};M.on_begin(body_state,body_actor)
local function body_prepare(token,revision,flag)
 M.on_lua_message(body_state,body_actor,'SceneZOI.Prepare',P.pack(token,'50',node.id,revision,flag,'lead',P.encode(Json.encode(node))))
end
body_prepare('body-only',1,'1')
local original_snapshot=body_state.lease.save_snapshot
assert(body_state.lease.keep_unmerged and not body_state.lease.committed and appearance.writes==0 and appearance.refreshes==0)
assert(appearance.setting.Body.bUseMeshMerge and not appearance.setting.FinalBody.bUseMeshMerge)
body_prepare('body-only',2,'1')
assert(body_state.lease.revision==2 and body_state.lease.save_snapshot==original_snapshot and appearance.writes==0,
 'A new revision before journal acknowledgement must not change native merge flags')
M.on_lua_message(body_state,body_actor,'SceneZOI.Commit',P.pack('body-only'));tick(body_state,body_actor)
assert(body_state.lease.ready and not appearance.setting.Body.bUseMeshMerge and not appearance.setting.FinalBody.bUseMeshMerge)
assert(appearance.refreshes==1 and not body_state.lease.body_merge_refresh_pending,
 'A body-only start must publish its unmerged layout once even with no outfit changes')
assert(body_state.lease.body_merge.base and not body_state.lease.body_merge.final)
body_prepare('body-only',2,'1')
assert(body_state.lease.ready and appearance.refreshes==1,'An unchanged Prepare retry must not refresh again')
appearance.setting.FinalBody.bUseMeshMerge=true
body_prepare('body-only',2,'1')
assert(body_state.lease.ready and not appearance.setting.FinalBody.bUseMeshMerge and appearance.refreshes==2,
 'A same-revision appearance refresh must reapply and send a rebuilt native layout')
assert(body_state.lease.save_snapshot==original_snapshot and not body_state.lease.body_merge.final)
release(body_state,body_actor,'body-only')
assert(appearance.setting.Body.bUseMeshMerge and not appearance.setting.FinalBody.bUseMeshMerge and appearance.refreshes==3)
body_prepare('late-body',1,'0')
M.on_lua_message(body_state,body_actor,'SceneZOI.Commit',P.pack('late-body'));tick(body_state,body_actor)
assert(body_state.lease.ready and appearance.refreshes==3)
body_prepare('late-body',1,'1')
assert(body_state.lease.ready and body_state.lease.keep_unmerged and appearance.refreshes==4,
 'A same-revision request can add an unmerged body after the participant was already ready')
release(body_state,body_actor,'late-body')
stub_outfit.apply,stub_outfit.restore=old_apply,old_restore
print('Initial body layout passed: stored request, commit-only mutation, no-outfit refresh, same-revision introduction/rebuild, original snapshot and Exit restoration.')

-- A B2-only reload loses the participant lease but the live B1 host still owns the original.
local reloaded={};M.on_begin(reloaded,o)
o.collision=false;o.AutonomyOption.AutonomyEnable.bFollowParent=false
M.on_lua_message(reloaded,o,'SceneZOI.Release',P.pack('captured','restore',P.encode(Json.encode(record))))
assert(not reloaded.lease and o.collision and o.AutonomyOption.AutonomyEnable.bFollowParent, tostring(reloaded.lease)..':'..tostring(o.collision)..':'..tostring(o.AutonomyOption.AutonomyEnable.bFollowParent))
local restored_reply = P.unpack(replies[1])
assert(restored_reply[1] == "captured" and restored_reply[2] == "released"
    and restored_reply[5] == "host_request", replies[1])
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
actor.force_resolved = true
prepare_node(token, 2)
assert(not changing.lease.ready,
    "Do not acknowledge readiness if the resolved policy remains enabled")
local autonomy_wait = waits[#waits]
assert(autonomy_wait[3] == "autonomy_enabled" and autonomy_wait[8] == "0"
    and autonomy_wait[9] == "0" and autonomy_wait[10] == "2",
    "Make the remaining native override visible in preparation diagnostics")
actor.force_resolved = nil
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
actor.activity_eligible = true
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
actor.activity_eligible = nil
print("Scene transitions preserve participant suppression, wait for tasks, and restore original settings on Exit.")

local function ready_participant(token)
    local state, zoi = {}, owner(2)
    M.on_begin(state, zoi)
    start(state, zoi, token)
    tick(state, zoi)
    assert(state.lease.ready and not zoi.collision and not zoi:IsAutonomyEnable())
    return state, zoi
end

-- A committed idle participant must finish on host retries even when its native
-- entity tick is delayed. A retry still cannot skip a running task's exit.
local pending, pending_actor = {}, owner(2)
M.on_begin(pending, pending_actor)
start(pending, pending_actor, "prepare-without-native-tick")
assert(pending.lease and not pending.lease.ready and pending.lease.idle_ticks == 1)
M.on_lua_message(pending, pending_actor, "SceneZOI.Prepare",
    P.pack("prepare-without-native-tick", "1", node.id, 1, "0", "lead", P.encode(Json.encode(node))))
assert(pending.lease.ready and pending.lease.lease_timing.tick_count == 0,
    "A valid Prepare retry must advance the existing two-idle-callback barrier")
assert(pending.lease.lease_timing.commit_received == 1,
    "A Prepare retry must not count as a received Commit")
release(pending, pending_actor, "prepare-without-native-tick")

pending, pending_actor = {}, owner(2)
M.on_begin(pending, pending_actor)
pending_actor.playing, pending_actor.queued = true, 2
start(pending, pending_actor, "prepare-still-cancelling")
for _ = 1, 3 do
    real_seconds = real_seconds + 1
    M.on_lua_message(pending, pending_actor, "SceneZOI.Prepare",
        P.pack("prepare-still-cancelling", "1", node.id, 1, "0", "lead", P.encode(Json.encode(node))))
end
assert(not pending.lease.ready and pending_actor.cancels == 1 and pending_actor.queued == 0)
local fresh_wait = waits[#waits]
local sample = Json.decode(P.decode(assert(fresh_wait[11])))
assert(fresh_wait[3] == "interaction_cancelling" and sample.simulation_ticks == 0 and sample.prepare_received == 4
    and sample.progress_source == "prepare_retry" and sample.controlled_id == "1"
    and sample.commit_received == 1 and sample.seconds_since_commit == 3,
    "Fresh retry diagnostics must distinguish message receipt from a missing native tick")
local commit_time = pending.lease.last_commit_wall
real_seconds = real_seconds + 1
M.on_lua_message(pending, pending_actor, "SceneZOI.Commit", P.pack("another.session"))
assert(pending.lease.lease_timing.commit_received == 1 and pending.lease.last_commit_wall == commit_time,
    "An unrelated Commit must not refresh receipt evidence")
M.on_lua_message(pending, pending_actor, "SceneZOI.Commit", P.pack("prepare-still-cancelling"))
sample = Json.decode(P.decode(assert(waits[#waits][11])))
assert(not pending.lease.ready and pending_actor.cancels == 1
    and sample.commit_received == 2 and sample.seconds_since_commit == 0 and sample.progress_source == "commit",
    "A matching Commit retry refreshes its own evidence without skipping task cancellation")
pending_actor.playing, pending_actor.cancel_delay = false, nil
M.on_lua_message(pending, pending_actor, "SceneZOI.Prepare",
    P.pack("prepare-still-cancelling", "1", node.id, 1, "0", "lead", P.encode(Json.encode(node))))
assert(not pending.lease.ready, "The first newly idle retry is only one confirmation")
M.on_lua_message(pending, pending_actor, "SceneZOI.Prepare",
    P.pack("prepare-still-cancelling", "1", node.id, 1, "0", "lead", P.encode(Json.encode(node))))
assert(pending.lease.ready)
release(pending, pending_actor, "prepare-still-cancelling")
print("Preparation retries progress delayed native callbacks without bypassing task cancellation, idle confirmation or ownership.")

local function assert_release(state, zoi, token, cause, diagnostic)
    assert(not state.lease and zoi.collision and zoi:IsAutonomyEnable()
        and zoi.AutonomyOption.AutonomyEnable.bFollowParent, "Release must restore participant ownership")
    local direct, relay = P.unpack(replies[2]), P.unpack(replies[1])
    assert(direct[1] == token and direct[2] == "released" and direct[3] == "ok"
        and direct[4] == "0" and direct[5] == cause, replies[2])
    assert(relay[1] == token and relay[2] == "released_unloaded" and relay[3] == "2"
        and relay[4] == cause and relay[5] == direct[6], replies[1])
    if diagnostic then
        assert(direct[6] and direct[6]:find(diagnostic, 1, true) and #direct == 6, replies[2])
    else
        assert(direct[6] == nil, replies[2])
    end
end

local causes = {
    {"lease_expired", function(state, zoi)
        real_seconds = real_seconds + require("SceneZOI.Config").lease_timeout + 1
        tick(state, zoi, require("SceneZOI.Config").lease_timeout + .1)
    end},
    {"simulation_save", function(state, zoi)
        assert(next(M.on_savegame(state, zoi)) == nil, "Release data must not be serialized into the save")
    end},
    {"simulation_load", M.on_loadgame},
    {"simulation_end", M.on_end},
    {"host_request", function(state, zoi, token)
        M.on_lua_message(state, zoi, "SceneZOI.Release", P.pack(token))
    end},
}
for _, case in ipairs(causes) do
    local cause, trigger = case[1], case[2]
    local tag = "release." .. cause
    local state, zoi = ready_participant(tag)
    trigger(state, zoi, tag)
    assert_release(state, zoi, tag, cause, cause == "lease_expired" and "timeout:6.000+elapsed:7.000" or nil)
end

-- A sparse NPC tick can cover time from before a newly delivered renewal.
local tag = "release.accumulated_tick"
local state, zoi = ready_participant(tag)
real_seconds = real_seconds + .5
M.on_lua_message(state, zoi, "SceneZOI.Heartbeat", P.pack(tag))
tick(state, zoi, 30)
assert(state.lease and state.lease.ready and not zoi.collision,
    "Accumulated simulation time must not consume a freshly renewed real-time lease")
-- Invalid/stale packets cannot keep a participant held after the host disappears.
real_seconds = real_seconds + 6
M.on_lua_message(state, zoi, "SceneZOI.Heartbeat", P.pack("another.session"))
tick(state, zoi, 0)
assert(state.lease, "The coarse real clock gets rounding grace at exactly six seconds")
real_seconds = real_seconds + 1
tick(state, zoi, 0)
assert_release(state, zoi, tag, "lease_expired", "timeout:6.000+elapsed:7.000")
local detail = P.unpack(replies[2])[6]
assert(detail:find("prepares:1+heartbeats:1", 1, true) and detail:find("last_dt:0.000+max_dt:30.000", 1, true)
    and detail:find("+age:7.000+clock_rollbacks:0", 1, true) and #detail <= 240, detail)

tag = "release.renewals"
state, zoi = ready_participant(tag)
for _ = 1, 10 do
    real_seconds = real_seconds + 1
    M.on_lua_message(state, zoi, "SceneZOI.Heartbeat", P.pack(tag))
    tick(state, zoi, 10)
    assert(state.lease, "Normal heartbeats survive arbitrarily accelerated simulation deltas")
end
-- Repeating Prepare also renews the same lease, without resetting its evidence.
start(state, zoi, tag)
assert(state.lease.lease_timing.prepare_received == 2 and state.lease.lease_timing.heartbeat_received == 10)
real_seconds = real_seconds + 7
tick(state, zoi, 0)
assert_release(state, zoi, tag, "lease_expired", "prepares:2+heartbeats:10")
tag = "release.clock_rollback"
state, zoi = ready_participant(tag)
real_seconds = real_seconds - 3600
tick(state, zoi, 0)
assert(state.lease and state.lease.lease_timing.clock_rollbacks == 1,
    "A backward system-clock change must not expire the lease or delay cleanup for an hour")
real_seconds = real_seconds + 7
tick(state, zoi, 0)
assert_release(state, zoi, tag, "lease_expired", "prepares:1+heartbeats:0")
assert(P.unpack(replies[2])[6]:find("clock_rollbacks:1", 1, true))
print("Participant watchdog uses real time: accumulated/accelerated ticks, pause, renewals, stale packets, rounding grace, clock rollback and real host loss.")

tag = "release.update"
state, zoi = ready_participant(tag)
zoi.queued, clear_failure = 2, true
tick(state, zoi)
assert_release(state, zoi, tag, "participant_update_error", "Injected_queue_clear_failure")

tag = "release.message"
state, zoi = ready_participant(tag)
local move = zoi.SetLocationAndRotationOnlySimul
function zoi:SetLocationAndRotationOnlySimul(...)
    self.SetLocationAndRotationOnlySimul = move
    error("anchor_failed | test")
end
M.on_lua_message(state, zoi, "SceneZOI.Anchor", P.pack(tag, 1, 2, 3, 0, 0, 0))
assert_release(state, zoi, tag, "participant_message_error", "anchor_failed")
assert(zoi.position_writes == 1, "The anchor failure must still restore the original position")

tag = "release.retry"
state, zoi = ready_participant(tag)
local original_collision_write = zoi.SetCollisionEnabled
function zoi:SetCollisionEnabled(...)
    self.SetCollisionEnabled = original_collision_write
    error("transient_collision_restore")
end
zoi.queued, clear_failure = 2, true
tick(state, zoi)
local pending = P.unpack(replies[2])
assert(state.lease and state.lease.releasing and not zoi.collision
    and pending[2] == "release_pending" and pending[3] == "restore_error" and pending[4] == "0"
    and pending[5]:find("transient_collision_restore", 1, true), replies[2])
M.on_lua_message(state, zoi, "SceneZOI.Release", P.pack(tag))
assert_release(state, zoi, tag, "participant_update_error", "Injected_queue_clear_failure")

start(state, zoi, tag)
local stale = P.unpack(replies[2])
assert(not state.lease and stale[1] == tag and stale[2] == "released" and stale[3] == "ok"
    and stale[4] == "0" and stale[5] == "retired_prepare", replies[2])
print("Participant release diagnostics distinguish lifecycle and exception causes, preserve the cause through restoration retries, and identify retired Prepare packets.")

-- A live clothing report captured pants/socks before preparation, then resolved
-- a skirt/stockings after task cleanup/layout refresh. Inventory and re-equip
-- must describe that settled entry outfit, before authored undressing starts.
local Containers=assert(loadfile('tests/support/containers.lua'))()
inzoi.FB1StyleSetting=Containers.style
inzoi.FB1GarmentDescription=function()return {}end
inzoi.FB1AccessoryDescription=function()return {}end
inzoi.FB1PrintedAccessoryDescription=function()return {PrintedAccessoryData=Containers.map()}end
local wardrobe_stub=package.loaded['SceneZOI.Wardrobe']
local real_wardrobe=assert(loadfile('modkit/SceneZOI_93C44199/workspace/lua/B2/SceneZOI/Wardrobe.lua'))()
for key,value in pairs(real_wardrobe)do wardrobe_stub[key]=value end
stub_outfit.apply,stub_outfit.restore,stub_outfit.keep_unmerged=real_outfit.apply,real_outfit.restore,real_outfit.keep_unmerged
local dressed_actor=owner(91)
local inherited_component=dressed_actor.GetComponent
function dressed_actor:GetFirstName()return 'Test'end
function dressed_actor:GetLastName()return 'Outfit'end
local stale_style=Containers.style()
stale_style.Outfit.Garments:Add('Bottom',{GarmentType='Bottom',GarmentId='old_pants'})
stale_style.Outfit.Garments:Add('Socks',{GarmentType='Socks',GarmentId='old_socks'})
local settled_style=Containers.style()
settled_style.Outfit.Garments:Add('Bottom',{GarmentType='Bottom',GarmentId='entry_skirt',VectorParameters={Tint='blue'}})
settled_style.Outfit.Garments:Add('Stockings',{GarmentType='Stockings',GarmentId='entry_stockings'})
local dressed_state={}
local outfit_appearance={setting={Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=true},
    FinalStyle=stale_style,Outfit={ActiveStyleList={}}},refreshes=0,active='None'}
function outfit_appearance:GetAppearanceSetting()return self.setting end
function outfit_appearance:SetAppearanceSetting(value)self.setting=value end
function outfit_appearance:GetActiveCostumeIdByReason()return self.active end
function outfit_appearance:EmplaceActiveOutfit(style)
    self.layer,self.active=style,'SceneZOI_Demo_Outfit';self.setting.Outfit.ActiveStyleList={style}
end
function outfit_appearance:RemoveCostumeByCostumeId()
    self.layer,self.active=nil,'None';self.setting.Outfit.ActiveStyleList={}
end
function outfit_appearance:RefreshAppearance()
    self.refreshes=self.refreshes+1
    assert(dressed_state.lease.committed and dressed_state.lease.save_snapshot,
        'Never resolve or mutate clothing before the original recovery journal is committed')
    if self.refreshes==1 then
        assert(not dressed_state.lease.wardrobe and not self.layer,
            'Resolve the entry layout before freezing pieces or applying authored removal')
    end
    local next_style=Containers.style()
    for slot,description in pairs(settled_style.Outfit.Garments:ToTable())do next_style.Outfit.Garments:Add(slot,description)end
    if self.layer then
        for slot,description in pairs(self.layer.Outfit.Garments:ToTable())do next_style.Outfit.Garments:Add(slot,description)end
    end
    self.setting.FinalStyle=next_style
end
function dressed_actor:GetComponent(kind)
    if kind==inzoi.EB2ComponentType.Appearance then return outfit_appearance end
    return inherited_component(self,kind)
end
dressed_actor.playing=true
M.on_begin(dressed_state,dressed_actor)
local dressed_node={id='test.settled_entry',participants={lead={body='female'}},
    outfits={lead={remove_slots={'Bottom','Stockings'}}}}
M.on_lua_message(dressed_state,dressed_actor,'SceneZOI.Prepare',P.pack('settled-entry','91',dressed_node.id,1,'1','lead',P.encode(Json.encode(dressed_node))))
local entry_journal=dressed_state.lease.save_snapshot
assert(not dressed_state.lease.wardrobe and outfit_appearance.refreshes==0 and entry_journal.body_merge.base and entry_journal.body_merge.final,
    'Prepare captures only recovery state, not a wardrobe which native work can still change')
M.on_lua_message(dressed_state,dressed_actor,'SceneZOI.Commit',P.pack('settled-entry'))
assert(not dressed_state.lease.wardrobe,'Do not freeze task-time clothes while cancellation is still pending')
for _=1,12 do if dressed_state.lease.ready then break end tick(dressed_state,dressed_actor)end
assert(dressed_state.lease.ready,'The dressed participant did not finish preparation')
local captured_wardrobe=dressed_state.lease.wardrobe
local pieces={};for _,item in ipairs(captured_wardrobe.items)do pieces[item.key]=item end
assert(pieces.Bottom.asset=='entry_skirt' and pieces.Stockings.asset=='entry_stockings' and not pieces.Socks,
    'Inventory must contain the actual settled skirt/stockings rather than earlier pants/socks')
assert(captured_wardrobe.snapshot.Outfit.Garments:Find('Bottom').VectorParameters.Tint=='blue')
assert(outfit_appearance.setting.FinalStyle.Outfit.Garments:Find('Bottom').GarmentId=='None'
    and outfit_appearance.setting.FinalStyle.Outfit.Garments:Find('Stockings').GarmentId=='None',
    'Capture the entry pieces before the initial scene directive removes them')
M.on_lua_message(dressed_state,dressed_actor,'SceneZOI.Outfit',P.pack('settled-entry',1,pieces.Bottom.id,'1',1,'1'))
assert(outfit_appearance.setting.FinalStyle.Outfit.Garments:Find('Bottom').GarmentId=='entry_skirt',
    'Manual re-equip must restore the entry skirt, not the stale pants')
M.on_lua_message(dressed_state,dressed_actor,'SceneZOI.Outfit',P.pack('settled-entry',2,pieces.Stockings.id,'1',1,'1'))
assert(outfit_appearance.setting.FinalStyle.Outfit.Garments:Find('Stockings').GarmentId=='entry_stockings')
local refreshes=outfit_appearance.refreshes
local next_node={id='test.next_entry',participants={lead={body='female'}}}
M.on_lua_message(dressed_state,dressed_actor,'SceneZOI.Prepare',P.pack('settled-entry','91',next_node.id,2,'1','lead',P.encode(Json.encode(next_node))))
assert(dressed_state.lease.ready and dressed_state.lease.wardrobe==captured_wardrobe and outfit_appearance.refreshes==refreshes,
    'Navigation must neither recapture an edited wardrobe nor add an unchanged appearance refresh')
assert(dressed_state.lease.save_snapshot==entry_journal and entry_journal.wardrobe==nil
    and entry_journal.body_merge.base and entry_journal.body_merge.final,
    'Settled wardrobe capture must not replace or expand the original recovery journal')
release(dressed_state,dressed_actor,'settled-entry')
assert(outfit_appearance.setting.Body.bUseMeshMerge and outfit_appearance.setting.FinalBody.bUseMeshMerge)
print('Settled entry wardrobe passed: original save barrier, delayed task/layout resolution, current pieces, capture before authored removal, exact re-equip and no navigation refresh.')
assert(native_bubble_calls==0, 'Participant leases must not add, remove or suppress native bubbles')
os.time=original_time

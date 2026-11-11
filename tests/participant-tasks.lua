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
inzoi={EB2ComponentType={Appearance=1,Autonomy=2,Interaction=3},EB1GenderType={Female=1,Male=2},
 cli={execute=function(c)
  local o=owners[c:match('entity_id=(%d+)')]
  if c=='entity.get_possessed'then return true,'','{"entity_id":1}'end
  if c:match('^autonomy.set_enable')then o.AutonomyOption.AutonomyEnable.Value=false;o.AutonomyOption.AutonomyEnable.bFollowParent=false;return true end
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
   assert(not o.playing,'Let the interaction cancel before inspecting leftover motions')
   return true,'',Json.encode({playing=#o.motions>0,motions=o.motions})
  end
  if c:match('^motion.stop') then
   o.stopped[#o.stopped+1]=assert(c:match(' anim_id=([%w_]+)$'),'Stop only a specific motion')
   return true
  end
  error('Unexpected command '..c)
 end},message={send_to_client=function(id,kind,packet)if kind=='SceneZOI.Reply'then replies[id.Value]=packet end end}}
local function owner(id)
 local o={id=id,queued=0,playing=false,current=1,clears=0,cancels=0,collision=true,motions={},stopped={},
  AutonomyOption={AutonomyEnable={Value=true,bFollowParent=true}}}
 function o:GetEntityId()return {Value=self.id}end
 function o:GetComponent(t)
  if t==1 then return {GetAppearanceSetting=function()return {Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}end}end
  if t==3 then return {IsQueueEmpty=function()return self.queued==0 end,GetCurrentInteractionQueueId=function()return self.current end}end
  return {OnAutonomyOptionChanged=function()end,SendAutonomyEnablePacket=function()end}
 end
 function o:GetAutonomyOption()return self.AutonomyOption end
 function o:GetLocation()return UE.FVector(0,0,0)end
 function o:GetRotation()return UE.FRotator(0,0,0)end
 function o:IsCollisionEnabled()return self.collision end
 function o:SetCollisionEnabled(v)self.collision=v end
 function o:SetLocationAndRotationOnlySimul()end
 function o:IsPlayingInteraction()return self.playing end
 function o:IsAutonomyEnable()return self.AutonomyOption.AutonomyEnable.Value end
 function o:RefreshAutonomyOptionCache()end
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
o.playing=true;o.queued=30;start(s,o,'backlog')
assert(o.queued==0 and o.cancels==1,'A backlog must be cleared before interruption, not drained one task at a time')
assert(s.lease and not s.lease.ready and not o.AutonomyOption.AutonomyEnable.Value)
tick(s,o);assert(not s.lease.ready and o.cancels==1,'Do not mark ready during asynchronous cancellation or spam cancel')
for _=1,4 do tick(s,o)end
assert(s.lease.ready and not o.playing and not o.collision)
-- New commands during playback must not escape scene ownership.
o.queued=5;tick(s,o);assert(o.queued==0 and o.cancels==1)
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
-- The simulated interaction is idle before the native upper-body loop ends.
o.motions={
 {anim_id='MovingChair_Sit_R',group='PostureGroup'},
 {anim_id='Dish_Eat_Stand',group='UpperGroup'},
 {anim_id='Snack_Eat_Stand',group='DefaultGroup'},
 {anim_id='Other_UpperBody_Action',group='UpperGroup'},
}
o.playing=true;o.current=4;start(s,o,'eating')
assert(#o.stopped==0)
for _=1,5 do tick(s,o)end
assert(s.lease.ready and #o.stopped==1 and o.stopped[1]=='Dish_Eat_Stand')
tick(s,o);assert(#o.stopped==1,'Do not repeatedly stop the same leftover motion')
release(s,o,'eating')
o.motions={}
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
M.on_lua_message(s,o,'SceneZOI.Release',P.pack('captured'));assert(not s.lease and o.collision)
-- Simulate stale native fields loaded from the snapshot, then replay only original owned values.
o.collision=false;o.AutonomyOption.AutonomyEnable.bFollowParent=false
local loaded={};M.on_begin(loaded,o)
M.on_lua_message(loaded,o,'SceneZOI.Recover',P.pack('restore.1',P.encode(Json.encode(record))))
assert(not loaded.lease and o.collision and not o.AutonomyOption.AutonomyEnable.Value and o.AutonomyOption.AutonomyEnable.bFollowParent)
local count=restored;M.on_lua_message(loaded,o,'SceneZOI.Recover',P.pack('restore.1',P.encode(Json.encode(record))))
assert(restored==count,'Duplicate recovery must not replay completed restoration')
print('Save leases passed: no mutation before UI cache, original false/inherited flags, body layout, stale-field recovery and duplicate acknowledgement.')

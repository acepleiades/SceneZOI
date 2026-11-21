-- Real shared native-exit coordinator, with deterministic native queues/poses.
-- No game calls: native submission/readback is represented by this owned fixture.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local Json=require('SceneZOI.Json')
local actors,objects={},{}
local submissions,reads={},0
local function entity(id)return {Value=id}end
inzoi={FB1EntityId=function()return {}end,EB2ComponentType={Interaction=1,Posture=2,Slot=3},
 EB1SlotType={Interaction=1},EB1SlotOccupyingReason={None=0,Interaction=1,Posture=2,Restricted=8},
 EB1InteractionPlayReason={User=3},EB1AddInteractionQueueResult={Success=37},
 getB2Manager=function()return {FindGameObject=function(_,id)return objects[id.Value]end,FindCharacter=function(_,id)return actors[id.Value]end}end,
 cli={execute=function(command)
  local who=tonumber(command:match('^motion%.get_current entity_id=(%d+)$'))
  assert(who,'NativeGetUp must not cancel tasks, stop motions or change policy through CLI')
  local actor=assert(actors[who]);reads=reads+1
  if actor.motion_error then return false,'read failed' end
  return true,'',Json.encode({motions=actor.motions})
 end}}
local GetUp=require('SceneZOI.NativeGetUp')
local function fixture(number,target)
 number,target=number or 1,target or 50
 local actor={number=number,motions={},location={X=100,Y=200,Z=0},rotation={Pitch=0,Yaw=0,Roll=0}}
 local slot={SlotStateInfos={
  {ComponentName='Seat',SlotName='Sit',OccupyingEntityId=entity(number),SlotOccupyingReasons={2}},
  {ComponentName='SeatAlias',SlotName='SitAlias',OccupyingEntityId=entity(number),SlotOccupyingReasons={2}},
  {ComponentName='Bystander',SlotName='Other',OccupyingEntityId=entity(7),SlotOccupyingReasons={2}},
 }}
 function slot:GetSlotStateInfoByComponentName(kind,name)
  assert(kind==1);for _,row in ipairs(self.SlotStateInfos)do if row.ComponentName==name then return row end end
 end
 local object={GetComponent=function(_,kind)assert(kind==3);return slot end};objects[target]=object
 local pose={state={PostureId='SitSofa',PostureTargetEntityId=entity(target),BaseComponentName='Seat',OccupyingSlot='Sit'}}
 function pose:GetCurrentPostureState()return self.state end
 function pose:IsStanding()return self.state.PostureId=='Stand'end
 function pose:IsRiddingVehicle()return self.riding==true end
 local interaction={InteractionQueue={},next_id=100,enqueue_result=37}
 function interaction:GetCurrentInteractionQueueId()return self.current and self.current.InteractionQueueId or -1 end
 function interaction:GetCurrentInteractionBagId()return self.current and self.current.InteractionBagId or 'None'end
 function interaction:GetCurrentInteractionTargetEntityId()return self.current and self.current.PickedEntityId or entity(0)end
 function interaction:AddInteractionQueueByParam(source,point,bag,reason,front,multi,label,packet,next_interaction)
  assert(source.Value==target,'The native source furniture, not the destination, is the Stand target')
  assert(point==actor.location and bag=='Stand'and reason==3 and front and not multi and label=='SceneZOI'and packet and not next_interaction)
  submissions[#submissions+1]={owner=number,target=source.Value}
  if self.enqueue_error then error('native enqueue failed')end
  if self.enqueue_result~=37 then return self.enqueue_result end
  self.next_id=self.next_id+1
  local row={InteractionQueueId=self.next_id,InteractionBagId='Stand',PickedEntityId=entity(target)}
  self.submitted=row
  if not self.hide_queue then self.InteractionQueue[#self.InteractionQueue+1]=row end
  return self.enqueue_result
 end
 function actor:GetEntityId()return entity(number)end
 function actor:GetComponent(kind)if kind==1 then return interaction elseif kind==2 then return pose end;error('Unexpected actor component')end
 function actor:GetLocation()return self.location end
 function actor:GetRotation()return self.rotation end
 function actor:IsPlayingInteraction()return interaction.current~=nil end
 actors[number]=actor
 local f={owner=actor,pose=pose,interaction=interaction,slots=slot,source=target}
 function f:release_claims()
  for _,row in ipairs(slot.SlotStateInfos)do if row.OccupyingEntityId.Value==number then row.OccupyingEntityId=entity(0);row.SlotOccupyingReasons={}end end
 end
 function f:stand_flags()
  self:release_claims();pose.state={PostureId='Stand',PostureTargetEntityId=entity(0),BaseComponentName='None',OccupyingSlot='None'}
 end
 function f:finish()
  interaction.InteractionQueue={};interaction.current=nil;self:stand_flags();actor.motions={}
 end
 function f:unchanged_bystander()
  local row=slot.SlotStateInfos[3];assert(row.OccupyingEntityId.Value==7 and row.SlotOccupyingReasons[1]==2)
 end
 return f
end
local cases,failures=0,{}
local function run(name,fn)
 cases=cases+1;actors,objects,submissions={}, {}, {};reads=0
 GetUp.records={};GetUp.clock=0;GetUp.next_poll=nil;GetUp.max_records=128
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then failures[#failures+1]=name..': '..tostring(err)end
end
local function settle(f,token)
 for _=1,8 do GetUp.tick(.1);local ready,sample=GetUp.ensure(f.owner,token);if ready then return sample end end
 error('Native exit did not settle')
end
run('queue-first ownership, idempotence and early vacancy',function()
 local f=fixture();local ready,r=GetUp.ensure(f.owner,'one')
 assert(not ready and r.owner=='1'and r.id=='50'and r.queue_id=='101'and #submissions==1)
 GetUp.ensure(f.owner,'one');assert(#submissions==1,'Duplicate callers share one native Stand queue')
 f.interaction.current=f.interaction.submitted;f.interaction.InteractionQueue={}
 f:stand_flags();f.owner.motions={{anim_id='GetUp',montage_id='transition',group='PostureGroup'}}
 for _=1,3 do GetUp.tick(.1);assert(not GetUp.ensure(f.owner,'one'),'Stand/empty claims do not end a still-running native queue')end
 f.interaction.current=nil
 assert(not GetUp.ensure(f.owner,'one'),'Queue disappearance cannot bypass a remaining posture montage')
 f.owner.motions={};GetUp.ensure(f.owner,'one')
 assert(not GetUp.ensure(f.owner,'one'),'Repeated calls within one clock observation cannot satisfy two idle observations')
 settle(f,'one');f:unchanged_bystander()
end)
run('all source aliases must release',function()
 local f=fixture();GetUp.ensure(f.owner,'aliases');f.interaction.InteractionQueue={}
 f.pose.state={PostureId='Stand',PostureTargetEntityId=entity(0)}
 f.slots.SlotStateInfos[1].OccupyingEntityId=entity(0);f.slots.SlotStateInfos[1].SlotOccupyingReasons={}
 GetUp.tick(.1);local ready,r=GetUp.ensure(f.owner,'aliases')
 assert(not ready and r.claim_pending,'A second own source alias cannot be left behind')
 f:release_claims();settle(f,'aliases');f:unchanged_bystander()
end)
run('position settlement after native completion',function()
 local f=fixture();GetUp.ensure(f.owner,'spatial');f:finish();GetUp.ensure(f.owner,'spatial')
 f.owner.location.X=f.owner.location.X+5;GetUp.tick(.1)
 assert(not GetUp.ensure(f.owner,'spatial'),'Entry must wait while native GetUp is still restoring world position')
 settle(f,'spatial')
end)
run('settled observations must be consecutive after motion clears',function()
 local f=fixture();GetUp.ensure(f.owner,'consecutive');f:finish();GetUp.ensure(f.owner,'consecutive')
 f.owner.motions={{anim_id='GetUpEnd',montage_id='transition-end',group='PostureGroup'}};GetUp.tick(.1)
 f.owner.motions={};GetUp.tick(.1)
 assert(not GetUp.ensure(f.owner,'consecutive'),'A returning posture motion invalidates the previous idle observation')
 settle(f,'consecutive')
end)
run('read errors cannot prove motion has ended',function()
 local f=fixture();GetUp.ensure(f.owner,'read');f:finish();f.owner.motion_error=true
 GetUp.tick(.1);local ready,r=GetUp.ensure(f.owner,'read');assert(not ready and r.motion_pending~=false)
 f.owner.motion_error=false;settle(f,'read')
end)
run('paused native clock does not expire pending exit',function()
 local f=fixture();GetUp.ensure(f.owner,'pause')
 for _=1,30 do GetUp.tick(0);local ready,r=GetUp.ensure(f.owner,'pause');assert(not ready and r.state~='failed')end
 assert(GetUp.clock==0 and #submissions==1);f:finish();settle(f,'pause')
end)
run('queue identity cannot silently change',function()
 local f=fixture();GetUp.ensure(f.owner,'replaced')
 f.interaction.submitted.InteractionBagId='Phone'
 local ready,r=GetUp.ensure(f.owner,'replaced')
 assert(not ready and r.state=='failed'and r.failure=='native_getup_queue_replaced')
 assert(#submissions==1);f:unchanged_bystander()
end)
run('enqueue failure remains bounded and is not retried',function()
 local f=fixture();f.interaction.enqueue_result=13
 local ready,r=GetUp.ensure(f.owner,'rejected')
 assert(not ready and r.state=='failed'and r.failure=='native_getup_enqueue_rejected')
 GetUp.ensure(f.owner,'rejected');assert(#submissions==1)
 GetUp.tick(61);assert(GetUp.sample(f.owner)==nil)
end)
run('accepted but untracked queue cannot pass',function()
 local f=fixture();f.interaction.hide_queue=true
 GetUp.ensure(f.owner,'untracked');GetUp.tick(2.1)
 local ready,r=GetUp.ensure(f.owner,'untracked')
 assert(not ready and r.state=='failed'and r.failure=='native_getup_queue_untracked')
end)
run('foreign source claim is preserved and not reported settled',function()
 local f=fixture();f.slots.SlotStateInfos[1].OccupyingEntityId=entity(7)
 local ready=GetUp.ensure(f.owner,'foreign')
 assert(not ready,'A non-standing actor with an unproved furniture source is not ready')
 assert(#submissions==0 and f.slots.SlotStateInfos[1].OccupyingEntityId.Value==7)
 f:unchanged_bystander()
end)
run('streamed-out source is not proof of standing',function()
 local f=fixture();objects[f.source]=nil
 assert(not GetUp.ensure(f.owner,'unloaded'),'An unavailable real source must fail or wait, not pass readiness')
 assert(#submissions==0)
end)
run('adopt exact native Stand, detach without cancelling it',function()
 local f=fixture();f.interaction.current={InteractionQueueId=88,InteractionBagId='Stand',PickedEntityId=entity(50)}
 local pending,r=GetUp.pending(f.owner)
 assert(pending and r.adopted and r.queue_id=='88'and #submissions==0)
 GetUp.ensure(f.owner,'adopt');GetUp.detach(f.owner,'adopt')
 assert(f.interaction.current.InteractionQueueId==88 and #submissions==0,'Exit must allow native teardown to finish')
 f:finish();GetUp.tick(.1);GetUp.tick(.1)
 assert(not GetUp.pending(f.owner));f:unchanged_bystander()
end)
run('independent actors and bounded active records',function()
 local a,b=fixture(1,50),fixture(2,51);GetUp.max_records=1
 GetUp.ensure(a.owner,'a');local ready,r=GetUp.ensure(b.owner,'b')
 assert(not ready and r.failure=='native_getup_capacity'and #submissions==1)
 a:finish();GetUp.tick(.1);GetUp.tick(.1);GetUp.tick(61)
 GetUp.ensure(b.owner,'b2');assert(#submissions==2 and submissions[2].owner==2 and submissions[2].target==51)
end)
run('capacity never grants permission to cancel an existing native exit',function()
 local a,b=fixture(1,50),fixture(2,51);GetUp.max_records=1;GetUp.ensure(a.owner,'occupied')
 b.interaction.current={InteractionQueueId=88,InteractionBagId='Stand',PickedEntityId=entity(51)}
 local waiting,r=GetUp.pending(b.owner)
 assert(waiting and r,'An existing native Stand remains protected when the coordinator cannot allocate another record')
 local ready=GetUp.ensure(b.owner,'second');assert(not ready and #submissions==1)
end)
run('standing and explicitly excluded movement stay untouched',function()
 local f=fixture();f:finish();assert(GetUp.ensure(f.owner,'standing')and #submissions==0)
 f.pose.state={PostureId='Swim',PostureTargetEntityId=entity(50),BaseComponentName='Seat',OccupyingSlot='Sit'}
 assert(GetUp.ensure(f.owner,'water')and #submissions==0)
 f.pose.state.PostureId='Vehicle';f.pose.riding=true;assert(GetUp.ensure(f.owner,'vehicle')and #submissions==0)
end)
if #failures>0 then error(table.concat(failures,'\n\n'))end
print('Native GetUp passed: '..cases..' cases covering real queue ownership, complete native exit, stable settlement, pause, proof failures, source/bystander isolation and detached cleanup.')

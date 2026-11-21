package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local now=100;os.time=function()return now end
local replies,calls,removes={},0,0
local activity_queries,entity_denied,object_denied=0,false,false
local unloaded,fail_at,throw_at,spill_at,foreign_at=false,nil,nil,nil,nil
local characters,cancelled={},{}
-- NativeGetUp's real queue/lifecycle has separate tests. This fixture controls
-- only whether that shared prerequisite has finished before a pair may claim.
package.loaded['SceneZOI.NativeGetUp']={
 pending=function(person)return person.getup_pending==true,person.getup_sample end,
 ensure=function(person)
  if person.getup_pending then return false,person.getup_sample end
  local p=person:GetComponent(16)
  if p:IsStanding()then return true,person.getup_sample end
  person.getup_pending=true;person.getups=(person.getups or 0)+1
  person.getup_sample={state='queued'}
  return false,person.getup_sample
 end,
}
local function owner(n)return {GetEntityId=function()return {Value=n}end}end
local a,b=owner(1),owner(2)
local states={}
for i=1,4 do states[i]={ComponentName='Seat'..i,SlotName='Sit',Blocked=false,OccupyingEntityId={Value=0},SlotOccupyingReasons={}}end
states[5]={ComponentName='Seat1Alias',SlotName='Sit',Blocked=false,OccupyingEntityId={Value=0},SlotOccupyingReasons={}}
local function has(state,n)for _,v in ipairs(state.SlotOccupyingReasons)do if v==n then return true end end;return false end
local function occupy(i,n,r)states[i].OccupyingEntityId.Value=n;states[i].SlotOccupyingReasons={r or 8}end
local function empty(i)states[i].OccupyingEntityId.Value=0;states[i].SlotOccupyingReasons={}end
local s={SlotStateInfos=states,GetOwnerEntityId=function()return {Value=50}end}
function s:TryOccupySlot(kind,p)
 activity_queries=activity_queries+1
 -- Real sofa aliases require Sit or Sit_PassOut tags. A generic reservation
 -- has no matching native interaction, even though the entity is eligible.
 return false
end
function s:IsOccupiableEntity()return not entity_denied end
function s:OccupySlot(kind,p)
 assert(p.UsageType==2,'Sofa aliases are reserved individually, without native Double-slot expansion')
 calls=calls+1
 if fail_at==calls then return end
 for i,row in ipairs(states)do if row.ComponentName==p.ComponentName and row.SlotName==p.SlotName then
  assert(row.OccupyingEntityId.Value==0,'Native mock refuses occupied slots');occupy(i,p.OccupyEntityId.Value)
 end end
 if spill_at==calls then occupy(4,p.OccupyEntityId.Value)end
 if foreign_at==calls then occupy(2,7,2)end
 if throw_at==calls then error('Native changed the slot before throwing')end
end
function s:RemoveOccupyingReasonByEntityId(person,r)
 removes=removes+1
 for i,row in ipairs(states)do if row.OccupyingEntityId.Value==person.Value then
  for j=#row.SlotOccupyingReasons,1,-1 do if row.SlotOccupyingReasons[j]==r then table.remove(row.SlotOccupyingReasons,j)end end
  if #row.SlotOccupyingReasons==0 then empty(i)end
 end end
end
function s:CanOccupySlot()return true end
function s:CanOccupySlotCheckOnlyEntity()return true end
local o={ObjectTableId='SofaA',GetComponent=function()return s end,IsOccupiableEntity=function()return not object_denied end,IsInUse=function()for _,row in ipairs(states)do if row.OccupyingEntityId.Value~=0 then return true end end;return false end}
inzoi={FB1EntityId=function()return {}end,FB2TargetSlotParam=function()return {}end,FB1PostureState=function()return {PostureId='Stand',PostureTargetEntityId={Value=0}}end,
 EB2ComponentType={Slot=14,Interaction=15,Posture=16},EB1SlotOccupyingReason={None=0,Interaction=1,Posture=2,Restricted=8},EB1SlotUsageType={Single=2},EB1SlotType={Interaction=1,Object=2},
 getB2Manager=function()return {FindGameObject=function()if not unloaded then return o end end,FindCharacter=function(_,e)return characters[e.Value]end}end,
 cli={execute=function(command)local n=tonumber(command:match('^interaction%.cancel entity_id=(%d+)$'));assert(n,'Only native interaction cancellation is permitted');cancelled[n]=(cancelled[n]or 0)+1;return true end},
 message={send_to_client=function(_,_,packet)replies[#replies+1]=P.unpack(packet)end}}
local M=require('SceneZOI.FurnitureLease');local Hook=require('Components.B2SlotComponent')
local profile={schema_version=1,id='author.sofa',kind='sofa.pair',objects={'SofaA'},surface_height_cm=44,sitting_spots={},seat_pairs={
 {id='left',spots={'s1','s2'}},{id='middle',spots={'s2','s3'}},{id='right',spots={'s3','s4'}}}}
for i=1,4 do profile.sitting_spots[i]={id='s'..i,run='straight',offset_cm={x=i*80,y=0,z=0},yaw_degrees=0,slots={{component_name='Seat'..i,slot_name='Sit'}}}end
profile.sitting_spots[1].slots[2]={component_name='Seat1Alias',slot_name='Sit'}
local encoded=P.encode(J.encode(profile))
local function send(token,action,pair,who,held,slots,spots)
 M.message(who or a,P.pack(token,'50',action,held or encoded,pair or'none',action=='acquire'and P.encode(J.encode({'1','2'}))or slots and P.encode(J.encode(slots))or'none',spots and P.encode(J.encode(spots))or'none'))
 return replies[#replies]
end
local function free()local r=send('status','look');return J.decode(P.decode(r[4]))end
assert(#free()==3 and calls==0,'Status is read-only and reports physical pairs')
entity_denied=true;local denied=send('entity_denied','acquire','left')
assert(denied[3]=='busy'and denied[4]=='native_entity_ineligible'and calls==0 and #free()==3,'Native entity eligibility failure must not mutate slots');entity_denied=false
object_denied=true;denied=send('object_denied','acquire','left')
assert(denied[3]=='busy'and denied[4]=='native_entity_ineligible'and calls==0 and #free()==3,'Native object eligibility failure must not mutate slots');object_denied=false
local r=send('first','acquire','left');assert(r[3]=='held'and r[7]=='left'and #J.decode(P.decode(r[8]))==3)
assert(activity_queries==0,'Scripted reservations must not pretend to run a native tagged activity')
assert(states[1].OccupyingEntityId.Value==1 and states[2].OccupyingEntityId.Value==1 and states[5].OccupyingEntityId.Value==1)
assert(states[3].OccupyingEntityId.Value==0 and states[4].OccupyingEntityId.Value==0,'Unselected spots stay usable')
assert(not M.blocked(s),'An entity-wide query must still search unused seats')
assert(not Hook.Override_CanOccupySlot(s,1,{ComponentName='Seat1',SlotName='Sit'},true))
assert(Hook.Override_CanOccupySlot(s,1,{ComponentName='Seat3',SlotName='Sit'},true))
assert(Hook.Override_CanOccupySlotCheckOnlyEntity(s,1,{Value=3}))
assert(Hook.Override_CanOccupySlot(s,1,{SlotName='Sit'},false),'A generic slot-name search must not hide spare seats that share that name')
assert(not Hook.Override_CanOccupySlot(s,1,{ComponentName='Seat3',SlotName='Sit',LinkedComponentName='Seat2'},true),'A lying interaction may span the occupied pair')
assert(#free()==1 and free()[1]=='right')
local count=calls;assert(send('first','acquire','left')[3]=='held'and calls==count,'Retry is idempotent')
assert(send('overlap','acquire','middle',b)[3]=='busy')
assert(send('second','acquire','right',b)[3]=='held','Disjoint sofa pairs support simultaneous sessions')
assert(#free()==0)
local removed=removes;send('wrong','release','left',b);assert(removes==removed and states[1].OccupyingEntityId.Value==1)
assert(send('first','release','left')[3]=='released'and states[1].OccupyingEntityId.Value==0 and states[3].OccupyingEntityId.Value==2)
assert(#free()==1 and free()[1]=='left','Release does not clear the other scene')
send('second','release','right',b);assert(#free()==3)

occupy(2,7,2);count=calls;assert(send('occupied','acquire','left')[3]=='busy'and calls==count,'Native posture occupancy is never force-removed')
assert(#free()==1 and free()[1]=='right');empty(2)
states[2].Blocked=true;assert(send('blocked','acquire','left')[3]=='busy');states[2].Blocked=false
occupy(4,1,8);assert(not pcall(send,'foreign_same_owner','acquire','left'));assert(states[4].OccupyingEntityId.Value==1);empty(4)

fail_at=calls+2;r=send('partial','acquire','left');assert(r[3]=='busy'and r[7]=='left'and #free()==3,'Partial reservation rolls back all acquired aliases')
assert(r[5]=='Seat1Alias'and r[6]=='Sit','A native no-op failure identifies the exact attempted alias');fail_at=nil
throw_at=calls+2;assert(not pcall(send,'throwing','acquire','left'))
local l=M.find('50','throwing','1');assert(l and #l.slots==2 and l.acquired)
local retry=send('throwing','acquire','left');assert(retry[3]~='held'and l.releasing,'A retry cannot acknowledge a partial native claim')
assert(send('throwing','heartbeat','left')[3]~='held','A heartbeat cannot promote a partial native claim')
throw_at=nil;assert(M.release('50',l)and #free()==3,'Native mutation then throw retains exact cleanup ownership')
spill_at=calls+1;r=send('spill','acquire','left');assert(r[3]=='busy'and #free()==3,'Native unexpectedly reserving an unselected slot is rolled back')
assert(r[5]=='Seat1'and r[6]=='Sit','A native spill failure identifies the alias that triggered it');spill_at=nil
foreign_at=calls+1;r=send('became_occupied','acquire','left')
assert(r[3]=='busy'and r[4]=='native_occupied'and states[1].OccupyingEntityId.Value==0 and states[2].OccupyingEntityId.Value==7,
 'Recheck targets after each native mutation and roll back only this lease if a new occupant arrives');foreign_at=nil;empty(2)

assert(send('protected','acquire','left')[3]=='held');l=M.find('50','protected','1')
occupy(4,1,8);removed=removes;assert(not pcall(send,'protected','release','left')and removes==removed,'Unrecorded same-owner restriction prevents owner-wide removal')
assert(l.releasing and states[1].OccupyingEntityId.Value==1);empty(4);M.tick();assert(#free()==3)

assert(send('diagnostic_retry','acquire','left')[3]=='held');occupy(4,1,8);characters[1]=a
assert(not pcall(send,'diagnostic_retry','release','left'));local reported=#replies
M.tick();M.tick();assert(#replies==reported+1 and replies[#replies][3]=='release_pending'and replies[#replies][4]=='native_unrecorded_restriction',
 'A failed proof reaches rolling diagnostics once, rather than flooding every native tick')
now=105;M.tick();assert(#replies==reported+2,'Long-running ownership conflicts remain observable at a bounded interval')
empty(4);M.tick();characters[1]=nil;now=100;assert(#free()==3)

assert(send('reload','acquire','left')[3]=='held');l=M.find('50','reload','1');local recovery={id='50',owner='1',pair_id='left',spots=l.spots,slots=l.slots}
assert(send('other_recovery','acquire','right',b)[3]=='held')
M.leases={};send('reload','release','left',a,'held',recovery.slots,recovery.spots)
assert(states[1].OccupyingEntityId.Value==0 and states[3].OccupyingEntityId.Value==2,'B2 reload cleanup preserves foreign owner on same object')
M.restore_saved(b,{{id='50',owner='2',pair_id='right',spots={'s3','s4'},slots={{component_name='Seat3',slot_name='Sit'},{component_name='Seat4',slot_name='Sit'}}}},'other_recovery')
assert(#free()==3);M.restore_saved(a,{recovery},'reload');assert(#free()==3,'Saved cleanup is idempotent')
assert(send('partial_unconfirmed','acquire','left')[3]=='held');l=M.find('50','partial_unconfirmed','1')
local unconfirmed_slots=l.target_slots;local unconfirmed_spots=l.spots
assert(send('foreign_unconfirmed','acquire','right',b)[3]=='held');M.leases={}
send('partial_unconfirmed','release','left',a,'unconfirmed',unconfirmed_slots,unconfirmed_spots)
assert(states[1].OccupyingEntityId.Value==0 and states[3].OccupyingEntityId.Value==2,
 'An unconfirmed held acknowledgement lost across B2 reload still cleans its pre-journaled aliases')
M.restore_saved(b,{{id='50',owner='2',pair_id='right',spots={'s3','s4'},slots={{component_name='Seat3',slot_name='Sit'},{component_name='Seat4',slot_name='Sit'}}}},'foreign_unconfirmed')
throw_at=calls+2;assert(not pcall(send,'partial_lost_ack','acquire','left'));l=M.find('50','partial_lost_ack','1')
local partial_slots,partial_spots=l.target_slots,l.spots;assert(#l.slots==2);M.leases={};throw_at=nil
assert(send('partial_lost_ack','release','left',a,'unconfirmed',partial_slots,partial_spots)[3]=='released'and #free()==3,
 'A partial native claim lost before its held acknowledgement is cleaned by its planned alias proof after B2 reload')
assert(send('new_owner_token','acquire','left')[3]=='held');l=M.find('50','new_owner_token','1');removed=removes
assert(send('stale_owner_token','release','left',a,'unconfirmed',l.target_slots,l.spots)[3]=='release_pending'and removes==removed,
 'A stale release cannot clear a different live lease using the same owner')
send('new_owner_token','release','left');assert(send('stale_owner_token','release','left',a,'unconfirmed',l.target_slots,l.spots)[3]=='released')
assert(not pcall(M.saved_rows,{{id='50',owner='2',pair_id='left',spots={'s1','s2'},slots=recovery.slots}},'1'),'Recovery rejects wrong owner')
assert(not pcall(M.saved_rows,{{id='50',pair_id='left',spots={'s1','s1'},slots=recovery.slots}}),'Recovery rejects invalid spot pair')

assert(send('stream','acquire','left')[3]=='held');unloaded=true;local before=#replies
send('stream','release','left');assert(#replies==before and M.find('50','stream','1').releasing)
M.tick();assert(M.find('50','stream','1'));unloaded=false;M.tick();assert(not M.find('50','stream','1')and #free()==3)
assert(send('expiry','acquire','left')[3]=='held');now=109;M.tick();assert(#free()==3)
assert(send('expiry','acquire','left')[3]=='busy','An expired token cannot reoccupy sofa slots')
assert(send('owner_end','acquire','left')[3]=='held');M.release_owner(a);assert(#free()==3)
assert(send('all_end','acquire','left')[3]=='held');M.clear();assert(#free()==3)

-- An occupied pair is preparable only for the same selected Zois. Wait for
-- native cancellation and posture release; never erase a bystander's reasons.
local person={playing=true,queue=10,stands=0}
local interaction={GetCurrentInteractionQueueId=function()return person.queue end,IsCurrentInteractionNonCancelable=function()return person.non_cancellable==true end}
local posture={current={PostureId='SitSofa',PostureTargetEntityId={Value=50}},IsStanding=function(self)return self.current.PostureId=='Stand'end,
 GetCurrentPostureState=function(self)return self.current end}
function posture:SetPostureState(next_state)
 assert(not person.playing,'Never rewrite posture during an active task')
 assert(next_state.PostureId=='Stand'and next_state.PostureTargetEntityId.Value==0)
 person.stands=person.stands+1;self.current=next_state
 for i,row in ipairs(states)do if row.OccupyingEntityId.Value==1 then empty(i)end end
end
function person:IsPlayingInteraction()return self.playing end
function person:GetComponent(kind)if kind==15 then return interaction elseif kind==16 then return posture end end
characters[1]=person
occupy(1,1,2);occupy(2,1,1);occupy(5,1,2);occupy(3,7,2)
local status=send('status','look');local clearable=J.decode(P.decode(status[5]))
assert(#J.decode(P.decode(status[4]))==0 and clearable.left[1]=='1'and not clearable.middle,'Status distinguishes free pairs from a clearable selected participant')
count=calls;local response=send('seated','acquire','left')
assert(response[3]=='preparing'and response[4]=='native_interaction_finishing'and response[7]=='left'and calls==count)
assert(cancelled[1]==1 and not cancelled[7]and person.stands==0)
assert(not Hook.Override_CanOccupySlot(s,1,{ComponentName='Seat2',SlotName='Sit'},true),'A clearing pair rejects new entrants before native restriction exists')
assert(Hook.Override_CanOccupySlot(s,1,{ComponentName='Seat4',SlotName='Sit'},true),'Clearing does not block a spare seat')
assert(Hook.Override_CanOccupySlot(s,1,{SlotName='Sit'},false),'A pending pair must not turn a generic seat search into a whole-sofa lock')
send('seated','acquire','left');assert(cancelled[1]==1 and person.stands==0,'Repeated request does not cancel the same native queue twice')
person.playing=false;response=send('seated','acquire','left')
assert(response[3]=='preparing'and response[4]=='native_getup_finishing'and person.stands==0 and person.getups==1 and calls==count)
assert(states[3].OccupyingEntityId.Value==7,'An unselected sofa occupant remains seated')
-- Native vacancy or logical Stand alone cannot short-circuit the full exit.
empty(1);empty(2);empty(5);posture.current={PostureId='Stand',PostureTargetEntityId={Value=-1}}
assert(send('seated','acquire','left')[3]=='preparing'and calls==count,
 'An owned queued/current native GetUp blocks the vacancy fast path until fully finished')
person.getup_pending=false;person.getup_sample.state='finished'
response=send('seated','acquire','left');assert(response[3]=='held'and calls>count and states[3].OccupyingEntityId.Value==7,'Claim starts only after native vacancy is confirmed')
send('seated','release','left');empty(3)

characters[7]=person;occupy(2,7,2);status=send('status','look');clearable=J.decode(P.decode(status[5]))
assert(clearable.left[1]=='7','Read-only status can describe an occupied pair before roster selection')
local before_cancel=cancelled[1];removed=removes
assert(send('bystander','acquire','left')[3]=='busy'and removes==removed and cancelled[1]==before_cancel and not cancelled[7],
 'Acquisition refuses a bystander even though the same sofa pair could be cleared for that Zoi in another roster')
empty(2);characters[7]=nil
person.playing=true;person.non_cancellable=true;occupy(2,1,1)
status=send('status','look');clearable=J.decode(P.decode(status[5]));assert(not clearable.left,'A native non-cancellable task is not advertised as preparable')
assert(send('non_cancellable','acquire','left')[3]=='busy'and cancelled[1]==before_cancel,'A non-cancellable task is left untouched')
person.non_cancellable=false;empty(2)
person.playing=true;person.queue=11;posture.current={PostureId='SitSofa',PostureTargetEntityId={Value=50}};occupy(2,1,2)
assert(send('cancel_pending','acquire','left')[3]=='preparing');local stands=person.stands;removed=removes
send('cancel_pending','release','left');assert(person.stands==stands and removes==removed and states[2].OccupyingEntityId.Value==1,
 'Cancelling preparation removes only its guard, not an unacquired native occupancy')
empty(2);characters[1]=nil
print('Sofa pair leases passed: physical aliases, spare seats, linked lying targets, two disjoint sessions, ownership proof, rollback, saved/B2-reload recovery, streaming and watchdog.')

-- A held Lua lease is not proof that native ownership is still intact.
assert(#free()==3)
assert(send('changed_owner','acquire','left')[3]=='held')
occupy(2,7,2)
local changed=send('changed_owner','heartbeat','left')
assert(changed[3]=='missing'and changed[4]=='native_pair_owner_changed',
 'A foreign owner replacing a held alias must not receive a renewed held acknowledgement')
assert(send('changed_owner','acquire','left')[3]~='held','Retry cannot revive a lease after native ownership changed')
send('changed_owner','release','left')
assert(states[2].OccupyingEntityId.Value==7 and has(states[2],2),'Cleanup preserves the replacement native occupant')
assert(states[1].OccupyingEntityId.Value==0 and states[5].OccupyingEntityId.Value==0);empty(2)

assert(send('changed_on_retry','acquire','left')[3]=='held');occupy(2,7,2)
changed=send('changed_on_retry','acquire','left')
assert(changed[3]=='missing'and changed[4]=='native_pair_owner_changed',
 'Retry-acquire must revalidate a fresh held lease before any heartbeat notices the loss')
assert(states[2].OccupyingEntityId.Value==7 and has(states[2],2)and states[1].OccupyingEntityId.Value==0,
 'Retry-acquire rollback preserves the replacement occupant')
send('changed_on_retry','release','left');empty(2)

assert(send('changed_reason','acquire','left')[3]=='held')
states[1].SlotOccupyingReasons={8,2}
changed=send('changed_reason','heartbeat','left')
assert(changed[3]=='missing'and changed[4]=='native_pair_reason_changed',
 'A normal posture mixed into a reserved alias invalidates the native lease proof')
assert(send('changed_reason','acquire','left')[3]~='held')
send('changed_reason','release','left')
assert(states[1].OccupyingEntityId.Value==1 and has(states[1],2)and not has(states[1],8),
 'Restore removes only its Restricted reason, preserving a new native posture');empty(1)

assert(send('alias_disappeared','acquire','left')[3]=='held')
local removed_alias=table.remove(states,2)
changed=send('alias_disappeared','heartbeat','left')
assert(changed[3]=='missing'and changed[4]=='native_pair_alias_missing','Every planned alias must still exist after acquisition')
assert(send('alias_disappeared','acquire','left')[3]~='held')
send('alias_disappeared','release','left')
removed_alias.OccupyingEntityId.Value=0;removed_alias.SlotOccupyingReasons={};table.insert(states,2,removed_alias)

local original_component=states[2].ComponentName;states[2].ComponentName='UnexpectedReplacement'
count=calls
assert(not pcall(send,'mismatched_native_alias','acquire','left')and calls==count and not M.find('50','mismatched_native_alias','1'),
 'A changed native topology fails before any slot mutation or lease creation')
states[2].ComponentName=original_component

assert(send('became_blocked','acquire','left')[3]=='held');states[2].Blocked=true
changed=send('became_blocked','heartbeat','left')
assert(changed[3]=='missing'and changed[4]=='native_pair_blocked')
send('became_blocked','release','left');states[2].Blocked=false

assert(send('new_unrecorded_restriction','acquire','left')[3]=='held');occupy(4,1,8)
changed=send('new_unrecorded_restriction','heartbeat','left')
assert(changed[3]=='missing'and changed[4]=='native_unrecorded_restriction')
local pending=assert(M.find('50','new_unrecorded_restriction','1'))
assert(pending.releasing and has(states[4],8)and has(states[1],8),
 'Owner-wide removal waits rather than erase an unrecorded restriction')
empty(4);M.tick();assert(not M.find('50','new_unrecorded_restriction','1')and #free()==3)
print('Held sofa proof passed: native owner/reason/topology changes, blocked aliases and unrecorded restrictions cannot renew a held lease; cleanup preserves foreign state.')

-- A missing reply may synchronously run Exit callbacks and a new start. Finish
-- the old cleanup before notifying B1, or that old handler can erase the new lease.
assert(send('reentrant_old','acquire','left')[3]=='held');empty(1)
local original_sender=inzoi.message.send_to_client
local loss_reply,fresh_reply
inzoi.message.send_to_client=function(recipient,name,packet)
 original_sender(recipient,name,packet)
 local fields=P.unpack(packet)
 if fields[1]=='reentrant_old'and fields[3]=='missing'then
  loss_reply=fields
  send('reentrant_old','release','left')
  fresh_reply=send('reentrant_fresh','acquire','left')
 end
end
send('reentrant_old','heartbeat','left')
inzoi.message.send_to_client=original_sender
assert(loss_reply and fresh_reply and fresh_reply[3]=='held','A loss callback can immediately acquire a fresh lease')
local fresh_lease=assert(M.find('50','reentrant_fresh','1'),'The old handler must not erase the replacement Lua lease')
assert(not fresh_lease.releasing and states[1].OccupyingEntityId.Value==1 and has(states[1],8)and
 states[2].OccupyingEntityId.Value==1 and has(states[2],8)and states[5].OccupyingEntityId.Value==1 and has(states[5],8),
 'The old handler must not release the replacement native reservation after its callback returns')
assert(not M.find('50','reentrant_old','1'));send('reentrant_fresh','release','left');assert(#free()==3)

-- A reload during selected-occupant clearing has a planned journal but no
-- acquired Restricted reason. Recovery must leave native sitting/task state alone.
characters[1]=person;person.playing=true;person.queue=12;person.non_cancellable=false
posture.current={PostureId='SitSofa',PostureTargetEntityId={Value=50}}
occupy(1,1,2);occupy(2,1,1);occupy(5,1,2)
assert(send('reload_before_claim','acquire','left')[3]=='preparing')
local pending_clear=assert(M.find('50','reload_before_claim','1'))
assert(pending_clear.clearing and not pending_clear.acquired and #pending_clear.slots==0)
local planned={id='50',owner='1',pair_id='left',spots=pending_clear.spots,slots=pending_clear.target_slots}
local cancellations,stand_count=cancelled[1],person.stands
M.leases={}
M.restore_saved(a,{planned},'reload_before_claim')
assert(states[1].OccupyingEntityId.Value==1 and has(states[1],2)and states[2].OccupyingEntityId.Value==1 and has(states[2],1)and has(states[5],2),
 'Pre-acquisition recovery must preserve normal Posture and Interaction reasons')
assert(cancelled[1]==cancellations and person.stands==stand_count and person.playing,
 'Recovery does not repeat task cancellation or force an unfinished task to Stand')
assert(not M.blocked(s));empty(1);empty(2);empty(5);characters[1]=nil
print('Pending sofa reload passed: planned recovery with no native claim preserves normal task and posture ownership.')

characters[1]=person;person.playing=false;posture.current={PostureId='SitSofa',PostureTargetEntityId={Value=50}}
occupy(1,1,2);occupy(2,1,2);occupy(5,1,2)
assert(send('abort_getup','acquire','left')[3]=='preparing'and person.getup_pending)
local awaiting=assert(M.find('50','abort_getup','1'));local reply_count=#replies
send('abort_getup','release','left');assert(#replies==reply_count and awaiting.releasing)
M.tick();assert(M.find('50','abort_getup','1')and M.blocked(s,1,{ComponentName='Seat1',SlotName='Sit'}),
 'Abort retains the selected-pair guard until the native exit finishes without cancellation')
person.getup_pending=false;person.getup_sample.state='finished'
posture:SetPostureState({PostureId='Stand',PostureTargetEntityId={Value=0}})
M.tick();assert(not M.find('50','abort_getup','1')and #free()==3)
characters[1]=nil

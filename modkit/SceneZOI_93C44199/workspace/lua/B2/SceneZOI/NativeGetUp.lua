-- Share the game's complete Stand interaction between furniture acquisition
-- and participant preparation. A logical SetPostureState alone skips the native
-- end animation and RestoreAnimTransform, leaving the old seat motion in control.
local P=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local M={records={},clock=0,max_records=128}
local function entity(id)local value=inzoi.FB1EntityId();value.Value=tonumber(id);return value end
local function object(id)return inzoi.getB2Manager('FB2EntityManager'):FindGameObject(entity(id))end
---@param owner FB2Character
local function interaction(owner)return assert(owner:GetComponent(inzoi.EB2ComponentType.Interaction),'Missing interaction component')end
---@param owner FB2Character
local function posture(owner)return assert(owner:GetComponent(inzoi.EB2ComponentType.Posture),'Missing posture component')end
local function has_reason(row,value)
 for _,reason in ipairs(row.SlotOccupyingReasons or {})do if reason==value then return true end end
 return false
end
local function ordinary_claims(slots,who)
 if not slots then return true end -- Streaming loss is not proof of release.
 for _,row in ipairs(slots.SlotStateInfos)do
  if row.OccupyingEntityId and P.id(row.OccupyingEntityId)==who and
   (has_reason(row,inzoi.EB1SlotOccupyingReason.Posture)or has_reason(row,inzoi.EB1SlotOccupyingReason.Interaction))then return true end
 end
 return false
end
---@param owner FB2Character
local function source(owner)
 local p=posture(owner);local state=p:GetCurrentPostureState();local name=tostring(state.PostureId)
 local target=state.PostureTargetEntityId and P.id(state.PostureTargetEntityId)
 local component,slot=tostring(state.BaseComponentName),tostring(state.OccupyingSlot)
 if p:IsStanding()or p:IsRiddingVehicle()or name=='Carried'or name=='Swim'or name=='Dive'or name=='Surf'or not target or
  not tonumber(target)or tonumber(target)<=0 or component=='None'or slot=='None'then return end
 local initial={id=target,owner=P.id(owner:GetEntityId()),component=component,slot=slot,posture_id=name}
 local o=object(target)
 if not o then return initial,'native_getup_source_unavailable'end
 local slots=o:GetComponent(inzoi.EB2ComponentType.Slot)
 if not slots then return end -- A non-slot object is not a furniture seat.
 local row=slots and slots:GetSlotStateInfoByComponentName(inzoi.EB1SlotType.Interaction,component)
 local who=P.id(owner:GetEntityId())
 if row and tostring(row.ComponentName)==component and tostring(row.SlotName)==slot and
  row.OccupyingEntityId and P.id(row.OccupyingEntityId)==who and has_reason(row,inzoi.EB1SlotOccupyingReason.Posture)then
  return initial
 end
 return initial,'native_getup_source_unproven'
end
---@param owner FB2Character
local function queues(owner)
 local c=interaction(owner);local result={}
 for _,row in ipairs(c.InteractionQueue or {})do
  local id=tostring(row.InteractionQueueId)
  result[id]={queue_id=id,bag=tostring(row.InteractionBagId),target=row.PickedEntityId and P.id(row.PickedEntityId)}
 end
 if owner:IsPlayingInteraction()then
  local id=tostring(c:GetCurrentInteractionQueueId())
  local bag=tostring(c:GetCurrentInteractionBagId())
  result[id]={queue_id=id,bag=bag,target=bag=='Stand'and P.id(c:GetCurrentInteractionTargetEntityId())or nil}
 end
 return result
end
---@param owner FB2Character
local function posture_motion(owner)
 local ok,_,text=inzoi.cli.execute('motion.get_current entity_id='..P.id(owner:GetEntityId()))
 if not ok or type(text)~='string'then return nil end
 local decoded,data=pcall(Json.decode,text)
 if not decoded or type(data)~='table'or type(data.motions)~='table'then return nil end
 for _,motion in ipairs(data.motions)do
  if motion.group=='PostureGroup'then return true,motion.anim_id,motion.montage_id end
 end
 return false
end
local function failed(r,reason)
 r.state,r.failure,r.terminal_at='failed',reason,M.clock
 return r
end
---@param owner FB2Character
local function update(owner,r)
 if r.state=='finished'or r.state=='failed'then return r end
 local active=queues(owner)
 if not r.queue_id then
  for id,row in pairs(active)do
   if row.bag=='Stand'and row.target==r.id and not r.before[id]then
    if r.queue_id then return failed(r,'native_getup_queue_ambiguous')end
    r.queue_id=id
   end
  end
 end
 local q=r.queue_id and active[r.queue_id]
 if q and(q.bag~='Stand'or q.target~=r.id)then return failed(r,'native_getup_queue_replaced')end
 r.queue_present=q~=nil
 local p=posture(owner);local current=p:GetCurrentPostureState()
 r.current_posture,r.current_target=tostring(current.PostureId),P.id(current.PostureTargetEntityId)
 r.standing=p:IsStanding()
 local o=object(r.id);local slots=o and o:GetComponent(inzoi.EB2ComponentType.Slot)
 r.claim_pending=ordinary_claims(slots,r.owner)
 if r.queue_present then r.state='queued';r.absent_since=nil;r.idle_checks=0;r.last_transform=nil;return r end
 r.absent_since=r.absent_since or M.clock
 r.state='finishing'
 if not r.queue_id then
  r.idle_checks=0;r.last_transform=nil
  if M.clock-r.absent_since>=2 then return failed(r,'native_getup_queue_untracked')end
  return r
 end
 if not r.standing or r.current_target==r.id or r.claim_pending then
  r.idle_checks=0;r.last_transform=nil
  if M.clock-r.absent_since>=2 then return failed(r,'native_getup_incomplete')end
  return r
 end
 r.motion_pending,r.anim_id,r.montage_id=posture_motion(owner)
 if r.motion_pending~=false then
  r.idle_checks=0;r.last_transform=nil
  if M.clock-r.absent_since>=10 then return failed(r,'native_getup_motion_unsettled')end
  return r
 end
 if r.idle_clock~=M.clock then
  local position,rotation=owner:GetLocation(),owner:GetRotation()
  local transform={position.X,position.Y,position.Z,rotation.Pitch,rotation.Yaw,rotation.Roll}
  local previous=r.last_transform;local stable=previous~=nil
  if previous then
   local distance=0;for i=1,3 do distance=distance+(transform[i]-previous[i])^2 end
   if distance>.25 then stable=false end -- Half a centimetre, including vertical settlement.
   for i=4,6 do if math.abs((transform[i]-previous[i]+180)%360-180)>.1 then stable=false end end
  end
  r.position_settled=stable;r.last_transform=transform
  r.idle_checks=stable and(r.idle_checks or 0)+1 or 1;r.idle_clock=M.clock
 end
 if r.idle_checks>=2 then r.state='finished';r.terminal_at=M.clock end
 if r.state~='finished'and M.clock-r.absent_since>=10 then return failed(r,'native_getup_position_unsettled')end
 return r
end
local function count()local n=0;for _ in pairs(M.records)do n=n+1 end;return n end
---@param owner FB2Character
local function adopt(owner)
 -- Native Stand may already be underway (including after B2 reload). Join the
 -- exact actor/queue/source operation; never cancel it as ordinary queued work.
 local selected,ambiguous,protected=nil,false,{}
 for _,row in pairs(queues(owner))do if row.bag=='Stand'and row.target and tonumber(row.target)and tonumber(row.target)>0 and object(row.target)then
  protected[row.queue_id]=row.target
  if selected then ambiguous=true else selected=row end
 end end
 if not selected then return end
 local p=posture(owner);local state=p:GetCurrentPostureState()
 local r={id=selected.target,owner=P.id(owner:GetEntityId()),component=tostring(state.BaseComponentName),
  slot=tostring(state.OccupyingSlot),posture_id=tostring(state.PostureId),queue_id=selected.queue_id,
  before={},state='queued',started=M.clock,adopted=true,protect_queues=protected}
 if ambiguous then failed(r,'native_getup_queue_ambiguous')end
 if count()>=M.max_records then return failed(r,'native_getup_capacity')end
 M.records[r.owner]=r;return r
end
---@param owner FB2Character
function M.pending(owner)
 local r=M.records[P.id(owner:GetEntityId())]or adopt(owner)
 if r then update(owner,r)end
 local waiting=r and r.state~='finished'and r.state~='failed'or false
 if r and r.state=='failed'then
  -- A tracking/observation failure cannot grant permission to cancel an exit
  -- still running. Leave those exact actor/source native Stand queues intact.
  for id,q in pairs(queues(owner))do if q.bag=='Stand'and(q.target==r.id or(r.protect_queues and r.protect_queues[id]==q.target))then waiting=true end end
 end
 return waiting,r
end
---@param owner FB2Character
function M.ensure(owner,token)
 local waiting,r=M.pending(owner)
 if r then
  r.detached=false
  if waiting then r.token=r.token or token;return false,r end
  if r.state=='failed'and r.token==token then return false,r end
  M.records[r.owner]=nil
 end
 local initial,invalid=source(owner)
 if not initial then return true,r end
 if count()>=M.max_records then initial.state='failed';initial.failure='native_getup_capacity';return false,initial end
 initial.before=queues(owner);initial.token=token;initial.state='queued';initial.started=M.clock
 M.records[initial.owner]=initial
 if invalid then return false,failed(initial,invalid)end
 local ok,result=pcall(function()
  return interaction(owner):AddInteractionQueueByParam(entity(initial.id),owner:GetLocation(),'Stand',
   inzoi.EB1InteractionPlayReason.User,true,false,'SceneZOI',true,false)
 end)
 if not ok then failed(initial,'native_getup_enqueue_error');initial.detail=tostring(result);return false,initial end
 if result~=inzoi.EB1AddInteractionQueueResult.Success then
  failed(initial,'native_getup_enqueue_rejected');initial.queue_result=result;return false,initial
 end
 update(owner,initial)
 return false,initial
end
---@param owner FB2Character
function M.detach(owner,token)
 local r=M.records[P.id(owner:GetEntityId())]
 if r and(r.token==token or r.adopted)then r.detached=true end
end
---@param owner FB2Character
function M.sample(owner)return M.records[P.id(owner:GetEntityId())]end
function M.tick(dt)
 if not dt or dt<=0 then return end
 M.clock=M.clock+dt
 if M.clock<(M.next_poll or 0)then return end
 M.next_poll=M.clock+.1
 for who,r in pairs(M.records)do
  local owner=inzoi.getB2Manager('FB2EntityManager'):FindCharacter(entity(who))
  if not owner then M.records[who]=nil
  else
   local ok,err=pcall(update,owner,r)
   if not ok then failed(r,'native_getup_observe_error');r.detail=tostring(err)end
   if r.terminal_at and M.clock-r.terminal_at>=60 then M.records[who]=nil end
  end
 end
end
return M

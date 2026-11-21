-- Beds reserve a whole surface; sofas hold only an authored pair of physical spots.
local P=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local Pairs=require('SceneZOI.FurniturePairs')
local V=require('SceneZOI.DataValidation')
local GetUp=require('SceneZOI.NativeGetUp')
local M={leases={},retired={},hooks=false}
local function id(v)return tostring(v.Value)end
local function entity(v)local e=inzoi.FB1EntityId();e.Value=tonumber(v);return e end
local function object(v)return inzoi.getB2Manager('FB2EntityManager'):FindGameObject(entity(v))end
local function slot(o)return o:GetComponent(inzoi.EB2ComponentType.Slot)end
local function key(c,n)return c..'\0'..n end
local function rowkey(row)return key(tostring(row.ComponentName),tostring(row.SlotName))end
local function leasekey(bed,pair)return pair and bed..':'..pair or bed end
local function reason(state,value)
 for _,item in ipairs(state.SlotOccupyingReasons or {})do if item==value then return true end end
 return false
end
local function owned_restrictions(s,who)
 local rows={}
 for _,state in ipairs(s.SlotStateInfos)do
  if state.OccupyingEntityId and id(state.OccupyingEntityId)==who and reason(state,inzoi.EB1SlotOccupyingReason.Restricted)then
   rows[rowkey(state)]={component_name=tostring(state.ComponentName),slot_name=tostring(state.SlotName)}
  end
 end
 return rows
end
local function list(rows)
 local result={};for _,row in pairs(rows)do result[#result+1]=row end
 table.sort(result,function(a,b)return key(a.component_name,a.slot_name)<key(b.component_name,b.slot_name)end)
 return result
end
local function reply(owner,token,bed,code,why,lease,available,clearable)
 local c,n=lease and lease.component,lease and lease.slot
 c=c and c:gsub('[^%w_.:+%-]','_');n=n and n:gsub('[^%w_.:+%-]','_')
 local packet
 if available then packet=P.pack(token,bed,code,P.encode(Json.encode(Json.array(available))),P.encode(Json.encode(clearable or {})))
 elseif why then packet=P.pack(token,bed,code,why,c and c~=''and c or'none',n and n~=''and n or'none',
  lease and lease.pair_id or'none',lease and lease.pair_id and P.encode(Json.encode(lease.slots or {}))or'none')
 else packet=P.pack(token,bed,code)end
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.FurnitureReply',packet)
end
local function find(bed,token,who)
 for _,l in pairs(M.leases)do if l.bed==bed and l.token==token and l.owner==who then return l end end
end
M.find=find
local function different_owner_lease(bed,who,token)
 for _,l in pairs(M.leases)do if l.bed==bed and l.owner==who and l.token~=token then return true end end
 return false
end
local function conflicts(bed,spots,except)
 for _,l in pairs(M.leases)do if l.bed==bed and l~=except and Pairs.overlap(spots,l.spots)then return true end end
 return false
end
-- Let broad entity-only queries find unused sofa seats. Exact target queries
-- reject either end of a linked/lying interaction that touches our pair.
function M.blocked(component,kind,param)
 local bed=id(component:GetOwnerEntityId())
 for _,l in pairs(M.leases)do if l.bed==bed then
  if not l.pair_id and not l.acquiring then return true end
  local claiming=param and l.acquiring and not l.clearing and param.OccupyEntityId and id(param.OccupyEntityId)==l.owner and
   param.OccupyingReason==inzoi.EB1SlotOccupyingReason.Restricted
  if l.pair_id and param and kind==inzoi.EB1SlotType.Interaction and not claiming then
   local c,n,linked=tostring(param.ComponentName or''),tostring(param.SlotName or''),tostring(param.LinkedComponentName or'')
   for _,row in ipairs(l.target_slots or l.slots)do
    if(c~=''and c==row.component_name and(n==''or n==row.slot_name))or
      (linked~=''and linked==row.component_name)then return true end
   end
  end
 end end
 return false
end
local function clear_restriction(bed,owner,l)
 local o=object(bed);if not o then return false end
 local s=assert(slot(o),'Furniture has no native interaction slots')
 if l and l.pair_id then
  local expected={};for _,row in ipairs(l.slots)do expected[key(row.component_name,row.slot_name)]=true end
  -- Native removal is owner-wide. Prove it cannot erase an unrecorded
  -- restriction for this owner; other owners and other reasons survive.
  for k in pairs(owned_restrictions(s,id(owner)))do assert(expected[k],'Furniture owner has an unrecorded native restriction')end
  s:RemoveOccupyingReasonByEntityId(owner,inzoi.EB1SlotOccupyingReason.Restricted)
  assert(not next(owned_restrictions(s,id(owner))),'Furniture native restriction was not removed')
 else s:RemoveOccupyingReasonByEntityId(owner,inzoi.EB1SlotOccupyingReason.Restricted)end
 return true
end
function M.release(bed,l)
 l.releasing=true
 for who in pairs(l.getup_ids or {})do
  local person=inzoi.getB2Manager('FB2EntityManager'):FindCharacter(entity(who))
  if person and GetUp.pending(person)then return false end
 end
 if l.acquired and not clear_restriction(bed,entity(l.owner),l)then return false end
 M.leases[l.key or bed]=nil;M.retired[l.token]=os.time();return true
end
local function target_rows(profile,pair_id,s)
 local pair=assert(Pairs.find(profile,pair_id),'Unknown furniture pair')
 local rows,wanted,states={},{},{}
 for _,spot in ipairs(Pairs.spots(profile,pair))do for _,row in ipairs(spot.slots)do
  wanted[key(row.component_name,row.slot_name)]=true;rows[#rows+1]={component_name=row.component_name,slot_name=row.slot_name}
 end end
 for _,state in ipairs(s.SlotStateInfos)do if wanted[rowkey(state)]then states[rowkey(state)]=state end end
 for k in pairs(wanted)do assert(states[k],'Authored sofa slot is missing from the native object')end
 return pair,rows,states,wanted
end
local function vacancy(states)
 for _,state in pairs(states)do
  if state.Blocked then return false end
  if state.OccupyingEntityId and(tonumber(id(state.OccupyingEntityId))or 0)>0 then return false end
  for _,value in ipairs(state.SlotOccupyingReasons or {})do if value~=inzoi.EB1SlotOccupyingReason.None then return false end end
 end
 return true
end
local function profile_for(o,encoded)
 local profile=require('SceneZOI.FurnitureData').profile(Json.decode(P.decode(encoded)))
 local matched=false;for _,name in ipairs(profile.objects)do if name==tostring(o.ObjectTableId)then matched=true end end
 assert(matched,'Furniture profile does not match native object');return profile
end
---@param zoi_actor FB2Character
local function can_clear_person(zoi_actor)
 if zoi_actor:IsPlayingInteraction()then
  local interaction=zoi_actor:GetComponent(inzoi.EB2ComponentType.Interaction)
  if not interaction or(interaction:IsCurrentInteractionNonCancelable()and not GetUp.pending(zoi_actor))then return false end
 end
 return true
end
---@param zoi_actor FB2Character
local function character_interaction_state(zoi_actor)
 return zoi_actor:GetComponent(inzoi.EB2ComponentType.Interaction),zoi_actor:IsPlayingInteraction()
end
local function clearing_occupants(states,allowed)
 local occupants={}
 ---@type FB2EntityManager
 local manager=inzoi.getB2Manager('FB2EntityManager')
 for _,state in pairs(states)do
  if state.Blocked then return end
  local who=state.OccupyingEntityId and id(state.OccupyingEntityId)
  local held=who and(tonumber(who)or 0)>0;local known=false
  for _,value in ipairs(state.SlotOccupyingReasons or {})do
   if value~=inzoi.EB1SlotOccupyingReason.None and value~=inzoi.EB1SlotOccupyingReason.Interaction and value~=inzoi.EB1SlotOccupyingReason.Posture then return end
   if value~=inzoi.EB1SlotOccupyingReason.None and not held then return end
   if value~=inzoi.EB1SlotOccupyingReason.None then known=true end
  end
  if held then
   if not known then return end
   if allowed and not allowed[who]then return end
   ---@type FB2Character
   local person=manager:FindCharacter(entity(who));if not person then return end
   if not can_clear_person(person)then return end
   occupants[who]=person
  end
 end
 return occupants
end
local function free_pairs(bed,profile,s)
 local result,clearable={},{}
 for _,pair in ipairs(profile.seat_pairs)do
  local ok,_,_,states=pcall(target_rows,profile,pair.id,s)
  if ok and not conflicts(bed,pair.spots)then
   if vacancy(states)then result[#result+1]=pair.id
   else
    local people=clearing_occupants(states)
    if people and next(people)then local ids={};for who in pairs(people)do ids[#ids+1]=who end;table.sort(ids);clearable[pair.id]=Json.array(ids)end
   end
  end
 end
 return result,clearable
end
-- Old save journals contain only bed IDs; preserve that backward compatibility.
-- Sofa records carry exact slots for recovery when B2's Lua leases are gone.
function M.saved_rows(rows,who)
 -- Earlier save snapshots encoded an empty furniture list as a JSON object.
 if type(rows)=='table'and not next(rows)then return {}end
 V.array(rows,4);local result={}
 for _,row in ipairs(rows)do
  if type(row)=='string'then assert(row:match('^%d+$'),'Invalid furniture ID');result[#result+1]=row
  else
   V.fields(row,{'id','owner','pair_id','spots','slots'},{'id','pair_id','spots','slots'})
   assert(type(row.id)=='string'and row.id:match('^%d+$'),'Invalid furniture ID')
   if row.owner~=nil then assert(type(row.owner)=='string'and row.owner:match('^%d+$')and(not who or row.owner==who),'Invalid furniture owner')end
   V.id(row.pair_id);V.array(row.spots,2);assert(#row.spots==2 and row.spots[1]~=row.spots[2],'Invalid furniture spots')
   for _,name in ipairs(row.spots)do V.id(name)end
   V.array(row.slots,64);assert(#row.slots>0,'Invalid furniture slots');local seen={}
   for _,value in ipairs(row.slots)do
    V.fields(value,{'component_name','slot_name'},{'component_name','slot_name'});V.name(value.component_name);V.name(value.slot_name)
    local k=key(value.component_name,value.slot_name);assert(not seen[k],'Duplicate furniture slot');seen[k]=true
   end
   result[#result+1]={id=row.id,owner=row.owner,pair_id=row.pair_id,spots=row.spots,slots=row.slots}
  end
 end
 return result
end
local function reserve_pair(tentative,owner,s,rows,wanted)
 local bed,token,who=tentative.bed,tentative.token,tentative.owner
 tentative.clearing=nil
 local o=assert(object(bed),'Furniture unloaded during reservation')
 if not s:IsOccupiableEntity(owner:GetEntityId())or not o:IsOccupiableEntity(owner:GetEntityId())then
  assert(M.release(bed,tentative),'Furniture not loaded during eligibility rollback')
  reply(owner,token,bed,'busy','native_entity_ineligible',tentative);return
 end
 for _,row in ipairs(rows)do
  local k=key(row.component_name,row.slot_name)
  if not owned_restrictions(s,who)[k]then
   -- Recheck every target immediately before mutation. Already-acquired rows
   -- may have only our Restricted reason; a new task or bystander must survive.
   local _,_,states=target_rows(tentative.profile,tentative.pair_id,s)
   local available=not conflicts(bed,tentative.spots,tentative)
   for _,state in pairs(states)do
    local occupied=state.OccupyingEntityId and(tonumber(id(state.OccupyingEntityId))or 0)>0
    if state.Blocked or(occupied and(id(state.OccupyingEntityId)~=who or not reason(state,inzoi.EB1SlotOccupyingReason.Restricted)))then available=false end
    for _,value in ipairs(state.SlotOccupyingReasons or {})do
     if value~=inzoi.EB1SlotOccupyingReason.None and(not occupied or value~=inzoi.EB1SlotOccupyingReason.Restricted)then available=false end
    end
   end
   if not available then
    assert(M.release(bed,tentative),'Furniture not loaded during reservation rollback')
    reply(owner,token,bed,'busy','native_occupied',tentative);return
   end
   local param=inzoi.FB2TargetSlotParam();param.ComponentName=row.component_name;param.SlotName=row.slot_name
   param.UsageType=inzoi.EB1SlotUsageType.Single
   param.OccupyEntityId=owner:GetEntityId();param.OccupyingReason=inzoi.EB1SlotOccupyingReason.Restricted
   param.bCheckCanMove=false;param.bCheckOwnershipSlot=false
   tentative.component=row.component_name;tentative.slot=row.slot_name
   -- TryOccupySlot also requires a matching native activity tag (Sit,
   -- Sit_PassOut, etc.). A scripted reservation runs none of those activities.
   -- Keep native entity eligibility and exact vacancy checks above, then use
   -- the native occupancy mutator and verify its complete owner/reason result.
   -- A native call can mutate before throwing; retain the affected slots.
   tentative.acquired=true;local ok,err=pcall(s.OccupySlot,s,inzoi.EB1SlotType.Interaction,param)
   local added=owned_restrictions(s,who);tentative.slots=list(added)
   if not ok then error(err)end
   local valid=added[k]~=nil
   for acquired in pairs(added)do if not wanted[acquired]then valid=false end end
   if not valid then
    assert(M.release(bed,tentative),'Furniture not loaded during acquisition rollback')
    reply(owner,token,bed,'busy','native_pair_reservation_failed',tentative);return
   end
  end
 end
 local complete=owned_restrictions(s,who)
 for k in pairs(wanted)do if not complete[k]then
  tentative.slots=list(complete);assert(M.release(bed,tentative),'Furniture not loaded during acquisition rollback')
  reply(owner,token,bed,'busy','native_pair_reservation_failed',tentative);return
 end end
 tentative.acquiring=nil;tentative.component=rows[1].component_name;tentative.slot=rows[1].slot_name
 reply(owner,token,bed,'held','native_pair_reserved',tentative)
end
local function preparing(owner,l,phase)
 if l.wait_phase~=phase then l.wait_phase=phase;reply(owner,l.token,l.bed,'preparing',phase,l)end
end
local function advance_pair(owner,l)
 local o=object(l.bed);if not o then return end
 local s=assert(slot(o),'Furniture has no native interaction slots')
 -- Vacancy can precede the end animation. The exact queued native GetUp must
 -- finish before either the classifier or vacancy fast path can reserve seats.
 local waiting=false
 for who in pairs(l.allowed)do
  local person=inzoi.getB2Manager('FB2EntityManager'):FindCharacter(entity(who))
  if person then
   local pending,sample=GetUp.pending(person)
   if pending then l.getup_ids=l.getup_ids or {};l.getup_ids[who]=true;waiting=true
   elseif l.getup_ids and l.getup_ids[who]and sample and sample.state=='failed'then
    assert(M.release(l.bed,l),'Furniture not loaded during GetUp rollback')
    reply(owner,l.token,l.bed,'busy',sample.failure or'native_getup_failed',l);return
   end
  end
 end
 if waiting then preparing(owner,l,'native_getup_finishing');return end
 local _,rows,states,wanted=target_rows(l.profile,l.pair_id,s)
 if vacancy(states)then reserve_pair(l,owner,s,rows,wanted);return end
 local people=clearing_occupants(states,l.allowed)
 if not people then
  assert(M.release(l.bed,l),'Furniture not loaded during preparation rollback')
  reply(owner,l.token,l.bed,'busy','native_occupied',l);return
 end
 l.clearing=true;l.cancelled=l.cancelled or {}
 local phase='native_posture_clearing'
 for who,person in pairs(people)do
  local interaction,playing=character_interaction_state(person)
  assert(interaction,'Missing interaction component')
  if playing then
   phase='native_interaction_finishing'
   local queue=tostring(interaction:GetCurrentInteractionQueueId())
   if l.cancelled[who]~=queue then
    local ok,message=inzoi.cli.execute('interaction.cancel entity_id='..who)
    assert(ok,message or 'Could not cancel selected sofa participant interaction');l.cancelled[who]=queue
   end
  else
   local ready,sample=GetUp.ensure(person,l.token)
   if not ready then
    l.getup_ids=l.getup_ids or {};l.getup_ids[who]=true
    if sample and sample.state=='failed'then
     assert(M.release(l.bed,l),'Furniture not loaded during GetUp rollback')
     reply(owner,l.token,l.bed,'busy',sample.failure or'native_getup_failed',l);return
    end
    phase='native_getup_finishing'
   end
  end
 end
 preparing(owner,l,phase)
end
local function allowed_participants(encoded,who)
 local decoded=assert(P.decode(encoded),'Missing sofa participants');local ids=Json.decode(decoded);V.array(ids,64)
 assert(#ids>0,'Missing sofa participants');local allowed={}
 for _,value in ipairs(ids)do
  assert(type(value)=='string'and value:match('^%d+$')and not allowed[value],'Invalid sofa participant')
  allowed[value]=true
 end
 assert(allowed[who],'Furniture owner is not a scene participant');return allowed
end
local function held_pair_error(l)
 local o=object(l.bed);if not o then return 'furniture_unloaded'end
 local s=slot(o);if not s then return 'native_slots_missing'end
 local wanted,states={},{}
 for _,row in ipairs(l.target_slots)do wanted[key(row.component_name,row.slot_name)]=row end
 for _,state in ipairs(s.SlotStateInfos)do
  local k=rowkey(state)
  if wanted[k]then
   if states[k]then return 'native_pair_alias_changed',wanted[k]end
   states[k]=state
  elseif state.OccupyingEntityId and id(state.OccupyingEntityId)==l.owner and reason(state,inzoi.EB1SlotOccupyingReason.Restricted)then
   return 'native_unrecorded_restriction',{component_name=tostring(state.ComponentName),slot_name=tostring(state.SlotName)}
  end
 end
 for _,row in ipairs(l.target_slots)do
  local state=states[key(row.component_name,row.slot_name)]
  if not state then return 'native_pair_alias_missing',row end
  if state.Blocked then return 'native_pair_blocked',row end
  if not state.OccupyingEntityId or id(state.OccupyingEntityId)~=l.owner then return 'native_pair_owner_changed',row end
  if not reason(state,inzoi.EB1SlotOccupyingReason.Restricted)then return 'native_pair_reason_changed',row end
  for _,value in ipairs(state.SlotOccupyingReasons or {})do
   if value~=inzoi.EB1SlotOccupyingReason.None and value~=inzoi.EB1SlotOccupyingReason.Restricted then return 'native_pair_reason_changed',row end
  end
 end
end
local function acknowledge_held(owner,l,why)
 if l.pair_id then
  -- A Lua lease alone cannot prove that the native reservation still exists.
  local lost,row=held_pair_error(l)
  if lost then
   l.releasing=true
   if row then l.component=row.component_name;l.slot=row.slot_name end
   -- Preserve reused/foreign slots. An unrecorded restriction for this owner
   -- retains the lease for the existing fail-closed cleanup retry and log.
   -- Finish our mutation before notifying B1: its callback can start a new
   -- lease for this owner/pair, which this old handler must not release.
   pcall(M.release,l.bed,l)
   reply(owner,l.token,l.bed,'missing',lost,l);return
  end
 end
 reply(owner,l.token,l.bed,'held',why,l)
end
---@param owner FB2Character
function M.message(owner,content)
 local f=P.unpack(content);if not f then return end
 local token,bed,action=f[1],f[2],f[3];local o=object(bed);local who=id(owner:GetEntityId());local l=find(bed,token,who)
 -- A failed native claim is cleanup-only, even if a caller retries before
 -- the outer message handler has finished its rollback.
 if l and l.acquiring and not l.clearing then l.releasing=true end
 local requested=f[5]and f[5]~='none'and {pair_id=f[5]}or nil
 if token=='status'then
  if o and f[4]and f[4]~='none'then
   local profile=profile_for(o,f[4])
   if profile.kind=='sofa.pair'then
    local available,clearable=free_pairs(bed,profile,assert(slot(o),'Furniture has no native slots'))
    reply(owner,token,bed,#available>0 and'free'or'busy',nil,nil,available,clearable);return
   end
  end
  reply(owner,token,bed,o and not o:IsInUse()and not conflicts(bed)and'free'or'busy');return
 end
 if action=='release'then
  local why='already_released'
  if l then if not M.release(bed,l)then return end;why='native_restriction_cleared'
  elseif not M.retired[token]and(f[4]=='held'or(f[4]=='unconfirmed'and f[5]and f[5]~='none'))then
   local recovery
   if f[5]and f[5]~='none'then
    if different_owner_lease(bed,who,token)then reply(owner,token,bed,'release_pending','different_lease_present',requested);return end
    assert(f[6]and f[7],'Missing acknowledged sofa reservation')
    recovery=M.saved_rows({{id=bed,owner=who,pair_id=f[5],slots=Json.decode(P.decode(f[6])),spots=Json.decode(P.decode(f[7]))}},who)[1]
   elseif conflicts(bed)then reply(owner,token,bed,'released','different_lease_present',requested);return end
   if not clear_restriction(bed,owner:GetEntityId(),recovery)then return end;why='cleared_after_lease_lost'
  elseif conflicts(bed)then why='different_lease_present'end
  M.retired[token]=os.time();reply(owner,token,bed,'released',why,l or requested);return
 end
 if action=='heartbeat'then
  if l and not l.releasing then
   l.time=os.time();if l.clearing then advance_pair(owner,l)else acknowledge_held(owner,l,'lease_heartbeat')end
  else reply(owner,token,bed,'missing','lease_missing',requested)end;return
 end
 if action~='acquire'then return end
 if l then
  l.time=os.time()
  if l.clearing and not l.releasing then advance_pair(owner,l)
  elseif l.releasing then reply(owner,token,bed,'busy','lease_already_held',l)
  else acknowledge_held(owner,l,'lease_already_held')end
  return
 end
 local unavailable=M.retired[token]and'retired_session'or not M.hooks and'guards_unavailable'or not o and'furniture_unloaded'
 if unavailable then reply(owner,token,bed,'busy',unavailable,requested);return end
 local profile=profile_for(o,f[4]);local s=assert(slot(o),'Furniture has no native interaction slots')
 local pair_id=profile.kind=='sofa.pair'and f[5]or nil
 if profile.kind=='sofa.pair'then
  local pair,rows,states=target_rows(profile,pair_id,s)
  if conflicts(bed,pair.spots)then reply(owner,token,bed,'busy','held_by_other_scene',requested);return end
  local allowed=allowed_participants(f[6],who)
  if not vacancy(states)and not clearing_occupants(states,allowed)then reply(owner,token,bed,'busy','native_occupied',requested);return end
  assert(not next(owned_restrictions(s,who)),'Furniture owner already has native restrictions')
  local tentative={key=leasekey(bed,pair_id),bed=bed,pair_id=pair_id,spots=pair.spots,slots={},target_slots=rows,
   token=token,owner=who,time=os.time(),acquired=false,acquiring=true,clearing=true,profile=profile,allowed=allowed}
  M.leases[tentative.key]=tentative
  advance_pair(owner,tentative);return
 end
 if conflicts(bed)or o:IsInUse()then reply(owner,token,bed,'busy','native_occupied');return end
 local tentative={key=bed,bed=bed,token=token,owner=who,time=os.time(),acquired=false,acquiring=true};M.leases[bed]=tentative
 for _,state in ipairs(s.SlotStateInfos)do
  local name=tostring(state.ComponentName):lower()
  if not name:find('youth',1,true)and not name:find('reform',1,true)and not name:find('fx',1,true)and not state.Blocked then
   local param=inzoi.FB2TargetSlotParam();param.ComponentName=state.ComponentName;param.SlotName=state.SlotName
   param.OccupyEntityId=owner:GetEntityId();param.OccupyingReason=inzoi.EB1SlotOccupyingReason.Restricted
   param.bCheckCanMove=false;param.bCheckOwnershipSlot=false;tentative.acquired=true
   if s:TryOccupySlot(inzoi.EB1SlotType.Interaction,param)then
    tentative.component=tostring(state.ComponentName):gsub('[^%w_.:+%-]','_');tentative.slot=tostring(state.SlotName):gsub('[^%w_.:+%-]','_')
    tentative.acquiring=nil;reply(owner,token,bed,'held','native_slot_reserved',tentative);return
   end
   tentative.acquired=false
  end
 end
 M.leases[bed]=nil;reply(owner,token,bed,'busy','no_slot_available')
end
function M.tick()
 for _,l in pairs(M.leases)do if l.releasing or os.time()-l.time>8 or not object(l.bed)then
  local ok,err=pcall(M.release,l.bed,l)
  if not ok and(l.release_error~=tostring(err)or os.time()-(l.error_reported_at or 0)>=5)then
   l.release_error=tostring(err);l.error_reported_at=os.time()
   print('[SceneZOI] Furniture release will retry: object='..l.bed..' owner='..l.owner..' pair='..(l.pair_id or'none')..' '..tostring(err))
   -- Keep a failed ownership proof visible in scenezoi_runtime too, without
   -- turning a native retry into a per-frame log flood.
   pcall(function()
    local recipient=inzoi.getB2Manager('FB2EntityManager'):FindCharacter(entity(l.owner))
    if recipient then reply(recipient,l.token,l.bed,'release_pending',tostring(err):find('unrecorded native restriction',1,true)and'native_unrecorded_restriction'or'native_restore_error',l)end
   end)
  end
 end end
 for token,time in pairs(M.retired)do if os.time()-time>60 then M.retired[token]=nil end end
end
---@param owner FB2Character
function M.release_owner(owner)
 local who=id(owner:GetEntityId());for _,l in pairs(M.leases)do if l.owner==who then M.release(l.bed,l)end end
end
---@param owner FB2Character
function M.restore_saved(owner,rows,token)
 local errors={};local who=id(owner:GetEntityId())
 for _,row in ipairs(M.saved_rows(rows,who))do
  local bed=type(row)=='table'and row.id or row
  local ok,err=pcall(function()
   local l=find(bed,token,who)
   if l then assert(M.release(bed,l),'Furniture not loaded')
   else
    local recovery=type(row)=='table'and row or nil
    assert(not different_owner_lease(bed,who,token),'Furniture owner is held by a different live lease')
    if not recovery then assert(not conflicts(bed),'Furniture held by another lease')end
    assert(clear_restriction(bed,owner:GetEntityId(),recovery),'Furniture not loaded')
   end
  end)
  if not ok then errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.clear()for _,l in pairs(M.leases)do pcall(M.release,l.bed,l)end end
return M

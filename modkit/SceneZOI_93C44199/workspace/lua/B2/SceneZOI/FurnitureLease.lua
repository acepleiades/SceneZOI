-- Whole-surface reservations; native sleeping-side ownership remains untouched.
local P=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local M={leases={},retired={},hooks=false}
local function id(v)return tostring(v.Value)end
local function entity(v)local e=inzoi.FB1EntityId();e.Value=tonumber(v);return e end
local function object(v)return inzoi.getB2Manager('FB2EntityManager'):FindGameObject(entity(v))end
local function slot(o)return o:GetComponent(inzoi.EB2ComponentType.Slot)end
local function reply(owner,token,bed,code,reason,lease)
 local component=lease and lease.component
 local name=lease and lease.slot
 local packet=reason and P.pack(token,bed,code,reason,component and component~='' and component or 'none',
  name and name~='' and name or 'none')or P.pack(token,bed,code)
 inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.FurnitureReply',packet)
end
function M.blocked(component)local l=M.leases[id(component:GetOwnerEntityId())];return l~=nil and not l.acquiring end
local function clear_restriction(bed,owner)
 local o=object(bed)
 if not o then return false end
 slot(o):RemoveOccupyingReasonByEntityId(owner,inzoi.EB1SlotOccupyingReason.Restricted)
 return true
end
function M.release(bed,l)
 l.releasing=true
 if l.acquired and not clear_restriction(bed,entity(l.owner))then return false end
 M.leases[bed]=nil;M.retired[l.token]=os.time()
 return true
end
function M.message(owner,content)
 local f=P.unpack(content);if not f then return end
 local token,bed,action=f[1],f[2],f[3];local o=object(bed);local l=M.leases[bed];local who=id(owner:GetEntityId())
 if token=='status'then reply(owner,token,bed,o and not o:IsInUse()and not l and 'free'or'busy');return end
 if action=='release'then
  local reason='already_released'
  if l and l.token==token and l.owner==who then
   if not M.release(bed,l)then return end
   reason='native_restriction_cleared'
  elseif not l and not M.retired[token]and f[4]=='held'then
   -- B2 may have reloaded since B1 received the acquisition acknowledgement.
   if not clear_restriction(bed,owner:GetEntityId())then return end
   reason='cleared_after_lease_lost'
  elseif l then
   reason='different_lease_present'
  end
  M.retired[token]=os.time();reply(owner,token,bed,'released',reason,l);return
 end
 if action=='heartbeat'then
  if l and l.token==token and l.owner==who and not l.releasing then
   l.time=os.time();reply(owner,token,bed,'held')
  else reply(owner,token,bed,'missing','lease_missing')end
  return
 end
 if action~='acquire'then return end
 if l then
  local same=l.token==token and l.owner==who
  reply(owner,token,bed,same and 'held'or'busy',same and 'lease_already_held' or 'held_by_other_scene',l);return
 end
 local unavailable=M.retired[token]and 'retired_session' or not M.hooks and 'guards_unavailable'
  or not o and 'furniture_unloaded' or o:IsInUse() and 'native_occupied'
 if unavailable then reply(owner,token,bed,'busy',unavailable);return end
 local profile=require('SceneZOI.FurnitureData').profile(Json.decode(P.decode(f[4])))
 local matched=false;for _,name in ipairs(profile.objects)do if name==tostring(o.ObjectTableId)then matched=true end end
 assert(matched,'Furniture profile does not match native object')
 local s=slot(o);assert(s,'Furniture has no native interaction slots')
 -- Reserve an available adult slot with a temporary reason so native IsInUse also sees the lease.
 local acquired=false
 local tentative={token=token,owner=who,time=os.time(),acquired=false,acquiring=true}
 M.leases[bed]=tentative
 for _,state in ipairs(s.SlotStateInfos)do
  local name=tostring(state.ComponentName):lower()
  if not name:find('youth',1,true)and not name:find('reform',1,true)and not name:find('fx',1,true)and not state.Blocked then
   local param=inzoi.FB2TargetSlotParam();param.ComponentName=state.ComponentName;param.SlotName=state.SlotName
   param.OccupyEntityId=owner:GetEntityId();param.OccupyingReason=inzoi.EB1SlotOccupyingReason.Restricted
   param.bCheckCanMove=false;param.bCheckOwnershipSlot=false
   tentative.acquired=true
   if s:TryOccupySlot(inzoi.EB1SlotType.Interaction,param)then
    tentative.component=tostring(state.ComponentName):gsub('[^%w_.:+%-]','_')
    tentative.slot=tostring(state.SlotName):gsub('[^%w_.:+%-]','_')
    acquired=true;break
   end
   tentative.acquired=false
  end
 end
 if not acquired then M.leases[bed]=nil;reply(owner,token,bed,'busy','no_slot_available');return end
 -- Once a native slot is held, guards exclude other slots across this whole surface.
 tentative.acquiring=nil;tentative.time=os.time()
 M.leases[bed]=tentative
 reply(owner,token,bed,'held','native_slot_reserved',tentative)
end
function M.tick()
 for bed,l in pairs(M.leases)do if l.releasing or os.time()-l.time>8 or not object(bed)then
  local ok,err=pcall(M.release,bed,l);if not ok then print('[SceneZOI] Furniture release will retry: '..tostring(err))end
 end end
 for token,time in pairs(M.retired)do if os.time()-time>60 then M.retired[token]=nil end end
end
function M.release_owner(owner)
 local who=id(owner:GetEntityId())
 for bed,l in pairs(M.leases)do if l.owner==who then M.release(bed,l)end end
end
function M.restore_saved(owner,beds,token)
 local errors={}
 for _,bed in ipairs(beds)do
  local ok,err=pcall(function()
   local l=M.leases[bed]
   if l then
    assert(l.token==token and l.owner==id(owner:GetEntityId()),'Furniture held by another lease')
    assert(M.release(bed,l),'Furniture not loaded')
   else
    assert(clear_restriction(bed,owner:GetEntityId()),'Furniture not loaded')
   end
  end)
  if not ok then errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.clear()
 for bed,l in pairs(M.leases)do pcall(M.release,bed,l)end
end
return M

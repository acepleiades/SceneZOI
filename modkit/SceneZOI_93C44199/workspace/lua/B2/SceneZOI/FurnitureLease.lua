-- Whole-surface reservations; native sleeping-side ownership remains untouched.
local P=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local M={leases={},retired={},hooks=false}
local function id(v)return tostring(v.Value)end
local function entity(v)local e=inzoi.FB1EntityId();e.Value=tonumber(v);return e end
local function object(v)return inzoi.getB2Manager('FB2EntityManager'):FindGameObject(entity(v))end
local function slot(o)return o:GetComponent(inzoi.EB2ComponentType.Slot)end
local function reply(owner,token,bed,code)inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.FurnitureReply',P.pack(token,bed,code))end
function M.blocked(component)local l=M.leases[id(component:GetOwnerEntityId())];return l~=nil and not l.acquiring end
function M.release(bed,l)
 if l.acquired then
  local o=object(bed)
  if o then slot(o):RemoveOccupyingReasonByEntityId(entity(l.owner),inzoi.EB1SlotOccupyingReason.Restricted)end
 end
 M.leases[bed]=nil;M.retired[l.token]=os.time()
end
function M.message(owner,content)
 local f=P.unpack(content);if not f then return end
 local token,bed,action=f[1],f[2],f[3];local o=object(bed);local l=M.leases[bed];local who=id(owner:GetEntityId())
 if token=='status'then reply(owner,token,bed,o and not o:IsInUse()and not l and 'free'or'busy');return end
 if action=='release'then
  if l and l.token==token and l.owner==who then M.release(bed,l)end
  M.retired[token]=os.time();reply(owner,token,bed,'released');return
 end
 if action=='heartbeat'then if l and l.token==token and l.owner==who then l.time=os.time();reply(owner,token,bed,'held')end;return end
 if action~='acquire'then return end
 if l then reply(owner,token,bed,l.token==token and l.owner==who and 'held'or'busy');return end
 if M.retired[token]or not M.hooks or not o or o:IsInUse()then reply(owner,token,bed,'busy');return end
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
   if s:TryOccupySlot(inzoi.EB1SlotType.Interaction,param)then acquired=true;break end
   tentative.acquired=false
  end
 end
 if not acquired then M.leases[bed]=nil;reply(owner,token,bed,'busy');return end
 -- Once a native slot is held, guards exclude other slots across this whole surface.
 M.leases[bed]={token=token,owner=who,time=os.time(),acquired=true}
 reply(owner,token,bed,'held')
end
function M.tick()
 for bed,l in pairs(M.leases)do if os.time()-l.time>8 or not object(bed)then
  local ok,err=pcall(M.release,bed,l);if not ok then print('[SceneZOI] Furniture release will retry: '..tostring(err))end
 end end
 for token,time in pairs(M.retired)do if os.time()-time>60 then M.retired[token]=nil end end
end
function M.release_owner(owner)
 local who=id(owner:GetEntityId())
 for bed,l in pairs(M.leases)do if l.owner==who then M.release(bed,l)end end
end
function M.restore_saved(owner,beds)
 local errors={}
 for _,bed in ipairs(beds)do
  local ok,err=pcall(function()
   local o=object(bed)
   if o then slot(o):RemoveOccupyingReasonByEntityId(owner:GetEntityId(),inzoi.EB1SlotOccupyingReason.Restricted)end
  end)
  if not ok then errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.clear()
 for bed,l in pairs(M.leases)do pcall(M.release,bed,l)end
end
return M

package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local Protocol=require('SceneZOI.Protocol');local Json=require('SceneZOI.Json')
local now=100;os.time=function()return now end
local replies,held,fail,occupied,throws={},false,false,false,false
local states={{ComponentName='AdultLeft',SlotName='Sleep',Blocked=false,SlotOccupyingReasons={}},{ComponentName='AdultRight',SlotName='Sleep',Blocked=false,SlotOccupyingReasons={}}}
local s={SlotStateInfos=states,GetOwnerEntityId=function()return {Value=50}end}
function s:TryOccupySlot(kind,p)held=true;if throws then error('partial native mutation')end;return true end
function s:RemoveOccupyingReasonByEntityId(person,reason)assert(person.Value==1 and reason==8);if fail then error('retry')end;held=false end
local o={ObjectTableId='ModelA',IsInUse=function()return occupied or held end,GetComponent=function()return s end}
local owner={GetEntityId=function()return {Value=1}end};local other={GetEntityId=function()return {Value=2}end}
inzoi={FB1EntityId=function()return {}end,FB2TargetSlotParam=function()return {}end,EB2ComponentType={Slot=14},EB1SlotOccupyingReason={Restricted=8},EB1SlotType={Interaction=1},getB2Manager=function()return {FindGameObject=function()return o end}end,message={send_to_client=function(_,_,p)replies[#replies+1]=Protocol.unpack(p)end}}
local M=require('SceneZOI.FurnitureLease');M.hooks=true
local profile=Protocol.encode(Json.encode({schema_version=1,id='author.bed',kind='bed.single',objects={'ModelA'},surface_height_cm=5}))
local function send(token,action,who)M.message(who or owner,Protocol.pack(token,'50',action,profile));return replies[#replies][3]end
occupied=true;assert(send('busy','acquire')=='busy'and not held);occupied=false
assert(send('first','acquire')=='held'and held and M.blocked(s));assert(send('other','acquire',other)=='busy')
assert(send('first','acquire')=='held','Duplicate acquisition is idempotent')
assert(send('wrong','release',other)=='released'and held,'Wrong token/owner cannot release another scene')
fail=true;assert(not pcall(send,'first','release')and held and M.blocked(s));fail=false
assert(send('first','release')=='released'and not held and not M.blocked(s));assert(send('first','acquire')=='busy','Late acquisition cannot resurrect a released token')
assert(send('next','acquire')=='held');now=109;M.tick();assert(not held and not M.blocked(s),'Lease expires without a UI heartbeat, including paused native time')
throws=true;assert(not pcall(send,'partial','acquire')and M.leases['50'].acquired and held);throws=false
M.release('50',M.leases['50']);assert(not held)
assert(send('after','acquire')=='held');M.release_owner(owner);assert(not held);assert(send('clear','acquire')=='held');M.clear();assert(not held)
print('Furniture lease passed: occupied rejection, exclusive whole-bed use, duplicate/stale/foreign requests, partial acquisition ownership, retryable release, watchdog and repeat use.')

-- A loaded native reservation has no Lua lease. Restore only its saved owner/reason.
held=true;assert(not next(M.leases));fail=true
assert(not pcall(M.restore_saved,owner,{'50'})and held,'A failed load-time removal must remain retryable')
fail=false;M.restore_saved(owner,{'50'});assert(not held)
M.restore_saved(owner,{'50'});assert(not held,'Already-removed native occupancy is idempotent')
local manager=inzoi.getB2Manager
inzoi.getB2Manager=function()return {FindGameObject=function()return nil end}end
assert(pcall(M.restore_saved,owner,{'50'}),'Deleted furniture must not block loaded participant recovery')
inzoi.getB2Manager=manager
print('Saved furniture passed: no Lua lease required, exact native owner/reason, retry, duplicate and deleted-object recovery.')

-- A reservation whose record was lost (no lease, no saved list): released once it has been stale for STALE_SEC.
held=true;M.leases={};states[1].SlotOccupyingReasons={8};states[1].OccupyingEntityId={Value=1}
assert(send('status','look')=='busy'and held,'First sight: still busy')
now=now+M.STALE_SEC;assert(send('status','look')=='free'and not held,'Stale reservation released')
assert(send('mine','acquire')=='held'and held);states[1].SlotOccupyingReasons={8}
now=now+M.STALE_SEC*3;send('status','look');assert(held,'A live lease is never touched')
print('Stale reservations passed: released after a while, a live lease kept.')

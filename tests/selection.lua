package.path="modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;"..package.path
local replies,opened={},0
local now=100;os.time=function()return now end
local groups,people,removes,breaks={},{},{},{}
local fail,move,break_fail=false,false,false
local function person(n)
 if not people[n] then people[n]={GetEntityId=function()return {Value=n}end,GetZoiGroupId=function()return {Value=groups[n] or 0}end}end
 return people[n]
end
local owner=person(1);person(2);person(3)
local manager={RequestOpenZoiGroupCreateWidget=function()opened=opened+1 end,
 RemoveZoiGroupMember=function(_,g,c)
  local n=c:GetEntityId().Value;removes[#removes+1]=n
  if move then groups[n]=99;return end
  if not fail then groups[n]=0 end
 end,
 BreakZoiGroup=function(_,g)
  breaks[#breaks+1]=g.Value
  if not break_fail then for n,v in pairs(groups)do if v==g.Value then groups[n]=0 end end end
 end}
inzoi={EB1ZoiGroupEditReason={CreateGroup=1},EB1ZoiGroupLeaveReason={UserSelf=2},FB1ZoiGroupId=function()return {Value=0}end,
 FB1EntityId=function()return {Value=0}end,
 getB2Manager=function(name)
  if name=="FB2EntityManager"then return {FindCharacter=function(_,e)return people[e.Value]end}end
  assert(name=="FB2ZoiGroupManager");return manager
 end,
 cli={execute=function()return true,"",'{"entity_id":1}'end},
 message={send_to_client=function(_,_,packet)replies[#replies+1]=packet end}}
local D=require("SceneZOIStarter.GroupDeparture")
D.leave(owner);assert(#removes==0 and #breaks==0)
groups[1]=7;groups[3]=7;D.leave(owner);assert(groups[1]==0 and groups[3]==7 and #breaks==0)
groups[1]=7;fail=true;D.leave(owner);assert(groups[1]==0 and groups[3]==0 and #breaks==1)
groups[1]=7;move=true;assert(not pcall(D.leave,owner));assert(groups[1]==99 and #breaks==1)
move=false;groups[1]=7;break_fail=true;assert(not pcall(D.leave,owner));assert(groups[1]==7)
fail=false;break_fail=false;groups[1]=0;groups[3]=0
local S=require("SceneZOIStarter.Selection")
local function open(token)S.open(owner,token);S.tick();S.tick()end
local function closed(token)S.message(owner,{token,"closed"});for i=1,3 do S.tick()end end
assert(not pcall(S.open,owner,"unbound"))
S.bind();open("two");assert(opened==1)
S.create({Value=1},{person(1),person(2)});closed("two")
assert(replies[#replies]=="SZ2|two|selected|1+2")
open("npcs");S.create({Value=1},{person(3),person(2)});closed("npcs");assert(replies[#replies]=="SZ2|npcs|selected|3+2","Unselected: only the others, in the order they were picked")
open("one_npc");S.create({Value=1},{person(2)});S.message(owner,{"one_npc","solo"});closed("one_npc");assert(replies[#replies]=="SZ2|one_npc|selected|2","A real selection wins over the solo guess")
open("solo");S.message(owner,{"solo","solo"});closed("solo")
assert(replies[#replies]=="SZ2|solo|selected|1","Start Solo needs nobody else picked")
open("three");S.create({Value=1},{person(1),person(3),person(2)});closed("three")
assert(replies[#replies]=="SZ2|three|selected|1+2+3")
groups[1]=7;groups[2]=7;groups[3]=7
open("grouped");assert(groups[1]==0 and groups[2]==7 and groups[3]==7)
S.create({Value=1},{person(1),person(2)});assert(groups[2]==7,"NPC departure waits for picker closure")
closed("grouped");assert(groups[2]==0 and groups[3]==7 and replies[#replies]=="SZ2|grouped|selected|1+2")
groups[1]=7;open("cancel");now=now+7;S.message(person(1),{"cancel","heartbeat"});now=now+7;S.tick()
closed("cancel");assert(groups[1]==0 and groups[3]==7 and replies[#replies]=="SZ2|cancel|cancelled|none")
open("missing");S.create({Value=1},{person(2)});people[2]=nil;closed("missing")
assert(replies[#replies]:find("|error|",1,true) and groups[3]==7,"Validate whole roster before removing NPCs")
person(2)
open("late");now=now+9;S.tick();S.message(owner,{"late","solo"});closed("late");assert(replies[#replies]=="SZ2|late|cancelled|none","An expired picker never starts a solo scene")
open("timeout");now=now+9;S.tick();assert(replies[#replies]:find("|error|",1,true))
assert(S.create({Value=1},{person(3)}));closed("timeout")
assert(replies[#replies]=="SZ2|timeout|cancelled|none" and groups[3]==7)
local native_calls=0
function manager:CreateZoiGroup()native_calls=native_calls+1;return {Value=42}end
local hook=require("Systems.B2ZoiGroupManager")
assert(hook.Override_CreateZoiGroup(manager,1,{Value=1},{person(2)},true).Value==42 and native_calls==1)
open("hook");assert(hook.Override_CreateZoiGroup(manager,1,{Value=1},{person(2)},true).Value==0 and native_calls==1)
S.clear()
print("Selection passed: leave-first, verified fallback, unrelated/new groups preserved, deferred NPC departure, roster validation, cancellation, expiry, no native scene group.")

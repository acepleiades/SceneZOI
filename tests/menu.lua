package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_demo"
local controlled=1
local function entry(key,target)return {Data={InteractionBagId=key,TargetEntityId={Value=target}},visibility=0,
 GetVisibility=function(self)return self.visibility end,SetVisibility=function(self,v)self.visibility=v end}end
local ours=entry(marker,1);local npc=entry(marker,2);local other_mod=entry("_UIMod_Other~demo",2);local native=entry("Talk",2)
local object_rows,talk_rows={ours,native},{npc,other_mod}
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=controlled}end}end},
 UWidgetBlueprintLibrary={GetAllWidgetsOfClass=function(_,_,kind)return kind==1 and object_rows or talk_rows end}}
inzoi={UB1ObjectInteractionListEntry={StaticClass=function()return 1 end},UB1TalkInteractionListEntry={StaticClass=function()return 2 end}}
local M=require("SceneZOIStarter.Menu")
assert(M.tick({a={}},false));assert(ours.visibility==1 and npc.visibility==1)
assert(M.tick({a={}},true));assert(ours.visibility==0 and npc.visibility==1 and native.visibility==0 and other_mod.visibility==0)
controlled=2;M.tick({a={}},true);assert(ours.visibility==1 and npc.visibility==0,"Recycled widgets must follow current control")
-- Native list entries are pooled. Rebinding Data does not reset Slate visibility.
ours.Data={InteractionBagId='Object_Select_MyBed02',TargetEntityId={Value=30}}
M.tick({a={}},true)
assert(ours.visibility==0,'Recycled Assign Bed row must not inherit the SceneZOI collapse')
native.visibility=1
npc.visibility=3;npc.Data.TargetEntityId.Value=1
M.tick({a={}},true);assert(npc.visibility==1)
npc.Data={InteractionBagId='Native_Talk',TargetEntityId={Value=2}}
M.tick({a={}},true);assert(npc.visibility==3 and native.visibility==1,'Restore exact saved visibility only on rows we changed')
-- A native reassignment that already reset visibility must win.
npc.Data.InteractionBagId=marker;npc.Data.TargetEntityId.Value=1
M.tick({a={}},true);npc.Data.InteractionBagId='Other_Talk';npc.visibility=2
M.tick({a={}},true);assert(npc.visibility==2,'Do not overwrite a new native visibility value')
local furniture=entry('_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_furniture',30)
package.loaded['SceneZOI.Furniture']={available=function()return nil end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {nodes={}}end}
object_rows={furniture,native};M.tick({a={}},true);assert(furniture.visibility==1)
object_rows={native};M.tick({a={}},true);assert(furniture.visibility==0,'Detached pooled entries must be released before reuse')
object_rows={furniture,native};M.tick({a={}},true);assert(furniture.visibility==1)
M.stop();assert(furniture.visibility==0 and native.visibility==1,'Unload restores owned mutations without changing other rows')
M.tick({},true)
print("Native menu passed: control/readiness, reused rows, exact native visibility, detached entries and unload cleanup.")

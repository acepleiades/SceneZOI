package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_demo"
local controlled=1
local function entry(key,target)return {Data={InteractionBagId=key,TargetEntityId={Value=target}},visibility=0,SetVisibility=function(self,v)self.visibility=v end}end
local ours=entry(marker,1);local npc=entry(marker,2);local other_mod=entry("_UIMod_Other~demo",2);local native=entry("Talk",2)
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=controlled}end}end},
 UWidgetBlueprintLibrary={GetAllWidgetsOfClass=function(_,_,kind)return kind==1 and {ours,native} or {npc,other_mod} end}}
inzoi={UB1ObjectInteractionListEntry={StaticClass=function()return 1 end},UB1TalkInteractionListEntry={StaticClass=function()return 2 end}}
local M=require("SceneZOIStarter.Menu")
assert(M.tick({a={}},false));assert(ours.visibility==1 and npc.visibility==1)
assert(M.tick({a={}},true));assert(ours.visibility==0 and npc.visibility==1 and native.visibility==0 and other_mod.visibility==0)
controlled=2;M.tick({a={}},true);assert(ours.visibility==1 and npc.visibility==0,"Recycled widgets must follow current control")
M.tick({},true)
print("Native menu passed: rendered object/talk entries, cold startup readiness, control changes, and native/other-mod rows preserved.")

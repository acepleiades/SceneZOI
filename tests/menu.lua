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
local debug_start=false
package.loaded['SceneZOI.Settings']={debug_start_enabled=function()return debug_start end}
package.loaded['SceneZOI.Localization']={text=function(key)return key end}
ours.SizeBox_Tag=entry('MOD',1)
ours.BW_Image_Modkit=entry('ModKit',1);ours.BW_Image_Modkit.visibility=1
npc.BW_SizeBox_Tag=entry('MOD',1)
npc.BW_Image_Modkit=entry('ModKit',1);npc.BW_Image_Modkit.visibility=1
ours.BW_Text_Content={SetText=function(_,label)ours.label=label end}
local M=require("SceneZOIStarter.Menu")
assert(M.tick({a={}},false));assert(ours.visibility==1 and npc.visibility==1)
assert(M.tick({a={}},true));assert(ours.visibility==0 and npc.visibility==1 and native.visibility==0 and other_mod.visibility==0)
assert(ours.label=='Solo SceneZOI Session' and ours.SizeBox_Tag.visibility==1 and ours.BW_Image_Modkit.visibility==4)
debug_start=true;M.tick({a={}},true)
assert(ours.label=='(Debug) SceneZOI manual start' and ours.SizeBox_Tag.visibility==1 and ours.BW_Image_Modkit.visibility==4)
debug_start=false;M.tick({a={}},true);assert(ours.SizeBox_Tag.visibility==1)
controlled=2;M.tick({a={}},true);assert(ours.visibility==1 and npc.visibility==0,"Recycled widgets must follow current control")
assert(npc.BW_SizeBox_Tag.visibility==1 and npc.BW_Image_Modkit.visibility==4)
-- Native list entries are pooled. Rebinding Data does not reset Slate visibility.
ours.Data={InteractionBagId='Object_Select_MyBed02',TargetEntityId={Value=30}}
M.tick({a={}},true)
assert(ours.visibility==0 and ours.SizeBox_Tag.visibility==0 and ours.BW_Image_Modkit.visibility==1,
    'Recycled native rows restore visibility, tags and ModKit icons')
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
package.loaded['SceneZOI.Furniture']={pickable=function()return nil end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {nodes={}}end}
object_rows={furniture,native};M.tick({a={}},true);assert(furniture.visibility==1)
object_rows={native};M.tick({a={}},true);assert(furniture.visibility==0,'Detached pooled entries must be released before reuse')
object_rows={furniture,native};M.tick({a={}},true);assert(furniture.visibility==1)
local future=entry('_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_furniture',31)
package.loaded['SceneZOI.Furniture']={pickable=function(id)return id=='31'and 'future_profile' or nil end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {nodes={future={starting_hub=true,furniture='future_profile'}}}end}
package.loaded['SceneZOI.FurnitureData']={compatible=function(node,profile)return node.furniture==profile end}
object_rows={furniture,future,native};M.tick({a={}},true);assert(furniture.visibility==1 and future.visibility==1)
debug_start=true;M.tick({a={}},true);assert(furniture.visibility==1 and future.visibility==0,'Debug mode supports any available compatible profile')
debug_start=false;M.tick({a={}},true);assert(future.visibility==1,'Turning debug off hides future furniture profiles again')
M.stop();assert(furniture.visibility==0 and future.visibility==0 and native.visibility==1,'Unload restores owned mutations without changing other rows')
M.tick({},true)

-- Add-ons opt in with their own object trigger and use the framework's profile.
local addonMarker = '_UIMod_MyGameplay_12345678/furniture~scenezoi_furniture'
local queen, single, sofa = entry(addonMarker, 40), entry(addonMarker, 41), entry(addonMarker, 42)
sofa.SizeBox_Tag=entry('MOD',1)
sofa.BW_Image_Modkit=entry('ModKit',1);sofa.BW_Image_Modkit.visibility=2
local chair, unknown = entry(addonMarker, 43), entry(addonMarker, 44)
local otherTrigger = entry('_UIMod_MyGameplay_12345678/furniture~scenezoi_furniture_extra', 43)
local nativeSameSuffix = entry('Native~scenezoi_furniture', 43)
local supportedKinds = {['40'] = 'bed.queen', ['41'] = 'bed.single', ['42'] = 'sofa.pair', ['43'] = 'chair'}
package.loaded['SceneZOI.Furniture'] = {
    tick = function() end,
    pickable = function() return nil end,
    profile = function(id)
        local kind = supportedKinds[id]
        if kind then return {kind = kind} end
    end,
}
object_rows = {queen, single, sofa, chair, unknown, otherTrigger, nativeSameSuffix, future}
local actors = {['2'] = {}}
assert(M.tick(actors, false))
assert(queen.visibility == 0 and single.visibility == 0 and sofa.visibility == 0,
    'Beds and native sofas stay visible without the debug setting, launcher readiness or available seats')
assert(sofa.SizeBox_Tag.visibility==1 and sofa.BW_Image_Modkit.visibility==4, 'Opted-in entries use the left ModKit icon')
assert(chair.visibility == 1 and unknown.visibility == 1 and future.visibility == 1,
    'Generic triggers hide unsupported furniture immediately and the debug entry still has its own conditions')
assert(otherTrigger.visibility == 0 and nativeSameSuffix.visibility == 0, 'Only opted-in UI Mod rows are filtered')

controlled = 1
assert(M.tick(actors, false))
assert(sofa.visibility == 1, 'Furniture entry is hidden until the new controlled Zoi is loaded')
actors['1'] = {}
assert(M.tick(actors, false))
assert(sofa.visibility == 0, 'Furniture entry is restored once the controlled Zoi is loaded')

chair.Data.InteractionBagId = 'Native_Sit'
unknown.Data.TargetEntityId.Value = 42
assert(M.tick(actors, false))
assert(chair.visibility == 0 and unknown.visibility == 0, 'Pooled menu rows restore when reused by a native entry or supported target')
unknown.Data.TargetEntityId.Value = 44
assert(M.tick(actors, false) and unknown.visibility == 1)
M.stop()
assert(unknown.visibility == 0, 'Unload restores an add-on row hidden by the framework')
assert(sofa.SizeBox_Tag.visibility==0 and sofa.BW_Image_Modkit.visibility==2, 'Unload restores the exact native badge and icon visibility')

print("Native menu passed: control/readiness, add-on furniture, reused rows, exact native visibility, detached entries and unload cleanup.")

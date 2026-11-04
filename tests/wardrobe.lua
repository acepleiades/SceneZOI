package.path="modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;"..package.path
local C=assert(loadfile("tests/support/containers.lua"))()
inzoi={EB2ComponentType={Appearance=2},EB1ChangeOutfitReason={Script=2},FB1StyleSetting=C.style,
    FB1GarmentDescription=function() return {} end,FB1AccessoryDescription=function() return {} end,
    FB1PrintedAccessoryDescription=function() return {PrintedAccessoryData=C.map()} end}
local source=C.style()
source.Outfit.Garments:Add("Top",{GarmentId="modded_shirt",MeshId="mesh",CustomGarmentName="My shirt",VectorParameters={Tint="red"}})
source.Outfit.Garments:Add("Hat",{GarmentId="hat",MeshId="hat_mesh"})
source.Outfit.Accessories:Add("Bag",{AccessoryId="hand_bag",AccessoryMeshId="bag_mesh",AccessoryTransformData={hand_r={scale=1.5}},VectorParameters={Tint="blue"}})
source.Outfit.PrintedAccessories:Add({PrintedAccessoryName="canvas",bHasUnlockedItems=true,PrintedAccessoryData=C.map({
    hand_l={PrintedAccessoryId="canvas_bag",SaveData={scale=.8}},head={PrintedAccessoryId="canvas_hat",SaveData={scale=1.2}}})})
local appearance={active="None",refreshes=0}
function appearance:GetAppearanceSetting() return {FinalStyle=source} end
function appearance:GetActiveCostumeIdByReason() return self.active end
function appearance:EmplaceActiveOutfit(style) self.active="SceneZOI_Demo_Outfit";self.layer=style end
function appearance:RemoveCostumeByCostumeId() self.active="None";self.layer=nil end
function appearance:RefreshAppearance() self.refreshes=self.refreshes+1 end
local owner={GetComponent=function() return appearance end,GetFirstName=function() return "Zoë" end,GetLastName=function() return "Jang" end}
local W=require("SceneZOI.Wardrobe")
local Outfit=require("SceneZOI.Outfit")
local P=require("SceneZOI.Protocol")
local lease={token="test",revision=1}
W.capture(owner,lease)
local original=lease.wardrobe
W.capture(owner,lease);assert(lease.wardrobe==original)
local items={};for _,item in ipairs(original.items) do items[item.key]=item end
assert(#original.items==5 and items.Top and items.Bag and items["1/hand_l"] and items["1/head"])
assert(P.decode(P.encode("Zoë <Bag>"))=="Zoë <Bag>")
source.Outfit.Garments.Top.VectorParameters.Tint="changed_after_capture"
Outfit.apply(owner,lease,{"Top"})
assert(not W.enabled(lease,items.Top) and W.enabled(lease,items.Hat) and W.enabled(lease,items.Bag))
assert(next(appearance.layer.Outfit.Accessories:ToTable())==nil,"Automatic undressing touched accessories")
assert(W.toggle(lease,items.Top.id,true));Outfit.apply(owner,lease,{})
assert(appearance.layer.Outfit.Garments.Top.GarmentId=="modded_shirt" and appearance.layer.Outfit.Garments.Top.VectorParameters.Tint=="red")
assert(W.toggle(lease,items.Bag.id,false));Outfit.apply(owner,lease,{})
assert(appearance.layer.Outfit.Accessories.Bag.AccessoryId=="None")
local refreshes=appearance.refreshes
Outfit.apply(owner,lease,{});assert(appearance.refreshes==refreshes,"Hub navigation rebuilt an unchanged manual outfit")
Outfit.apply(owner,lease,{"Top"})
assert(not W.enabled(lease,items.Top) and not W.enabled(lease,items.Bag),"A node must apply its own removal and retain the manual accessory choice")
assert(W.toggle(lease,items.Bag.id,true));Outfit.apply(owner,lease,{})
assert(appearance.layer.Outfit.Accessories.Bag.AccessoryTransformData.hand_r.scale==1.5 and appearance.layer.Outfit.Accessories.Bag.VectorParameters.Tint=="blue")
assert(W.toggle(lease,items["1/hand_l"].id,false));Outfit.apply(owner,lease,{})
local printed=appearance.layer.Outfit.PrintedAccessories[1]
assert(not printed.PrintedAccessoryData:Find("hand_l") and printed.PrintedAccessoryData:Find("head").SaveData.scale==1.2)
assert(W.toggle(lease,items["1/hand_l"].id,true));Outfit.apply(owner,lease,{})
assert(appearance.layer.Outfit.PrintedAccessories[1].PrintedAccessoryData:Find("hand_l").SaveData.scale==.8)
local version=original.version
assert(not W.toggle(lease,"invented_piece",false) and original.version==version)
assert(W.toggle(lease,items.Bag.id,true) and original.version==version,"A duplicate absolute choice must not rebuild")
local inventory=P.unpack(W.inventory(owner,lease))
assert(P.decode(inventory[6])=="Zoë Jang" and inventory[7]:find(items.Bag.id,1,true))
Outfit.restore(owner,lease);assert(not lease.outfit and appearance.active=="None" and not lease.removed_slots)
assert(source.Outfit.Accessories.Bag.VectorParameters.Tint=="blue" and source.Outfit.PrintedAccessories[1].PrintedAccessoryData:Find("hand_l"))
print("Wardrobe checks passed: captured pieces, colors/transforms, ordinary and per-bone printed accessories, exact re-equip, automatic/manual precedence, no-op retries, inert labels and final layer restoration.")
source.Outfit.Garments.InnerTop={GarmentId="W_InnTop03_001"}
local result=P.unpack(W.inventory(owner,lease))
assert(result[8]:find("g."..P.encode("InnerTop")..":"..P.encode("W_InnTop03_001"),1,true))
assert(not original.snapshot.Outfit.Garments:Find("InnerTop"),"Resolved metadata must not seed a new starting piece")
print("Wardrobe result metadata follows the game resolver independently of the immutable entry pieces.")

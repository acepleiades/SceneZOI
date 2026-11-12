local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B2/?.lua;"..package.path
inzoi={
    EB2ComponentType={Appearance=2},EB1ChangeOutfitReason={Invalid=0,Script=2},
    FB1StyleSetting=function() return {Outfit={Garments={Add=function(self,key,value) self[key]=value end}}} end,
    FB1GarmentDescription=function() return {} end,
}
local appearance={remove_count=0,enter_count=0}
appearance.setting={Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false},Outfit={ActiveStyleList={}}}
function appearance:GetAppearanceSetting() return self.setting end
function appearance:SetAppearanceSetting(value) self.setting=value end
local original={hair="hair",ring="ring",hat="hat",top={id="shirt",color="red"},indoor="TakeOffShoes"}
local function add_layer(reason, costume, garments)
    local layer = {Reason=reason, Outfit={CostumeId=costume, Garments=garments or {}}}
    table.insert(appearance.setting.Outfit.ActiveStyleList, layer)
    return layer
end
function appearance:GetActiveCostumeIdByReason(reason)
    local layers = self.setting.Outfit.ActiveStyleList
    for index = #layers, 1, -1 do
        if layers[index].Reason == reason then return layers[index].Outfit.CostumeId end
    end
    return "None"
end
function appearance:RefreshAppearance()
    self.refresh_count=(self.refresh_count or 0)+1
    if self.fail_refresh then self.fail_refresh=false;error("Injected appearance refresh failure") end
end
function appearance:EmplaceActiveOutfit(style,costume,reason)
    assert(reason==2 and costume=="SceneZOI_Demo_Outfit")
    assert(style.Reason==2 and style.Outfit.CostumeId==costume)
    self.enter_count=self.enter_count+1;self.layer=style
    table.insert(self.setting.Outfit.ActiveStyleList, style)
    if self.reset_merge_on_enter then self.setting.FinalBody.bUseMeshMerge=true end
    if self.enter_failure then error("Injected partial native entry") end
end
function appearance:RemoveCostumeByCostumeId(costume,reason)
    assert(reason==2 and costume=="SceneZOI_Demo_Outfit")
    self.remove_count=self.remove_count+1
    if self.remove_failure then self.remove_failure=false;error("Injected native restoration error") end
    if self.remove_deferred then return end
    local layers = self.setting.Outfit.ActiveStyleList
    for index = #layers, 1, -1 do
        local layer = layers[index]
        if layer.Reason == reason and layer.Outfit.CostumeId == costume then table.remove(layers, index) end
    end
    self.layer = nil
end
local owner={GetComponent=function(_,kind) assert(kind==2);return appearance end,GetEntityId=function()return {Value=7}end}
local outfit=require("SceneZOI.Outfit")
local slots={"Top","Bottom","Full","Jacket","Shoes","Socks","InnerTop","InnerUnder","Stockings","Gloves","Scarf"}
local function enter(owner,lease) return outfit.apply(owner,lease,slots) end
for _=1,20 do
    local lease={}
    enter(owner,lease)
    local calls=appearance.enter_count
    enter(owner,lease);assert(appearance.enter_count==calls)
    for _,kind in ipairs({"Top","Bottom","Full","Jacket","Shoes","Socks","InnerTop","InnerUnder","Stockings","Gloves","Scarf"}) do
        assert(appearance.layer.Outfit.Garments[kind].GarmentId=="None")
    end
    for _,kind in ipairs({"Hat","Necklace","Nail","Bracelet","Ring"}) do
        assert(not appearance.layer.Outfit.Garments[kind],"Accessory was included in undressing")
    end
    assert(not appearance.layer.Hair and not appearance.layer.Outfit.Accessories)
    outfit.restore(owner,lease)
    calls=appearance.remove_count;outfit.restore(owner,lease);assert(appearance.remove_count==calls)
    assert(not lease.outfit and not appearance.layer)
end
-- Idle can start with existing layers. Later outfit edits add a sparse layer above all of them.
local ring = add_layer(2, "Marriage_ExchangeRings", {Ring={GarmentId="WeddingRing"}})
local shoes = add_layer(4, "TakeOffShoes")
local mod = add_layer(2, "NZOI_Costume_NoneTopBottom", {Top={GarmentId="None"},Bottom={GarmentId="None"}})
local layers = appearance.setting.Outfit.ActiveStyleList
local lease = {}
outfit.apply(owner, lease, {})
assert(#layers == 3 and not lease.outfit)
enter(owner, lease)
assert(#layers == 4 and layers[1] == ring and layers[2] == shoes and layers[3] == mod)
assert(not layers[4].Outfit.Garments.Ring and ring.Outfit.Garments.Ring.GarmentId == "WeddingRing")
-- Another outfit can take precedence before Exit. Cleanup must still find and verify our layer.
local later = add_layer(2, "OtherMod_Later")
appearance.remove_deferred = true
assert(not pcall(outfit.restore, owner, lease) and lease.outfit and #layers == 5)
appearance.remove_deferred = false
outfit.restore(owner, lease)
assert(#layers == 4 and layers[1] == ring and layers[2] == shoes and layers[3] == mod and layers[4] == later)
-- A leftover under a newer Script layer is removed by ID before SceneZOI adds a revision.
local stale = add_layer(2, "SceneZOI_Demo_Outfit")
local uniform = add_layer(2, "Uniform01", {Top={GarmentId="UniformShirt"}})
enter(owner, {})
assert(#layers == 6 and layers[5] == uniform and layers[6] ~= stale)
outfit.restore(owner, {outfit=true,recovering=true})
assert(#layers == 5 and layers[5] == uniform and uniform.Outfit.Garments.Top.GarmentId == "UniformShirt")
appearance.setting.Outfit.ActiveStyleList = {}

-- Save recovery still understands old journals that lent a uniform.
local put_on
function appearance:ChangeCostumeByCostumeId(costume,reason)
    assert(reason==2)
    if self.fail_restore_uniform then error("Injected put-back failure") end
    put_on=add_layer(reason,costume)
end
local claim={outfit=true,lent_costume="Uniform01",recovering=true}
outfit.restore(owner,claim);assert(put_on==nil and claim.lent_costume==nil,"A claim alone puts nothing on")
local proven={outfit=true,lent_costume="Uniform01",recovering=true}
add_layer(2,"SceneZOI_Demo_Outfit")
appearance.fail_restore_uniform=true
assert(not pcall(outfit.restore,owner,proven) and proven.lent_costume=="Uniform01")
appearance.fail_restore_uniform=false
outfit.restore(owner,proven)
assert(put_on and put_on.Outfit.CostumeId=="Uniform01","Legacy recovery retries a failed put-back")
appearance.setting.Outfit.ActiveStyleList = {}
local taken={outfit=true,lent_costume="Uniform01",recovering=true}
add_layer(2,"SceneZOI_Demo_Outfit")
local replacement=add_layer(2,"OtherMod")
put_on=nil
outfit.restore(owner,taken)
assert(put_on==nil and appearance.setting.Outfit.ActiveStyleList[1]==replacement)
appearance.setting.Outfit.ActiveStyleList = {}
local recovery=require("SceneZOI.SaveRecovery")
UE=UE or {FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
local record={version=1,token="t",collision=true,local_value=true,follow_parent=false,outfit=true,location={0,0,0},rotation={0,0,0},furniture={},lent_costume="Uniform01"}
assert(recovery.lease(record).lent_costume=="Uniform01","A save keeps which uniform to put back")
record.lent_costume="bad value!";assert(not pcall(recovery.lease,record),"A malformed outfit id is refused")
enter(owner,lease);appearance.remove_failure=true
assert(not pcall(outfit.restore,owner,lease) and lease.outfit)
outfit.restore(owner,lease);assert(not lease.outfit)
appearance.enter_failure=true
assert(not pcall(enter,owner,lease) and lease.outfit)
appearance.enter_failure=false;outfit.restore(owner,lease)
assert(original.hair=="hair" and original.ring=="ring" and original.hat=="hat" and original.top.color=="red" and original.indoor=="TakeOffShoes")
-- Preserve the pre-scene merge snapshot across refreshes and failed release.
lease={};outfit.keep_unmerged(owner,lease)
assert(not appearance.setting.Body.bUseMeshMerge and not appearance.setting.FinalBody.bUseMeshMerge)
outfit.keep_unmerged(owner,lease)
assert(lease.body_merge.base and not lease.body_merge.final)
appearance.reset_merge_on_enter=true
enter(owner,lease)
assert(not appearance.setting.FinalBody.bUseMeshMerge,"Resolved outfit rules re-enabled merging before RefreshAppearance")
appearance.reset_merge_on_enter=false
appearance.fail_refresh=true
assert(not pcall(outfit.restore,owner,lease) and lease.body_merge)
outfit.restore(owner,lease)
assert(appearance.setting.Body.bUseMeshMerge and not appearance.setting.FinalBody.bUseMeshMerge and not lease.body_merge)
lease={};outfit.keep_unmerged(owner,lease)
local refreshes=appearance.refresh_count
outfit.restore(owner,lease)
assert(appearance.refresh_count==refreshes+1 and appearance.setting.Body.bUseMeshMerge,
    "A body-only lease must restore even with no outfit overlay")
local legacy_layers={
    {Reason=0,Outfit={CostumeId="SceneZOI_Prototype_MaleAnatomy"}},
    {Reason=0,Outfit={CostumeId="OtherMod"}},
    {Reason=0,Outfit={CostumeId="SceneZOI_Prototype_MaleAnatomy"}},
}
function legacy_layers:Remove(index) table.remove(self,index) end
appearance.setting.Outfit.ActiveStyleList=legacy_layers
outfit.recover(owner,{"SceneZOI_Prototype_MaleAnatomy"})
assert(#legacy_layers==1 and legacy_layers[1].Outfit.CostumeId=="OtherMod","Recovery removed another system's outfit layer")
print("Outfit checks passed: 20 temporary overlays, clothing-only allowlist, shared Script layer ownership, partial-entry cleanup and restoration retries.")

local lease={}
outfit.apply(owner,lease,{"Top"})
assert(appearance.layer.Outfit.Garments.Top and not appearance.layer.Outfit.Garments.Bottom)
outfit.apply(owner,lease,{"Bottom"})
assert(appearance.layer.Outfit.Garments.Bottom and appearance.layer.Outfit.Garments.Top)
local refreshes = appearance.refresh_count
outfit.apply(owner,lease,{})
assert(lease.outfit and appearance:GetActiveCostumeIdByReason(2)=="SceneZOI_Demo_Outfit")
assert(appearance.refresh_count==refreshes,"An omitted instruction must not refresh/rebuild the body")
outfit.apply(owner,lease,{"Bottom","Top"})
assert(appearance.refresh_count==refreshes,"Equivalent cumulative slots should be a no-op")
outfit.restore(owner,lease)
assert(not lease.outfit and not lease.removed_slots and appearance:GetActiveCostumeIdByReason(2)=="None")
print("Outfit node-change tests passed: additive removed slots, no refresh at hubs and original layer restored only on release.")

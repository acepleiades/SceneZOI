local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B2/?.lua;"..package.path
inzoi={
    EB2ComponentType={Appearance=2},EB1ChangeOutfitReason={Invalid=0,Script=2},
    FB1StyleSetting=function() return {Outfit={Garments={Add=function(self,key,value) self[key]=value end}}} end,
    FB1GarmentDescription=function() return {} end,
}
local appearance={active="None",remove_count=0,enter_count=0}
appearance.setting={Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}
function appearance:GetAppearanceSetting() return self.setting end
function appearance:SetAppearanceSetting(value) self.setting=value end
local original={hair="hair",ring="ring",hat="hat",top={id="shirt",color="red"},indoor="TakeOffShoes"}
function appearance:GetActiveCostumeIdByReason(reason) assert(reason==2);return self.active end
function appearance:RefreshAppearance()
    self.refresh_count=(self.refresh_count or 0)+1
    if self.fail_refresh then self.fail_refresh=false;error("Injected appearance refresh failure") end
end
function appearance:EmplaceActiveOutfit(style,costume,reason)
    assert(reason==2 and costume=="SceneZOI_Demo_Outfit")
    assert(style.Reason==2 and style.Outfit.CostumeId==costume)
    self.enter_count=self.enter_count+1;self.active=costume;self.layer=style
    if self.reset_merge_on_enter then self.setting.FinalBody.bUseMeshMerge=true end
    if self.enter_failure then error("Injected partial native entry") end
end
function appearance:RemoveCostumeByCostumeId(costume,reason)
    assert(reason==2 and costume=="SceneZOI_Demo_Outfit")
    self.remove_count=self.remove_count+1
    if self.remove_failure then self.remove_failure=false;error("Injected native restoration error") end
    self.active="None";self.layer=nil
end
local owner={GetComponent=function(_,kind) assert(kind==2);return appearance end}
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
appearance.active="AnotherMod"
local lease={}
assert(not pcall(enter,owner,lease) and not lease.outfit)
assert(appearance.active=="AnotherMod","Existing script layer was replaced")
appearance.active="None"
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
local layers={
    {Reason=0,Outfit={CostumeId="SceneZOI_Prototype_MaleAnatomy"}},
    {Reason=0,Outfit={CostumeId="OtherMod"}},
    {Reason=0,Outfit={CostumeId="SceneZOI_Prototype_MaleAnatomy"}},
}
function layers:Remove(index) table.remove(self,index) end
function appearance:GetAppearanceSetting() return {Outfit={ActiveStyleList=layers}} end
function appearance:SetAppearanceSetting(setting) assert(setting.Outfit.ActiveStyleList==layers) end
outfit.recover(owner,{"SceneZOI_Prototype_MaleAnatomy"})
assert(#layers==1 and layers[1].Outfit.CostumeId=="OtherMod","Recovery removed another system's outfit layer")
print("Outfit checks passed: 20 temporary overlays, clothing-only allowlist, existing layer refusal, partial-entry cleanup and restoration retries.")

local lease={}
outfit.apply(owner,lease,{"Top"})
assert(appearance.layer.Outfit.Garments.Top and not appearance.layer.Outfit.Garments.Bottom)
outfit.apply(owner,lease,{"Bottom"})
assert(appearance.layer.Outfit.Garments.Bottom and appearance.layer.Outfit.Garments.Top)
local refreshes = appearance.refresh_count
outfit.apply(owner,lease,{})
assert(lease.outfit and appearance.active=="SceneZOI_Demo_Outfit")
assert(appearance.refresh_count==refreshes,"An omitted instruction must not refresh/rebuild the body")
outfit.apply(owner,lease,{"Bottom","Top"})
assert(appearance.refresh_count==refreshes,"Equivalent cumulative slots should be a no-op")
outfit.restore(owner,lease)
assert(not lease.outfit and not lease.removed_slots and appearance.active=="None")
print("Outfit node-change tests passed: additive removed slots, no refresh at hubs and original layer restored only on release.")

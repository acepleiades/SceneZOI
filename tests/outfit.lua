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
appearance.active="AnotherMod"
local lease={}
assert(not pcall(enter,owner,lease) and not lease.outfit)
assert(appearance.active=="AnotherMod","Existing script layer was replaced")
-- A work uniform is lent for the scene and comes back after it. Anything else stays refused.
local shared_remove=appearance.RemoveCostumeByCostumeId
local taken_off,put_on
local queued=false
function appearance:RemoveCostumeByCostumeId(costume,reason)
 if costume=="Uniform01"then taken_off=costume;if not queued then self.active="None" end;return end
 return shared_remove(self,costume,reason)
end
function appearance:ChangeCostumeByCostumeId(costume,reason)assert(reason==2);put_on=costume;self.active=costume end
inzoi.FB2ScriptContext=function(a,b)return {a,b}end;inzoi.FB1Condition=function()return {}end
inzoi.EB1BaseObject={Self=1};inzoi.EB1CompareType={Equal=1};inzoi.EB1ScriptReason={Interaction=1};inzoi.EB1ConditionType={CostumeTag=9}
local tagged=true
inzoi.FB2Script_Appearance={Condition_CostumeTag=function(_,c)assert(c.S1=="Job"and c.Command==9);return tagged end}
local notes={};inzoi.message={send_to_client=function(_,kind,content)notes[#notes+1]={kind,content}end}
local function top_layer(reason,costume)appearance.setting.Outfit={ActiveStyleList={{Reason=reason,Outfit={CostumeId=costume}}}}end
top_layer(2,"Uniform01")
appearance.active="Uniform01"
assert(outfit.borrowable(owner)=="Uniform01")
local work={token="t1"}
enter(owner,work)
assert(taken_off=="Uniform01"and work.lent_costume=="Uniform01"and appearance.active=="SceneZOI_Demo_Outfit")
assert(notes[#notes][1]=="SceneZOI.Save"and notes[#notes][2]:find("lent|Uniform01",1,true),"The save record learns what was actually taken off")
local refreshes=appearance.refresh_count or 0
outfit.restore(owner,work)
assert(put_on=="Uniform01"and appearance.active=="Uniform01"and work.lent_costume==nil,"The uniform goes back on")
assert((appearance.refresh_count or 0)==refreshes+1,"The game is told once")
-- Dressed by something else during the scene: leave it alone.
work={};enter(owner,work);put_on=nil
function appearance:GetActiveCostumeIdByReason(reason)assert(reason==2);if work.outfit==false and not self.hold then return "AnotherLayer" end;return self.active end
outfit.restore(owner,work);assert(put_on==nil and work.lent_costume==nil,"A slot something else took is not overwritten")
function appearance:GetActiveCostumeIdByReason(reason)assert(reason==2);return self.active end
appearance.active="Uniform01"
-- A failed removal or put-back keeps the uniform on record and retries.
work={};local remove_uniform=appearance.RemoveCostumeByCostumeId
function appearance:RemoveCostumeByCostumeId(costume,reason)if costume=="Uniform01"then error("Injected removal failure")end;return remove_uniform(self,costume,reason)end
assert(not pcall(enter,owner,work)and work.lent_costume=="Uniform01","Recorded before the native call")
appearance.RemoveCostumeByCostumeId=remove_uniform;appearance.active="None"
local put_back=appearance.ChangeCostumeByCostumeId;local fail_once=true
function appearance:ChangeCostumeByCostumeId(costume,reason)if fail_once then fail_once=false;error("Injected put-back failure")end;return put_back(self,costume,reason)end
assert(not pcall(outfit.restore,owner,work)and work.lent_costume=="Uniform01","A failed put-back stays on record")
outfit.restore(owner,work);assert(appearance.active=="Uniform01"and work.lent_costume==nil,"And is retried")
appearance.ChangeCostumeByCostumeId=put_back
-- A Job layer on top of another mod's Script outfit is not a reason to take that outfit off.
appearance.active="OtherMod_Dress";top_layer(11,"Uniform01")
assert(outfit.borrowable(owner)==nil and not pcall(enter,owner,{})and appearance.active=="OtherMod_Dress","The Job tag must belong to the Script layer")
top_layer(2,"Uniform01");appearance.active="Uniform01"
-- A costume id the save record could not hold is not borrowed.
appearance.active="Bad.Id";top_layer(2,"Bad.Id");assert(outfit.borrowable(owner)==nil)
appearance.active="Uniform01";top_layer(2,"Uniform01")
-- After a load, only our own layer proves the scene took the uniform.
local claim={outfit=true,lent_costume="Uniform01",recovering=true};appearance.active="None";put_on=nil
outfit.restore(owner,claim);assert(put_on==nil and claim.lent_costume==nil,"A claim alone puts nothing on")
local proven={outfit=true,lent_costume="Uniform01",recovering=true};appearance.active="SceneZOI_Demo_Outfit"
outfit.restore(owner,proven);assert(put_on=="Uniform01","Our layer was there, so the uniform goes back")
appearance.active="Uniform01"
-- The game can queue taking it off while the Zoi finishes an interaction: the scene waits, without asking twice.
appearance.active="Uniform01";queued=true;taken_off=nil
local waiting={}
assert(enter(owner,waiting)==false and waiting.lent_costume=="Uniform01"and taken_off=="Uniform01"and not waiting.outfit,"Still queued: wait")
taken_off=nil
assert(enter(owner,waiting)==false and taken_off==nil,"The removal is requested once")
appearance.active="None";queued=false
enter(owner,waiting);assert(waiting.outfit and appearance.active=="SceneZOI_Demo_Outfit","Once it is off, the scene outfit goes on")
outfit.restore(owner,waiting);assert(appearance.active=="Uniform01")
tagged=false;work={};taken_off=nil
assert(not pcall(enter,owner,work)and appearance.active=="Uniform01"and not work.lent_costume and not taken_off,"Only Job outfits are borrowed")
assert(outfit.borrowable(owner)==nil)
tagged=true
local recovery=require("SceneZOI.SaveRecovery")
UE=UE or {FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FRotator=function(p,y,r)return {Pitch=p,Yaw=y,Roll=r}end}
local record={version=1,token="t",collision=true,local_value=true,follow_parent=false,outfit=true,location={0,0,0},rotation={0,0,0},furniture={},lent_costume="Uniform01"}
assert(recovery.lease(record).lent_costume=="Uniform01","A save keeps which uniform to put back")
record.lent_costume="bad value!";assert(not pcall(recovery.lease,record),"A malformed outfit id is refused")
appearance.active="SceneZOI_Demo_Outfit"
local leftover={}
enter(owner,leftover);assert(leftover.outfit and appearance.remove_count>0,"A leftover layer of our own is cleared, not refused")
outfit.restore(owner,leftover)
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

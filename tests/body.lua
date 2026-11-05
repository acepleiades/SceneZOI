local root=TEST_ROOT or "modkit/SceneZOI_93C44199/workspace/lua/"
package.path=root.."B1/?.lua;"..package.path
assert(loadfile("tests/support/profiles.lua"))()
local asset={}
local material={}
local created,destroyed=0,0
local leader_failure,destroy_failure=false,false
UE={UObject={Load=function() return asset end},FTransform=function() return {} end,
    USkeletalMeshComponent={StaticClass=function() return {} end}}
inzoi={EB1GenderType={Male=1,Female=2}}
local body=require("SceneZOI.BodyRegion")
local coverage_garments={}
function coverage_garments:ToTable()
    local result={}
    for key,value in pairs(self) do if type(value)=="table" then result[key]=value end end
    return result
end
local coverage_actor={AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=coverage_garments}}}}}
local function covered() return body.covered(coverage_actor,"test.region") end
for _,slot in ipairs({"Bottom","Full","InnerUnder","Top","ModdedCoat"}) do
    coverage_garments[slot]={GarmentId="not_a_pants_name",BodyFlags=1 << 17}
    assert(covered(),"Coverage must work independently of the garment category")
    coverage_garments[slot]=nil
end
coverage_garments.Bottom={BodyFlags=1 << 17};coverage_garments.Full={BodyFlags=1 << 17}
assert(covered());coverage_garments.Bottom=nil;assert(covered());coverage_garments.Full=nil
coverage_garments.InnerUnder={GarmentId="normalized_base_body",BodyFlags=0}
assert(not covered(),"Normalized underwear IDs must not imply coverage")
coverage_garments.Top={BodyFlags=(1 << 16) | (1 << 18)}
assert(not covered(),"Adjacent body regions must not count as crotch coverage")
coverage_garments.Full={BodyFlags=-1}
assert(not covered(),"The game's all-regions skeleton-preservation exception must be mirrored")
coverage_garments.Full={BodyFlags=0xffffffff}
assert(not covered())
assert(not pcall(body.covered,coverage_actor,"unverified_body"))
local owner={actor=coverage_actor,original_outfit_metadata={
    Top={asset="shirt",flags=0},Full={asset="full",flags=1 << 17},CustomCoat={asset="coat",flags=1 << 17}}}
local function after(kind,key,asset,enabled)
    return body.after_outfit(owner,{piece={kind=kind,key=key,asset=asset},enabled=enabled and "1" or "0"},"test.region")
end
coverage_garments.Top={BodyFlags=0};coverage_garments.Full=nil;coverage_garments.InnerUnder={BodyFlags=0}
assert(after("garment","Top","shirt",true)==false)
assert(after("garment","Full","full",true)==true)
assert(after("garment","CustomCoat","coat",true)==true,"Custom garment slots must use their actual mask")
assert(after("garment","Top","different_asset",true)==nil,"Mismatched snapshots must remain conservative")
assert(after("garment","Unknown","unknown",true)==nil)
assert(after("garment","Top","shirt",false)==false)
assert(after("accessory","Bag","bag",true)==false and after("printed","1/hand_r","prop",false)==false)
coverage_garments.Bottom={BodyFlags=1 << 17}
assert(after("garment","Top","shirt",true)==true,"Other covering layers must remain part of the prediction")
coverage_garments.Bottom=nil;coverage_garments.Top={BodyFlags=1 << 17};coverage_garments.Full={BodyFlags=-1}
assert(not covered() and after("garment","Full","full",false)==true,
    "The all-regions exception must be applied after the entire predicted outfit is combined")
assert(not body.ready({body_region={patch={}}}),"An unfinished body must not enter mesh readiness checks")
assert(body.load("test.region")==asset)
local actor,mesh,patch,setting
local function fixture()
    local mesh_asset={GetName=function() return "SKM_Male_Base" end}
    mesh={visibility={[0]=true,[1]=false},count=1}
    function mesh:GetSkeletalMeshAsset() return mesh_asset end
    function mesh:GetNumMaterials() return self.count end
    function mesh:GetMaterialIndex(name) assert(name=="Material_018");return 17 end
    function mesh:GetNumLODs() return 2 end
    function mesh:IsMaterialSectionShown(slot,lod) assert(slot==17);return self.visibility[lod] end
    function mesh:ShowMaterialSection(slot,section,shown,lod)
        assert(slot==17 and section==17);self.visibility[lod]=shown
    end
    function mesh:GetMaterial(slot) assert(slot==17);if self.material_missing then return nil end;return material end
    function mesh:GetMorphTarget(name) assert(name=="Body_Muscle");return .21 end
    setting={Gender=1,Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}
    actor={Mesh=mesh,AppearanceComponent={AppearanceSetting=setting}}
    function actor.AppearanceComponent:RefreshAll() self.refreshes=(self.refreshes or 0)+1;mesh.count=32 end
    function actor:AddComponentByClass(_,manual,_,deferred)
        assert(manual and not deferred)
        created=created+1
        patch={visibility={},materials={},hidden=true}
        function patch:SetHiddenInGame(value) self.hidden=value end
        function patch:SetCollisionEnabled(value) assert(value==0) end
        function patch:SetGenerateOverlapEvents(value) assert(not value) end
        function patch:SetSimulatePhysics(value) assert(not value) end
        function patch:SetSkeletalMeshAsset(value) assert(value==asset) end
        function patch:GetMaterialIndex(name) assert(name=="shader_body_shader18");return 17 end
        function patch:K2_AttachToComponent(parent,bone,a,b,c,weld)
            assert(parent==mesh and bone=="None" and a==0 and b==0 and c==0 and not weld);return true
        end
        function patch:K2_SetRelativeTransform() end
        function patch:SetLeaderPoseComponent(parent,force,tick)
            if leader_failure then leader_failure=false;error("Injected LeaderPose failure") end
            assert(parent==mesh and force and not tick)
        end
        function patch:AddTickPrerequisiteComponent(parent) assert(parent==mesh) end
        function patch:SetMaterial(slot,value) assert(value==material);self.materials[slot]=value end
        function patch:GetMaterial(slot) return self.materials[slot] end
        function patch:GetNumMaterials() return 32 end
        function patch:GetNumLODs() return 4 end
        function patch:ShowMaterialSection(slot,section,shown,lod)
            assert(slot==section);self.visibility[lod..":"..slot]=shown
        end
        function patch:SetMorphTarget(name,value,remove) assert(name=="Body_Muscle" and value==.21 and remove) end
        function patch:PrestreamTextures() end
        function patch:GetNumBones() return 432 end
        function patch:K2_DestroyComponent(owner)
            assert(owner==actor)
            if destroy_failure then destroy_failure=false;error("Injected destruction failure") end
            destroyed=destroyed+1
        end
        return patch
    end
    return {patch_asset=asset,node={attachment={body_profile="test.region"}}}
end
local function prepared(s)
    assert(not body.prepare(s,actor))
    assert(not setting.Body.bUseMeshMerge and not setting.FinalBody.bUseMeshMerge)
    assert(not body.prepare(s,actor))
    assert(not body.prepare(s,actor))
    assert(body.prepare(s,actor))
    assert(patch.hidden and mesh.visibility[0] and not mesh.visibility[1])
    for lod=0,3 do
        for slot=0,31 do assert(patch.visibility[lod..":"..slot]==(slot==17)) end
    end
end
local function restored(s, refreshes)
    assert(not s.body_region and setting.Body.bUseMeshMerge and not setting.FinalBody.bUseMeshMerge)
    assert(mesh.visibility[0] and not mesh.visibility[1],"Restore must preserve originally hidden LODs")
    assert(actor.AppearanceComponent.refreshes==(refreshes or 1),"Cleanup must not replace the montage's animation instance")
end
for _=1,6 do
    local s=fixture();prepared(s)
    assert(not body.ready(s) and mesh.visibility[0] and patch.hidden)
    assert(not body.ready(s))
    assert(body.ready(s) and not patch.hidden)
    assert(not mesh.visibility[0] and not mesh.visibility[1])
    body.restore(s);body.restore(s);restored(s)
end
-- Exit while appearance is being rebuilt, before either object exists.
local s=fixture();assert(not body.prepare(s,actor));body.restore(s);restored(s)
-- Partial component construction must remain owned by the session after an exception.
s=fixture();leader_failure=true
assert(not body.prepare(s,actor));body.prepare(s,actor);body.prepare(s,actor)
assert(not pcall(body.prepare,s,actor) and s.body_region.patch)
body.restore(s);restored(s)
-- Destruction failure must leave enough state for the existing runtime retry path.
s=fixture();prepared(s);destroy_failure=true
assert(not pcall(body.restore,s) and s.body_region)
body.restore(s);restored(s)
-- The adapter follows explicit layout data, not a framework gender restriction.
s=fixture();setting.Gender=2
prepared(s);body.restore(s);restored(s)
-- Slot count is available before the appearance skin MID on an initial load.
s=fixture();mesh.material_missing=true
local before_created=created
assert(not body.prepare(s,actor));body.prepare(s,actor);body.prepare(s,actor)
assert(not body.prepare(s,actor) and created==before_created)
mesh.material_missing=false
assert(body.prepare(s,actor))
body.restore(s);restored(s)
-- Manual clothing can rebuild the mesh while the session is still alive.
s=fixture();prepared(s);body.ready(s);body.ready(s);assert(body.ready(s))
local original_patch,old_mesh=patch,mesh
local rebuilt={visibility={[0]=true,[1]=false},count=32}
for key,value in pairs(old_mesh) do if type(value)=="function" then rebuilt[key]=value end end
mesh=rebuilt;actor.Mesh=rebuilt
-- The visual guard runs before appearance/material readiness, retaining the
-- original per-LOD values even when it has already hidden the incoming mesh.
body.guard(s)
assert(not rebuilt.visibility[0] and not old_mesh.visibility[0])
assert(not body.prepare(s,actor));assert(not body.prepare(s,actor));assert(body.prepare(s,actor))
assert(patch~=original_patch and s.body_region.mesh==rebuilt)
assert(not body.ready(s));assert(not body.ready(s));assert(body.ready(s))
body.restore(s);restored(s)
assert(old_mesh.visibility[0] and not old_mesh.visibility[1],"The retired mesh's original section visibility was lost")
-- Simulation outfit refreshes resend merge settings. Reapply the active profile
-- once, wait for its rebuild, and retain the original merge/visibility snapshot.
for _, flags in ipairs({{true,false},{false,true},{true,true}}) do
    s=fixture();prepared(s);body.ready(s);body.ready(s);assert(body.ready(s))
    original_patch,old_mesh=patch,mesh
    rebuilt={visibility={[0]=true,[1]=false},count=1}
    for key,value in pairs(old_mesh) do if type(value)=="function" then rebuilt[key]=value end end
    mesh=rebuilt;actor.Mesh=rebuilt
    setting.Body.bUseMeshMerge,setting.FinalBody.bUseMeshMerge=flags[1],flags[2]
    assert(not body.prepare(s,actor) and not s.body_region.mesh and not s.body_region.patch)
    assert(actor.AppearanceComponent.refreshes==2 and s.body_region.frames==0)
    assert(not setting.Body.bUseMeshMerge and not setting.FinalBody.bUseMeshMerge)
    assert(not body.prepare(s,actor));assert(not body.prepare(s,actor));assert(body.prepare(s,actor))
    assert(patch~=original_patch and s.body_region.mesh==rebuilt)
    assert(not body.ready(s));assert(not body.ready(s));assert(body.ready(s))
    assert(body.prepare(s,actor) and actor.AppearanceComponent.refreshes==2,"Stable profiles must not refresh every frame")
    body.restore(s);restored(s,2)
    assert(old_mesh.visibility[0] and not old_mesh.visibility[1])
end
-- Exit during a repeated unmerge still restores the entry flags and owns cleanup.
s=fixture();prepared(s);setting.FinalBody.bUseMeshMerge=true
assert(not body.prepare(s,actor));body.restore(s);restored(s,2)
-- A native parameter refresh can reset section flags on the same mesh. Re-hide
-- immediately even while its material is unavailable, without recapturing state.
s=fixture();prepared(s)
body.guard(s);assert(mesh.visibility[0],"Initial coverage must wait for the stock patch")
body.ready(s);body.ready(s);assert(body.ready(s))
mesh.visibility[0]=true;mesh.material_missing=true
body.guard(s);assert(not mesh.visibility[0] and s.body_region.guard_ticks==1)
assert(not body.ready(s))
body.restore(s);restored(s)
assert(created==destroyed,"Skin patch components leaked")
print("Body checks passed: readiness barrier, section/LOD isolation, pose/material/muscle setup, repeated sessions, early Exit, partial failure, restoration retry, female exclusion.")
print("Body refresh passed: replace the obsolete stock patch on an outfit mesh rebuild while preserving merge and section restoration.")

-- Unfamiliar mesh/material names must work when the declared section is preserved.
local profile=require('SceneZOI.Profiles').body('test.region')
for _,layout in ipairs({{name='ArbitraryBodyA',materials=18},{name='DifferentBodyB',materials=32},{name='ExtraSectionsC',materials=48}})do
 s=fixture()
 local native_asset={GetName=function()return layout.name end}
 mesh.GetSkeletalMeshAsset=function()return native_asset end
 mesh.GetMaterialIndex=function()error('Participant material names must not be queried')end
 function actor.AppearanceComponent:RefreshAll()self.refreshes=(self.refreshes or 0)+1;mesh.count=layout.materials end
 prepared(s);body.ready(s);body.ready(s);assert(body.ready(s))
 mesh.visibility[0]=true;body.guard(s);assert(not mesh.visibility[0],'Active coverage must support the declared section regardless of mesh/material names')
 setting.FinalStyle={Outfit={Garments={ToTable=function()return {Bottom={BodyFlags=1<<17}}end}}}
 mesh.visibility[0]=true;assert(body.guard_clothing(actor,'test.region')==1,'Clothing and preparation must share the same generic section checks')
 body.restore(s);restored(s)
end
-- Missing sections, LODs and skin resources remain retryable without masking.
for _,missing in ipairs({'section','lod','asset','material','component'})do
 s=fixture();assert(not body.prepare(s,actor))
 if missing=='section'then mesh.count=17
 elseif missing=='lod'then mesh.GetNumLODs=function()return 0 end
 elseif missing=='asset'then mesh.GetSkeletalMeshAsset=function()return nil end
 elseif missing=='component'then actor.Mesh=nil
 else mesh.material_missing=true end
 for _=1,5 do assert(not body.prepare(s,actor),'Unavailable section resources must remain retryable')end
 assert(not s.body_region.patch and mesh.visibility[0])
 assert(body.status(s):find('section=17',1,true),'Diagnostics must identify the required section')
 body.restore(s);restored(s)
end
local Validate=require('SceneZOI.ProfileData')
assert(pcall(Validate.validate_body,profile))
local copy=require('SceneZOI.DataValidation').copy
for _,field in ipairs({'mesh_name','material_slot','minimum_materials','compatible_layouts'})do
 local p=copy(profile);p[field]='obsolete';assert(not pcall(Validate.validate_body,p),'Removed name-list fields must not be accepted')
end
assert(created==destroyed,'Generic section readiness must retain independent patch cleanup')
print('Generic body section passed: arbitrary names/material counts, exact declared section across all guards, resource waits, independent cleanup and removed-name-list validation.')

package.path=(TEST_ROOT or 'modkit/SceneZOI_93C44199/workspace/lua/')..'B1/?.lua;'..package.path
local records={}
package.loaded['SceneZOI.ClothingCoverage']={compatible_body=function()return true end,original_visibility=function()end}
package.loaded['SceneZOI.Diagnostics']={record=function(kind,detail)records[#records+1]={kind=kind,detail=detail}end}
local assets,skeleton={},{}
UE={UObject={Load=function(path)return assets[path]end},FTransform=function()return {}end,
    USkeletalMeshComponent={StaticClass=function()return {}end}}
local function array(value)return {ToTable=function()return value end}end
local function soft(path)
    local package,name=path:match('^(.*)%.([^%.]+)$')
    return {AssetPath={PackageName=package or 'None',AssetName=name or 'None'}}
end
local function asset(path,slots,compatible)
    local value={path=path,slots=slots or {'skin','hidden'},PhysicsAsset={name=path},
        MorphTargets=array({{GetName=function()return 'Body_Muscle'end}})}
    local materials={};for _,slot in ipairs(value.slots)do materials[#materials+1]={MaterialSlotName=slot}end
    value.Materials=array(materials)
    function value:GetName()return self.path:match('%.([^%.]+)$')end
    function value:GetSkeleton()return compatible==false and {}or skeleton end
    assets[path]=value;return value
end
local SOURCE=asset('/Native/Body.Body')
local FIRST=asset('/Provider/First.First',{'hidden','skin'})
local SECOND=asset('/Provider/Second.Second')
local WRONG=asset('/Provider/Wrong.Wrong',nil,false)
local function fixture(id,role)
    local skin,hidden={},{}
    local mesh={asset=SOURCE,instance={},materials={[0]=skin,[1]=hidden},visibility={[0]={[0]=true,[1]=true},[1]={[0]=false,[1]=false}},
        morphs={Body_Muscle=.37},changes=0,physics_changes=0}
    function mesh:GetSkeletalMeshAsset()return self.asset end
    function mesh:GetAnimInstance()return self.instance end
    function mesh:GetNumLODs()return 2 end
    function mesh:GetNumMaterials()return #self.asset.slots end
    function mesh:GetMaterialSlotNames()return array(self.asset.slots)end
    function mesh:GetMaterialIndex(name)for i,n in ipairs(self.asset.slots)do if n==name then return i-1 end end;return -1 end
    function mesh:GetMaterial(index)return self.materials[index]end
    function mesh:SetMaterial(index,value)if self.material_failure then error('material failure')end;self.materials[index]=value end
    function mesh:IsMaterialSectionShown(index,lod)return self.visibility[index][lod]end
    function mesh:ShowMaterialSection(index,section,shown,lod)
        assert(index==section);self.visibility[index]=self.visibility[index]or {};self.visibility[index][lod]=shown
    end
    function mesh:GetMorphTarget(name)return self.morphs[name]or 0 end
    function mesh:SetMorphTarget(name,value)self.morphs[name]=value end
    function mesh:SetPhysicsAsset(value,force)assert(not force);self.PhysicsAssetOverride=value;self.physics_changes=self.physics_changes+1 end
    function mesh:SetSkeletalMeshAsset(value)
        assert(value and not value.invalid,'Stale mesh userdata');self.asset=value;self.changes=self.changes+1
        if self.instance_failure then self.instance={}end
    end
    local setting={Body={OverrideMesh=soft(''),bUseMeshMerge=false},
        FinalBody={OverrideMesh=soft(''),bUseMeshMerge=false,BodyData={BodyMesh=soft(SOURCE.path)}}}
    local p={id=id,role=role,actor={Mesh=mesh,AppearanceComponent={AppearanceSetting=setting}}}
    p.actor.keepers={}
    function p.actor:AddComponentByClass(_,manual,_,deferred)
        assert(manual and not deferred)
        local holder={materials={}}
        function holder:SetHiddenInGame(hidden)assert(hidden)end
        function holder:SetCollisionEnabled(mode)assert(mode==0)end
        function holder:SetGenerateOverlapEvents(enabled)assert(not enabled)end
        function holder:SetSimulatePhysics(enabled)assert(not enabled)end
        function holder:SetComponentTickEnabled(enabled)assert(not enabled)end
        function holder:SetSkeletalMeshAsset(value)self.asset=value end
        function holder:GetSkeletalMeshAsset()return self.asset end
        function holder:SetMaterial(index,value)self.materials[index]=value end
        function holder:K2_DestroyComponent(actor)
            if actor.keeper_destroy_failure then error('keeper cleanup failed')end
            self.destroyed=true;self.asset=nil;self.materials={}
        end
        self.keepers[#self.keepers+1]=holder
        return holder
    end
    return p,mesh,skin,hidden,setting
end
local Body=require('SceneZOI.TemporaryBody')
local first,mesh,skin,hidden,setting=fixture('one','female')
local second,other=fixture('two','male')
local current={participants={first,second},node={id='scene',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
local instance=mesh.instance
assert(not Body.prepare(current)and mesh.asset==FIRST)
assert(mesh.materials[0]==hidden and mesh.materials[1]==skin,'Native skin did not map by material name')
assert(not mesh.visibility[0][0]and mesh.visibility[1][0],'Clothing section masks did not map by material name')
assert(mesh.morphs.Body_Muscle==.37 and mesh.PhysicsAssetOverride==SOURCE.PhysicsAsset)
assert(mesh.instance==instance and other.changes==0)
assert(first.actor.keepers[1].asset==SOURCE and first.actor.keepers[1].materials[0]==skin,
    'Native-generated mesh and dynamic materials need an engine GC owner')
assert(setting.Body.OverrideMesh.AssetPath.PackageName=='None'and setting.FinalBody.OverrideMesh.AssetPath.PackageName=='None',
    'Body variant modified appearance storage')
assert(Body.prepare(current)and mesh.changes==1,'Stable selected mesh was reapplied every frame')
current.node._body_variants.female={id='test.second',mesh=SECOND.path}
assert(not Body.prepare(current)and mesh.asset==SECOND)
assert(current.temporary_bodies.one.original.asset==SOURCE,'Navigation recaptured the selected body as native')
current.node._body_variants={}
assert(not Body.prepare(current)and mesh.asset==SOURCE)
assert(mesh.materials[0]==skin and mesh.materials[1]==hidden and not mesh.visibility[1][0])
assert(mesh.PhysicsAssetOverride==nil,'Native default physics was not restored')
assert(first.actor.keepers[1].destroyed,'Keeper leaked after deselection')
assert(Body.prepare(current))

-- Existing region masking is temporary; it must not become the body's native baseline.
for _,original_shown in ipairs({true,false})do
    local person,body=fixture('masked','female')
    local masks={[1]={[0]=original_shown,[1]=original_shown}}
    local scene={participants={person},node={id='masked',_body_variants={female={id='test.first',mesh=FIRST.path}}},
        subsystems={body_visibility=function(_,owner,component,native)
            assert(owner==person and component==body and native==SOURCE)
            return masks
        end}}
    assert(not Body.prepare(scene))
    assert(scene.temporary_bodies.masked.original.slots.hidden.visibility[0]==original_shown,
        'The attachment-owned hidden section contaminated the native body baseline')
    assert(masks[1][0]==original_shown,'Capturing native body visibility modified subsystem snapshots')
    scene.subsystems={};scene.node._body_variants={}
    assert(not Body.prepare(scene)and body.asset==SOURCE)
    assert(body.visibility[1][0]==original_shown and body.visibility[1][1]==original_shown,
        'Retiring both attachment and body must restore native visibility, including garment-hidden sections')
end

-- A native clothing rebuild becomes the latest baseline, not an old snapshot.
current.node._body_variants.female={id='test.first',mesh=FIRST.path}
assert(not Body.prepare(current))
local NEW=asset('/Native/New.New')
mesh.asset=NEW;setting.FinalBody.BodyData.BodyMesh=soft(NEW.path)
mesh.materials={[0]=skin,[1]=hidden};mesh.visibility={[0]={[0]=true,[1]=true},[1]={[0]=false,[1]=false}}
assert(not Body.guard(current)and mesh.asset==NEW,'Guard must hold before reapplying after a native rebuild')
assert(not Body.prepare(current)and mesh.asset==FIRST)
Body.restore(current)
assert(mesh.asset==NEW,'Exit restored an obsolete native mesh')
assert(mesh.PhysicsAssetOverride==nil,'A clothing rebuild recaptured our own physics override as native')

-- Reacquire meshes after a native rebuild: Lua references are not GC owners.
first,mesh,skin,hidden,setting=fixture('gc','female')
current={participants={first},node={id='scene',_body_variants={female={id='test.gc',mesh=FIRST.path}}}}
assert(not Body.prepare(current))
mesh.asset=SOURCE;mesh.materials={[0]=skin,[1]=hidden}
mesh.visibility={[0]={[0]=true,[1]=true},[1]={[0]=false,[1]=false}}
FIRST.invalid=true
local FRESH=asset(FIRST.path,{'hidden','skin'})
assert(not Body.guard(current))
assert(not Body.prepare(current)and mesh.asset==FRESH,'A stale cached provider asset survived a native rebuild')
-- A changed static lookup must not replace the exact generated source retained in native ownership.
local FRESH_SOURCE=asset(SOURCE.path)
Body.restore(current)
assert(mesh.asset==SOURCE,'Restoration discarded the exact engine-retained native source')
FIRST.invalid=nil
assets[FIRST.path],assets[SOURCE.path]=FIRST,SOURCE

-- Do not swap the old merged mesh while native clothing is still preparing.
first,mesh=fixture('merged','female')
local MERGED=asset('/Transient/Merged.Merged',{'garments_and_skin'})
mesh.asset=MERGED
current={participants={first},node={id='scene',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
assert(not Body.prepare(current)and mesh.changes==0)
assert(Body.status(current):find('awaiting_native_section_layout',1,true))
mesh.asset=SOURCE
assert(not Body.prepare(current)and mesh.asset==FIRST)
mesh.asset=MERGED;current.node._body_variants={}
assert(Body.prepare(current)and mesh.asset==MERGED,'Deselection overwrote a newer native clothing rebuild')
assert(mesh.PhysicsAssetOverride==nil,'Native body restoration left our physics override behind')
Body.restore(current);assert(mesh.asset==MERGED)

-- An unmerged native body may still be generated rather than the configured static asset.
first,mesh,skin,hidden,setting=fixture('generated','female')
local GENERATED=asset('/Transient/Generated.Generated')
mesh.asset=GENERATED;setting.Body.bUseMeshMerge=true;setting.FinalBody.bUseMeshMerge=true
current={participants={first},node={id='scene',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
assert(not Body.prepare(current)and mesh.asset==GENERATED and mesh.changes==0)
setting.Body.bUseMeshMerge=false;setting.FinalBody.bUseMeshMerge=false
assert(not Body.prepare(current)and mesh.asset==FIRST,'Generated unmerged native bodies must be supported')
assert(first.actor.keepers[1].asset==GENERATED)
Body.restore(current)
assert(mesh.asset==GENERATED and first.actor.keepers[1].destroyed)

-- Invalid optional bodies log once and preserve a valid native body.
for _,bad in ipairs({'/Provider/Missing.Missing',WRONG.path})do
    first,mesh=fixture('invalid','female')
    current={participants={first},node={id='scene',_body_variants={female={id='test.bad',mesh=bad}}}}
    local before=#records
    assert(Body.prepare(current)and Body.prepare(current)and mesh.asset==SOURCE and mesh.changes==0)
    assert(#records==before+1 and records[#records].kind=='appearance_variant_warning')
end

-- Independent cleanup retries a failed skin restore without undoing other owners.
first,mesh=fixture('one','female');second,other=fixture('two','male')
current={participants={first,second},node={id='scene',_body_variants={
    female={id='test.first',mesh=FIRST.path},male={id='test.second',mesh=SECOND.path}}}}
assert(not Body.prepare(current));mesh.material_failure=true
assert(not pcall(Body.restore,current)and other.asset==SOURCE)
local changes=other.changes
mesh.material_failure=false;Body.restore(current)
assert(mesh.asset==SOURCE and other.changes==changes)

-- Keeper cleanup has its own retry; an already restored native body is not swapped again.
first,mesh=fixture('keeper','female')
current={participants={first},node={id='scene',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
assert(not Body.prepare(current));first.actor.keeper_destroy_failure=true
assert(not pcall(Body.restore,current)and mesh.asset==SOURCE)
changes=mesh.changes;first.actor.keeper_destroy_failure=false
Body.restore(current)
assert(mesh.changes==changes and first.actor.keepers[1].destroyed)

-- Unexpected animation-instance changes fail through ordinary retryable cleanup.
first,mesh=fixture('instance','female')
current={participants={first},node={id='scene',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
mesh.instance_failure=true
assert(not pcall(Body.prepare,current))
mesh.instance_failure=false;Body.restore(current);assert(mesh.asset==SOURCE)
-- Clothing coverage runs before attachment coverage. Neither layer's mask is
-- a native restoration baseline, including when the same slot is owned by both.
local Coverage=package.loaded['SceneZOI.ClothingCoverage']
for _,native_shown in ipairs({true,false})do
    local person,body=fixture('clothing-baseline','female')
    local clothing={[1]={[0]=native_shown,[1]=native_shown}}
    local attachment={[1]={[0]=false,[1]=false}}
    local scene={participants={person},node={id='clothing-baseline',_body_variants={female={id='test.first',mesh=FIRST.path}}},
        subsystems={body_visibility=function()return attachment end}}
    Coverage.original_visibility=function(owner,participant,component,asset)
        assert(owner==scene and participant==person and component==body and asset==SOURCE)
        return clothing
    end
    assert(not Body.prepare(scene))
    assert(scene.temporary_bodies[person.id].original.slots.hidden.visibility[0]==native_shown,
        'Clothing originals must override the attachment snapshot of already-clothing-masked skin')
    assert(attachment[1][0]==false and clothing[1][0]==native_shown,'Capturing baselines must not mutate either owner')
    scene.subsystems={};scene.node._body_variants={}
    assert(not Body.prepare(scene)and body.asset==SOURCE)
    assert(body.visibility[1][0]==native_shown and body.visibility[1][1]==native_shown,
        'Removing body and both coverage layers must restore the native baseline on every LOD')
end
Coverage.original_visibility=function()end
local compatibility=Coverage.compatible_body
Coverage.compatible_body=function()return false,'The replacement body has no supported native clothing region layout.'end
first,mesh=fixture('unsupported-layout','female')
current={participants={first},node={id='unsupported-layout',_body_variants={female={id='test.first',mesh=FIRST.path}}}}
local warning_count=#records
assert(Body.prepare(current)and Body.prepare(current)and mesh.asset==SOURCE and mesh.changes==0)
assert(#records==warning_count+1 and records[#records].detail.detail:find('clothing region layout',1,true),
    'A late unsupported-layout check must warn once and preserve the valid native body')
Coverage.compatible_body=compatibility
print('Temporary body tests passed: renderer-only geometry, native instance, skin/morph/physics/masks, clothing/attachment originals, rebuilds, invalid fallbacks and independent cleanup.')

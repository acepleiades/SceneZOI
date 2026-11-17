-- Native skin MIDs can arrive after an unmerged body exposes its section layout.
package.path=(TEST_ROOT or 'modkit/SceneZOI_93C44199/workspace/lua/')..'B1/?.lua;'..package.path
package.loaded['SceneZOI.Diagnostics']={record=function()end}
package.loaded['SceneZOI.ClothingCoverage']={compatible_body=function()return true end,original_visibility=function()end}
package.loaded['SceneZOI.Profiles']={material=function()return {
    source_material=17,source_skin_parameter='SkinTone Color',source_chromophore_parameter='Chromophore Contribution',
    source_hair_parameter='TipColor',skin_slot='Skin',hair_slot='Hair',skin_parameter='SkinTint',
    chromophore_parameter='SkinChromophore',hair_parameter='HairColor'}end}
local assets,skeleton={},{}
local MID={}
local function array(value)return {ToTable=function()return value end}end
local function material(dynamic,tone)
    local value={dynamic=dynamic,parameters={['SkinTone Color']={R=tone or .3,G=.2,B=.1},
        ['Chromophore Contribution']={R=.3,G=.2,B=.1}},writes=0}
    function value:IsA(class)assert(class==MID);return self.dynamic end
    function value:K2_GetVectorParameterValue(name)return self.parameters[name]end
    function value:SetVectorParameterValue(name,color)self.parameters[name]=color;self.writes=self.writes+1 end
    return value
end
local STATIC=material(false)
local function asset(path,slots)
    local materials={};for _,name in ipairs(slots)do materials[#materials+1]={MaterialSlotName=name,MaterialInterface=STATIC}end
    local value={path=path,slots=slots,Materials=array(materials),MorphTargets=array({})}
    function value:GetName()return self.path end
    function value:GetSkeleton()return skeleton end
    assets[path]=value;return value
end
local slots,target_slots={}, {'provider_extra'}
for i=1,32 do slots[i]='shader_body_shader'..i end
for i=32,1,-1 do target_slots[#target_slots+1]=slots[i]end
local SOURCE=asset('/Native/Body.Body',slots)
local CHOSEN=asset('/Provider/Body.Body',target_slots)
local NEXT=asset('/Provider/Next.Next',slots)
local function soft(path)
    local package,name=path:match('^(.*)%.([^%.]+)$')
    return {AssetPath={PackageName=package or 'None',AssetName=name or 'None'}}
end
UE={UObject={Load=function(path)return assets[path]end},FTransform=function()return {}end,
    USkeletalMeshComponent={StaticClass=function()return {}end},UMaterialInstanceDynamic={StaticClass=function()return MID end},
    FLinearColor=function(r,g,b,a)return {R=r,G=g,B=b,A=a}end}
local function component()
    local mesh={materials={},visibility={},instance={},changes=0}
    function mesh:SetSkeletalMeshAsset(value)
        self.asset=value;self.changes=self.changes+1
        -- Real native swaps can clear overrides back to the mesh's factory MIC.
        self.materials={};for i in ipairs(value.slots)do self.materials[i-1]=value.factory and value.factory[i-1]or STATIC end
    end
    function mesh:GetSkeletalMeshAsset()return self.asset end
    function mesh:GetMaterialSlotNames()return array(self.asset.slots)end
    function mesh:GetMaterialIndex(name)for i,n in ipairs(self.asset.slots)do if n==name then return i-1 end end;return -1 end
    function mesh:GetMaterial(index)return self.materials[index]end
    function mesh:SetMaterial(index,value)
        if self.fail_material then error('injected keeper material failure')end
        self.materials[index]=value
    end
    function mesh:GetNumLODs()return 2 end
    function mesh:GetNumMaterials()return #self.asset.slots end
    function mesh:IsMaterialSectionShown(index,lod)
        return not self.visibility[index]or self.visibility[index][lod]~=false
    end
    function mesh:ShowMaterialSection(index,section,shown,lod)
        assert(index==section);self.visibility[index]=self.visibility[index]or {};self.visibility[index][lod]=shown
    end
    function mesh:GetAnimInstance()return self.instance end
    function mesh:SetPhysicsAsset(value)self.PhysicsAssetOverride=value end
    function mesh:SetHiddenInGame(hidden)self.hidden=hidden end
    function mesh:SetCollisionEnabled()end
    function mesh:SetGenerateOverlapEvents()end
    function mesh:SetSimulatePhysics()end
    function mesh:SetComponentTickEnabled()end
    function mesh:K2_DestroyComponent()self.destroyed=true;self.asset=nil;self.materials={}end
    return mesh
end
local function fixture()
    local mesh=component();mesh:SetSkeletalMeshAsset(SOURCE)
    local entry_mid=material(true)
    mesh:SetMaterial(17,entry_mid)
    local actor={Mesh=mesh,keepers={},AppearanceComponent={AppearanceSetting={
        Body={OverrideMesh=soft(''),bUseMeshMerge=false},
        FinalBody={OverrideMesh=soft(''),bUseMeshMerge=false,BodyData={BodyMesh=soft(SOURCE.path)}}}}}
    function actor:AddComponentByClass()
        local keeper=component();self.keepers[#self.keepers+1]=keeper;return keeper
    end
    local participant={id='male',role='male',actor=actor}
    local scene={participants={participant},node={id='example.scene',_body_variants={male={id='example.body',mesh=CHOSEN.path}}}}
    local attachment_mesh={materials={[0]=STATIC,[1]=STATIC},created=0}
    function attachment_mesh:GetMaterialIndex(name)return name=='Skin'and 0 or name=='Hair'and 1 or -1 end
    function attachment_mesh:GetMaterial(index)return self.materials[index]end
    function attachment_mesh:CreateDynamicMaterialInstance(index,source)
        assert(source==self.materials[index]);self.created=self.created+1
        local mid=material(true);self.materials[index]=mid;return mid
    end
    return scene,participant,mesh,entry_mid,{actor=actor,component=attachment_mesh},{mesh=mesh}
end
local Body=require('SceneZOI.TemporaryBody')
local Color=require('SceneZOI.MaterialMatch')
for _,handoff in ipairs({'guard','prepare','restore','next_variant'})do
    local scene,participant,mesh,entry_mid,attachment,body=fixture()
    assert(not Body.prepare(scene)and mesh.asset==CHOSEN)
    assert(scene.temporary_bodies.male.original.keeper:GetMaterial(17)==entry_mid)
    -- An outfit rebuild publishes the native mesh/slots before its final skin.
    mesh:SetSkeletalMeshAsset(SOURCE)
    assert(not Body.guard(scene)and not Body.prepare(scene)and mesh.asset==CHOSEN)
    local original=scene.temporary_bodies.male.original
    assert(original.slots[slots[18]].material==STATIC and original.keeper:GetMaterial(17)==STATIC)
    -- The native builder finishes asynchronously on the same main component,
    -- now displaying our chosen mesh. Hidden native slots can stay static.
    local late_mid=material(true,.47)
    local selected_slot=mesh:GetMaterialIndex(slots[18])
    mesh:SetMaterial(selected_slot,late_mid)
    local extra=material(true,.8);mesh:SetMaterial(0,extra)
    if handoff=='guard'then
        original.keeper.fail_material=true
        assert(not pcall(Body.guard,scene),'A failed native keeper write must remain retryable')
        assert(original.slots[slots[18]].material==STATIC and original.keeper:GetMaterial(17)==STATIC,
            'Do not publish a new Lua snapshot until an engine owner has retained that material')
        original.keeper.fail_material=false
        assert(Body.guard(scene))
    elseif handoff=='prepare'then assert(Body.prepare(scene))
    elseif handoff=='next_variant'then
        scene.node._body_variants.male={id='example.next',mesh=NEXT.path}
        assert(not Body.prepare(scene)and mesh:GetMaterial(17)==late_mid,
            'Switching variants discarded a late native skin MID')
    end
    if handoff~='restore'then
        assert(original.slots[slots[18]].material==late_mid and original.keeper:GetMaterial(17)==late_mid,
            'The asynchronous native skin MID must replace the early MIC snapshot and gain an engine GC owner')
        assert(original.slots[slots[1]].material==STATIC and original.keeper:GetMaterial(0)==STATIC,
            'Provider-only slots must never contaminate a native material with the same numeric index')
    end
    if handoff=='restore'then Body.restore(scene)
    else scene.node._body_variants={};assert(not Body.prepare(scene));assert(Body.prepare(scene))end
    assert(mesh.asset==SOURCE and mesh:GetMaterial(17)==late_mid,
        'Returning to native geometry must preserve the finished native skin instead of restoring a factory MIC')
    assert(original.keeper.destroyed and mesh:GetMaterial(0)==STATIC)
    assert(not Color.ready(attachment,body,'example.colors')and Color.ready(attachment,body,'example.colors'),
        'A retained unanimated attachment must still finish real material matching after native-body return')
    assert(attachment.color.body_material==late_mid and attachment.color.skin.parameters.SkinTint.R==.47)
    assert(late_mid.writes==0 and entry_mid.writes==0,'Native skin materials must only be borrowed, never modified')
end

-- A static/nil transient never replaces a finished native MID. The original
-- remains usable if the user immediately clears the body selection or Exits.
for _,transient in ipairs({'static','missing'})do
    local scene,_,mesh,entry_mid=fixture()
    assert(not Body.prepare(scene))
    local slot=mesh:GetMaterialIndex(slots[18])
    mesh:SetMaterial(slot,transient=='static'and STATIC or nil)
    assert(Body.guard(scene))
    Body.restore(scene)
    assert(mesh:GetMaterial(17)==entry_mid,'A transient static/missing material overwrote the finished native skin')
end

-- A failed skin installation must not adopt a provider's authored MID. That
-- differs from a later native publication on an already native-skinned renderer.
do
    local scene,_,mesh,entry_mid=fixture()
    CHOSEN.factory={};for i,name in ipairs(CHOSEN.slots)do
        if name==slots[18]then CHOSEN.factory[i-1]=material(true,.9)end
    end
    mesh.fail_material=true
    assert(not pcall(Body.prepare,scene)and mesh.asset==CHOSEN)
    mesh.fail_material=false
    Body.restore(scene)
    assert(mesh.asset==SOURCE and mesh:GetMaterial(17)==entry_mid,
        'An authored provider MID became the native baseline after a partial skin installation')
    CHOSEN.factory=nil
end
print('Temporary body material regression passed: native delayed MIDs, named slots, keeper ownership, guard/prepare/rapid return, variant navigation and retained attachment matching.')

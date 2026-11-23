local root=TEST_ROOT or 'modkit/SceneZOI_93C44199/workspace/lua/'
package.path=root..'B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local events={}
package.loaded['SceneZOI.Diagnostics']={record=function(name,fields)
 events[#events+1]={name=name,fields=V.copy(fields)}
end}
local stock='/Test/StockPatch.StockPatch'
local fitted='/Test/FittedPatch.FittedPatch'
local body_path='/ExampleBody/Mesh/Body.Body'
local missing_body='/OptionalBody/Mesh/Body.Body'
local source={GetName=function()return 'Body'end}
local native={GetName=function()return 'Body'end}
local assets={[stock]={},[fitted]={},[body_path]=source}
local loads={}
UE={UObject={Load=function(path)loads[path]=(loads[path]or 0)+1;return assets[path]end},
 FTransform=function()return {}end,USkeletalMeshComponent={StaticClass=function()return {}end},
 FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,
 UKismetMathLibrary={TransformLocation=function(t)return t end}}
local profile={schema_version=2,id='example.region',section=17,coverage_bit=17,
 patch_mesh=stock,patch_material_slot='shader_body_shader18',morph='Body_Muscle',
 patch_mesh_overrides={[body_path]=fitted,[missing_body]=fitted}}
require('SceneZOI.Profiles').set({body={['example.region']=profile},material={},rules={}})
local Body=require('SceneZOI.BodyRegion')
local created,destroyed=0,0
local function mesh(asset)
 local m={asset=asset,material={},visibility={[0]=true,[1]=false,[2]=true,[3]=true}}
 function m:GetSkeletalMeshAsset()return self.asset end
 function m:GetNumMaterials()return 32 end
 function m:GetNumLODs()return 4 end
 function m:GetMaterial(slot)assert(slot==17);return self.material end
 function m:GetMorphTarget(name)assert(name=='Body_Muscle');return .21 end
 function m:IsMaterialSectionShown(slot,lod)assert(slot==17);return self.visibility[lod]end
 function m:ShowMaterialSection(slot,section,shown,lod)assert(slot==17 and section==17);self.visibility[lod]=shown end
 function m:GetSocketTransform()return {X=0,Y=0,Z=0}end
 return m
end
local function fixture(asset)
 local actor={Mesh=mesh(asset)}
 actor.AppearanceComponent={AppearanceSetting={Body={bUseMeshMerge=false},FinalBody={bUseMeshMerge=false}}}
 function actor.AppearanceComponent:RefreshAll()self.refreshes=(self.refreshes or 0)+1 end
 function actor:AddComponentByClass()
  created=created+1
  local p={materials={},visibility={}}
  function p:SetHiddenInGame(value)self.hidden=value end
  function p:SetCollisionEnabled(value)assert(value==0)end
  function p:SetGenerateOverlapEvents(value)assert(not value)end
  function p:SetSimulatePhysics(value)assert(not value)end
  function p:SetSkeletalMeshAsset(value)self.asset=value end
  function p:GetMaterialIndex(name)assert(name=='shader_body_shader18');return 17 end
  function p:K2_AttachToComponent(parent,socket)self.parent=parent;assert(socket=='None');return true end
  function p:K2_SetRelativeTransform()end
  function p:SetLeaderPoseComponent(parent)assert(parent==self.parent)end
  function p:AddTickPrerequisiteComponent(parent)assert(parent==self.parent)end
  function p:SetMaterial(slot,value)self.materials[slot]=value end
  function p:GetMaterial(slot)return self.materials[slot]end
  function p:GetNumMaterials()return 32 end
  function p:GetNumLODs()return 4 end
  function p:ShowMaterialSection(slot,section,shown,lod)assert(slot==section);self.visibility[lod..':'..slot]=shown end
  function p:SetMorphTarget(name,value)assert(name=='Body_Muscle'and value==.21)end
  function p:PrestreamTextures()end
  function p:GetNumBones()return 365 end
  function p:GetSocketTransform()return {X=0,Y=0,Z=0}end
  function p:K2_DestroyComponent(owner)
   assert(owner==actor)
   if self.fail_destroy_once then self.fail_destroy_once=false;error('retry destruction')end
   assert(not self.destroyed,'A patch must be destroyed only once')
   self.destroyed=true;destroyed=destroyed+1
  end
  return p
 end
 local s={node={id='example.scene',attachment={body_profile='example.region',participant='lead'}},patch_asset=assets[stock]}
 return actor,s
end
local function prepare(actor,s)
 for _=1,8 do if Body.prepare(s,actor)then return end end
 error('Body did not prepare')
end
local function ready(s)
 for _=1,8 do if Body.ready(s)then return end end
 error('Body did not become ready')
end
local function original(m)
 assert(m.visibility[0]and not m.visibility[1]and m.visibility[2]and m.visibility[3],
  'The source body must regain its original visibility on every LOD')
end
local function hidden(m)for lod=0,3 do assert(not m.visibility[lod])end end

-- Stock and a fitted replacement coexist without sharing selection or resources.
local a,s=fixture(native);local b,t=fixture(source)
prepare(a,s);prepare(b,t);ready(s);ready(t)
assert(s.body_region.patch.asset==assets[stock]and t.body_region.patch.asset==assets[fitted])
assert(s.body_region.patch_selection.reason=='default_unlisted_body')
assert(t.body_region.patch_selection.matched_source==body_path)
hidden(a.Mesh);hidden(b.Mesh)
assert(Body.status(t):find('patch_selection=body_mesh_override',1,true))
assert(Body.status(t):find(body_path,1,true),'Preparation diagnostics must identify the exact matched body')
assert(loads[missing_body]==1,'Absent optional body mods must not be probed repeatedly')
local count=loads[body_path]
for _=1,10 do assert(Body.prepare(s,a)and Body.prepare(t,b));Body.guard(s);Body.guard(t)end
assert(loads[body_path]==count,'Settled patches must not perform per-frame asset matching')
local unrelated={GetName=function()return 'AnotherBody'end}
local _,unrelated_selection=Body.load('example.region',unrelated)
assert(unrelated_selection.reason=='default_unlisted_body'and loads[body_path]==count,
 'A different canonical object name must not force large unrelated body assets to load')
Body.restore(s);original(a.Mesh);assert(not t.body_region.patch.destroyed)
Body.restore(t);original(b.Mesh)

-- A clothing rebuild uses the actual new body, not a name or the prior match.
a,s=fixture(native);prepare(a,s);ready(s)
local previous_mesh,previous_patch=a.Mesh,s.body_region.patch
a.Mesh=mesh(source)
Body.guard(s) -- Native appearance may reset visibility before prepare sees it.
prepare(a,s);ready(s)
assert(previous_patch.destroyed and s.body_region.patch.asset==assets[fitted])
assert(s.body_region.patch_selection.reason=='body_mesh_override')
local fitted_patch=s.body_region.patch
a.Mesh=mesh(native);Body.guard(s);prepare(a,s);ready(s)
assert(fitted_patch.destroyed and s.body_region.patch.asset==assets[stock])
Body.restore(s);original(a.Mesh);original(previous_mesh)

-- The same native component can receive a different skeletal mesh asset.
a,s=fixture(source);prepare(a,s);ready(s)
previous_patch=s.body_region.patch
a.Mesh.asset=native;a.Mesh.visibility={[0]=true,[1]=false,[2]=true,[3]=true}
Body.guard(s);prepare(a,s);ready(s)
assert(previous_patch.destroyed and s.body_region.patch.asset==assets[stock])
Body.restore(s);original(a.Mesh)

-- A required fitted mesh cannot silently become the stock fallback. Even after
-- an incoming guard has hidden the body, failure/Exit releases all owned masks.
a,s=fixture(native);prepare(a,s);ready(s)
previous_mesh,previous_patch=a.Mesh,s.body_region.patch
a.Mesh=mesh(source);Body.guard(s);assets[fitted]=nil
local ok,err=pcall(prepare,a,s)
assert(not ok and tostring(err):find(fitted,1,true))
assert(previous_patch.destroyed and not s.body_region.patch)
Body.restore(s);original(a.Mesh);original(previous_mesh)
assert(events[#events].name=='body_patch_unavailable'and events[#events].fields.patch_mesh==fitted)
assets[fitted]={}

-- A failed old-component destruction keeps ownership for the existing retry.
a,s=fixture(source);prepare(a,s);ready(s)
previous_mesh,previous_patch=a.Mesh,s.body_region.patch
previous_patch.fail_destroy_once=true;a.Mesh=mesh(native);Body.guard(s)
assert(not pcall(Body.prepare,s,a)and s.body_region.patch==previous_patch)
prepare(a,s);ready(s);Body.restore(s);original(a.Mesh);original(previous_mesh)

-- Profiles without variants retain the same default load path. Identity is
-- unavailable until a real body asset exists; no override work runs meanwhile.
local with_overrides=profile.patch_mesh_overrides;profile.patch_mesh_overrides=nil
local selected;local value;value,selected=Body.load('example.region',source)
assert(value==assets[stock]and selected.reason=='default_profile')
profile.patch_mesh_overrides=with_overrides
a,s=fixture(nil)
for _=1,5 do assert(not Body.prepare(s,a))end
assert(not s.body_region.patch);Body.restore(s)
assert(created==destroyed,'Patch selection, failure and body rebuilds leaked a component')

-- Asset identity also catches two redirected paths that target the same body:
-- a conflicting fit is invalid rather than depending on map iteration order.
local alias='/Alias/Body.Body';assets[alias]=source;profile.patch_mesh_overrides[alias]=stock
assert(not pcall(Body.load,'example.region',source))
profile.patch_mesh_overrides[alias]=nil
local Validate=require('SceneZOI.ProfileData')
assert(pcall(Validate.validate_body,profile))
for _,value in ipairs({false,'a body name',{Body=fitted},{[body_path]='bad path'},{[body_path]=false}})do
 local p=V.copy(profile);p.patch_mesh_overrides=value
 assert(not pcall(Validate.validate_body,p),'Malformed patch override maps must be rejected')
end
local p=V.copy(profile);p.patch_mesh_overrides[body_path:lower()]=stock
assert(not pcall(Validate.validate_body,p),'Case-only duplicate Unreal paths are ambiguous')
print('Body patch selection passed: exact assets, stock fallback, concurrent owners, rebuild/swap/return, cached absence, missing fit, retry cleanup and schema validation.')

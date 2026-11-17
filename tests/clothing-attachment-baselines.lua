package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
package.loaded['SceneZOI.Diagnostics']={record=function()end}
local assets,skeleton={},{}
local function array(v)return {ToTable=function()return v end}end
local function soft(path)
 local package,name=path:match('^(.*)%.([^%.]+)$')
 return {AssetPath={PackageName=package or'None',AssetName=name or'None'}}
end
local function asset(path)
 local a={path=path,Materials={},MorphTargets=array({}),PhysicsAsset={}}
 for i=1,32 do a.Materials[i]={MaterialSlotName='part'..i}end
 a.Materials=array(a.Materials)
 function a:GetName()return self.path end
 function a:GetSkeleton()return skeleton end
 assets[path]=a;return a
end
local native=asset('/Native/Body.Body')
local stock=asset('/Provider/StockCoveragePatch.StockCoveragePatch')
UE={UObject={Load=function(path)return assets[path]end},FTransform=function()return {}end,
 USkeletalMeshComponent={StaticClass=function()return {}end}}
local Profiles=require('SceneZOI.Profiles')
Profiles.set({body={test={section=17,coverage_bit=17,full_coverage_exception=true}},material={},rules={}})
local Coverage=require('SceneZOI.ClothingCoverage')
local Body=require('SceneZOI.BodyRegion')
local TemporaryBody=require('SceneZOI.TemporaryBody')
local function noop()end
local unused={load=function()return {}end,prepare=function()return true end,ready=function()return true end,
 enter=noop,sample=noop,guard=noop,restore=noop,leave_node=noop,status=function()return 'ready'end}
for _,name in ipairs({'Gaze','Expressions','Sfx','Voices','VoiceResponses','CompletionEffects','TaskActions'})do
 package.loaded['SceneZOI.'..name]=unused
end
local Host=require('SceneZOI.Subsystems')

local function fixture(original)
 local states={[native]={},[stock]={}}
 for _,slots in pairs(states)do for section=0,31 do slots[section]={[0]=true,[1]=true}end end
 states[native][17]={[0]=original,[1]=original}
 local mesh={asset=native,instance={},materials={}}
 function mesh:GetSkeletalMeshAsset()return self.asset end
 function mesh:SetSkeletalMeshAsset(value)self.asset=value end
 function mesh:GetNumMaterials()return 32 end
 function mesh:GetNumLODs()return 2 end
 function mesh:GetMaterialSlotNames()
  local result={};for i=1,32 do result[i]='part'..i end;return array(result)
 end
 function mesh:GetMaterialIndex(name)return tonumber(name:match('^part(%d+)$'))-1 end
 function mesh:GetMaterial(index)self.materials[index]=self.materials[index]or{};return self.materials[index]end
 function mesh:SetMaterial(index,value)self.materials[index]=value end
 function mesh:IsMaterialSectionShown(section,lod)return states[self.asset][section][lod]end
 function mesh:ShowMaterialSection(material,section,shown,lod)assert(material==section);states[self.asset][section][lod]=shown end
 function mesh:GetAnimInstance()return self.instance end
 function mesh:SetPhysicsAsset(value)self.PhysicsAssetOverride=value end
 local garments={}
 local setting={Body={OverrideMesh=soft(''),bUseMeshMerge=false},FinalBody={OverrideMesh=soft(''),
  bUseMeshMerge=false,BodyData={BodyMesh=soft(native.path),bMergeBodyMesh=true}},
  FinalStyle={Outfit={Garments=array(garments)}}}
 local actor={Mesh=mesh,AppearanceComponent={AppearanceSetting=setting,RefreshAll=function()end},keepers={}}
 function actor:AddComponentByClass()
  local holder={SetHiddenInGame=function()end,SetCollisionEnabled=function()end,SetGenerateOverlapEvents=function()end,
   SetSimulatePhysics=function()end,SetComponentTickEnabled=function()end,SetMaterial=function()end}
  function holder:SetSkeletalMeshAsset(value)self.asset=value end
  function holder:GetSkeletalMeshAsset()return self.asset end
  function holder:K2_DestroyComponent()self.destroyed=true;self.asset=nil end
  self.keepers[#self.keepers+1]=holder;return holder
 end
 local person={id='one',role='lead',body='male',actor=actor,original_garments={},removed_slots={}}
 local scene={token='session',participants={person},bindings={lead=person},node={id='scene',_body_variants={}},retained_subsystems={}}
 scene.subsystems=Host.new(scene,{})
 local context={node={attachment={body_profile='test'}},scene_session=scene,coverage_owner=person}
 assert(Body.prepare(context,actor)==false)
 -- Supply provenance explicitly so the regression reaches the actual mask
 -- contamination on old code, rather than only failing a plumbing assertion.
 context.body_region.scene_session,context.body_region.coverage_owner=scene,person
 context.body_region.coverage_committed=true
 local item={owner_id=person.id,context=context,engine={id='attachment'}}
 scene.subsystems.items={item};scene.subsystems.retained.region=item
 return scene,person,mesh,garments,context,states,item
end

for _,original in ipairs({true,false})do
 local scene,p,mesh,garments,context,states,item=fixture(original)
 Coverage.guard(scene);Body.guard(context)
 assert(not mesh:IsMaterialSectionShown(17,0))
 -- The retained attachment starts naked, then clothing owns the same hidden
 -- section before a stock body is selected on the already-playing scene.
 garments.Bottom={BodyFlags=(1<<17)|(1<<20)|(1<<26)}
 Coverage.guard(scene);Body.guard(context)
 scene.node._body_variants.lead={id='test.stock',mesh=stock.path}
 assert(not TemporaryBody.prepare(scene)and mesh.asset==stock)
 Coverage.guard(scene);Body.guard(context)
 local captured=context.body_region.masked[#context.body_region.masked]
 assert(captured.asset==stock and captured.visibility[1].shown==original,
  'The retained attachment captured a clothing-owned false mask as the native stock-body baseline')
 garments.Bottom=nil
 Coverage.guard(scene);Body.guard(context)
 assert(not mesh:IsMaterialSectionShown(17,0),'The active attachment still owns its region after undressing')
 Body.restore(context);item.restored=true
 assert(mesh:IsMaterialSectionShown(17,0)==original and mesh:IsMaterialSectionShown(17,1)==original,
  'Attachment removal after redress/body-swap/undress left the native region hidden')
 scene.stopping=true;Coverage.restore(scene);TemporaryBody.restore(scene)
 assert(mesh.asset==native and mesh:IsMaterialSectionShown(17,0)==original)
 assert(p.actor.keepers[1].destroyed,'Stock-cycle cleanup leaked its native body keeper')
end

-- Retiring a replacement while clothing still covers it must not expose the
-- native region, even though the underlying body baseline is correctly true.
local scene,p,mesh,garments,context,states,item=fixture(true)
Coverage.guard(scene);Body.guard(context)
garments.Bottom={BodyFlags=1<<17};Coverage.guard(scene);Body.guard(context)
Body.restore(context);item.restored=true
assert(not mesh:IsMaterialSectionShown(17,0)and not mesh:IsMaterialSectionShown(17,1),
 'Retiring the attachment exposed a region that clothing still owns')
garments.Bottom=nil;Coverage.guard(scene)
assert(mesh:IsMaterialSectionShown(17,0),'Removing the remaining garment did not release its own mask')
scene.stopping=true;Coverage.restore(scene)

-- The attachment adapter must provide that provenance in ordinary runtime
-- preparation, before the body adapter takes its first snapshot.
local wiring,owner=fixture(true)
wiring.retained_subsystems={}
wiring.node={id='wiring',kind='loop',duration=3,anchor_participant='lead',tracks={lead='body'},
 participants={lead={body='male'}},attachments={replacement={participant='lead',mesh='attachment',socket='pelvis',
  reference_bone='pelvis',body_profile='test',retain_for_session=true}}}
local Attachment=require('SceneZOI.Attachment')
local original_load,original_prepare=Attachment.load,Attachment.prepare
Attachment.load=function()return {},nil,nil end
Attachment.prepare=function(adapter,actor)
 assert(adapter.scene_session==wiring and adapter.coverage_owner==owner,
  'Attachment preparation did not forward its session and coverage owner')
 return Body.prepare(adapter,actor)
end
local loaded=Host.load(wiring.node,3,wiring)
for i=#loaded,1,-1 do if loaded[i].engine.id~='attachment'then table.remove(loaded,i)end end
wiring.subsystems=Host.new(wiring,loaded)
assert(not wiring.subsystems:prepare(wiring))
local saved=wiring.subsystems.items[1].context.body_region
assert(saved.scene_session==wiring and saved.coverage_owner==owner)
Attachment.load,Attachment.prepare=original_load,original_prepare
print('Clothing/attachment baselines passed: retained replacement, redress, stock-body selection, undress, attachment removal, independent hidden baseline and covered retirement.')

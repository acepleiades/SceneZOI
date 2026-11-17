package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local diagnostics={}
package.loaded['SceneZOI.Diagnostics']={record=function(kind,fields)diagnostics[#diagnostics+1]={kind=kind,fields=fields}end}
local assets={}
UE={UObject={Load=function(path)return assets[path]end}}
local function array(values)return {ToTable=function()return values end}end
local function soft(path)
 local package,name=path:match('^(.*)%.([^%.]+)$')
 return {AssetPath={PackageName=package or'None',AssetName=name or'None'}}
end
local names={};for i=1,32 do names[i]='native_region_'..i end
local function asset(path,slots)
 local materials={};for i,name in ipairs(slots)do materials[i]={MaterialSlotName=name}end
 local a={Materials=array(materials),slots=slots}
 function a:GetName()return path end
 assets[path]=a;return a
end
local native=asset('/Native/Body.Body',names)
local reversed={};for i=1,32 do reversed[i]=names[33-i]end
local custom=asset('/Provider/Body.Body',reversed)
local collapsed=asset('/Transient/Merged.Merged',{names[11]})
local duplicate_slots={};for i,name in ipairs(names)do duplicate_slots[i]=name end;duplicate_slots[33]=names[1]
local duplicate=asset('/Provider/Duplicate.Duplicate',duplicate_slots)
local function fixture(id)
 local states={}
 local mesh={asset=native,writes={},reads=0}
 function mesh:GetSkeletalMeshAsset()return self.asset end
 function mesh:GetNumMaterials()return #self.asset.slots end
 function mesh:GetNumLODs()return 2 end
 function mesh:GetMaterialIndex(name)for i,value in ipairs(self.asset.slots)do if value==name then return i-1 end end;return -1 end
 function mesh:IsMaterialSectionShown(section,lod)
  states[self.asset]=states[self.asset]or{}
  states[self.asset][section]=states[self.asset][section]or{[0]=true,[1]=true}
  return states[self.asset][section][lod]
 end
 function mesh:ShowMaterialSection(material,section,shown,lod)
  assert(material==section and section>=0 and section<#self.asset.slots)
  if shown and self.fail_restore==section and lod==1 then error('restore not ready')end
  self:IsMaterialSectionShown(section,lod)
  states[self.asset][section][lod]=shown
  self.writes[#self.writes+1]={asset=self.asset,section=section,lod=lod,shown=shown}
 end
 local garments={}
 local map={ToTable=function()mesh.reads=mesh.reads+1;return garments end}
 local setting={Body={bUseMeshMerge=false},FinalBody={bUseMeshMerge=false,OverrideMesh=soft(''),
  BodyData={BodyMesh=soft('/Native/Body.Body'),bMergeBodyMesh=true}},FinalStyle={Outfit={Garments=map}}}
 local person={id=id or'one',role='lead',actor={Mesh=mesh,AppearanceComponent={AppearanceSetting=setting}}}
 local current={token='session',participants={person},node={id='hub'},preparing=true}
 return current,person,mesh,garments,setting,states
end
local C=require('SceneZOI.ClothingCoverage')
local scene,p,mesh,garments,setting=fixture()
-- This is a clothed hub with no instantiated attachment. All native sections
-- begin visible after unmerging; pants/top masks must cover more than Crotch.
local mask=(1<<15)|(1<<20)|(1<<26)|(1<<17)
garments.Bottom={BodyFlags=(1<<20)|(1<<26)|(1<<17),CoveredFlags=0}
garments.Top={BodyFlags=1<<15,CoveredFlags=0xffffffff}
mesh:ShowMaterialSection(4,4,false,0)
local before=mesh.reads
assert(C.guard(scene)and mesh.reads==before+1,'Resolved garments must be read once per participant guard')
for _,section in ipairs({15,17,20,26})do for lod=0,1 do assert(not mesh:IsMaterialSectionShown(section,lod))end end
assert(mesh:IsMaterialSectionShown(0,0)and not mesh:IsMaterialSectionShown(4,0),'Unrelated regions changed')
local originals=C.original_visibility(scene,p,mesh,native)
assert(originals[15][0]and originals[20][1])
originals[15][0]=false
assert(C.original_visibility(scene,p,mesh,native)[15][0],'Visibility inspection must return copies')
assert(not C.original_visibility(scene,{id='other'},mesh,native)and not C.original_visibility(scene,p,{},native)
 and not C.original_visibility(scene,p,mesh,custom),'Snapshots cannot cross owners, components or assets')
-- Native refresh can reset masks on the same component/asset.
mesh:ShowMaterialSection(20,20,true,1);assert(C.guard(scene)and not mesh:IsMaterialSectionShown(20,1))
garments.Bottom=nil;assert(C.guard(scene))
for _,section in ipairs({17,20,26})do for lod=0,1 do assert(mesh:IsMaterialSectionShown(section,lod))end end
assert(not mesh:IsMaterialSectionShown(15,0)and not mesh:IsMaterialSectionShown(4,0))
garments.Top=nil;assert(C.guard(scene)and mesh:IsMaterialSectionShown(15,0))
assert(not C.original_visibility(scene,p,mesh,native),'Released mask snapshots are not authoritative')

-- Signed native bitmasks and normalized underwear/custom garment slots count.
garments.NormalizedUnderwear={BodyFlags=-1}
assert(C.guard(scene))
for region=0,31 do assert(mesh:IsMaterialSectionShown(region,0)==(region==17))end
garments.NormalizedUnderwear=nil;assert(C.guard(scene))
assert(not mesh:IsMaterialSectionShown(4,0),'An initially hidden independent section was exposed')

-- A reordered body variant is mapped by native slot name, never current index.
garments.CustomOutfitSlot={BodyFlags=mask}
mesh.asset=custom
assert(C.compatible_body(p.actor,custom)and C.guard(scene))
for _,region in ipairs({15,17,20,26})do
 local slot=mesh:GetMaterialIndex(names[region+1]);assert(not mesh:IsMaterialSectionShown(slot,0))
end
assert(mesh:IsMaterialSectionShown(mesh:GetMaterialIndex(names[1]),0))
local writes=#mesh.writes
mesh.asset=native;C.restore(scene)
assert(scene.clothing_coverage.restored and mesh:IsMaterialSectionShown(15,0))
for i=writes+1,#mesh.writes do assert(mesh.writes[i].asset==native,'Cleanup replayed a retired asset mask')end

-- A retained attachment mask is not the original native baseline. A genuine
-- initially-hidden region stays hidden when the garment is removed.
for _,original in ipairs({true,false})do
 local s,person,m,g=fixture('layered')
 m:ShowMaterialSection(17,17,false,0);m:ShowMaterialSection(17,17,false,1)
 s.subsystems={body_visibility=function(_,owner,component,body)
  assert(owner==person and component==m and body==native)
  return {[17]={[0]=original,[1]=original}}
 end}
 g.Bottom={BodyFlags=1<<17};assert(C.guard(s))
 assert(C.original_visibility(s,person,m,native)[17][0]==original)
 g.Bottom=nil;assert(C.guard(s)and m:IsMaterialSectionShown(17,0)==original)
 -- The parent's subsequent subsystem guard reasserts the still-owned attachment.
 m:ShowMaterialSection(17,17,false,0)
 assert(not m:IsMaterialSectionShown(17,0))
end

-- Ordinary merged bodies are untouched. While an acknowledged unmerge is still
-- displaying a collapsed mesh, preparation waits without a spurious warning.
local s,person,m,g,config=fixture('pending');m.asset=collapsed;g.Top={BodyFlags=1}
config.Body.bUseMeshMerge,config.FinalBody.bUseMeshMerge=true,true
assert(C.guard(s)and #m.writes==0)
config.Body.bUseMeshMerge,config.FinalBody.bUseMeshMerge=false,false
local count=#diagnostics
assert(not C.guard(s)and #m.writes==0 and #diagnostics==count)
m.asset=native;assert(C.guard(s)and not m:IsMaterialSectionShown(0,0))
assert(not C.compatible_body(person.actor,collapsed),'A one-slot replacement cannot safely map native region flags')
assert(not C.compatible_body(person.actor,duplicate),'Duplicate native slots make coverage ambiguous')
m.asset=collapsed;s.preparing=false
assert(not C.guard(s));count=#diagnostics;assert(not C.guard(s)and #diagnostics==count,'Unknown target warnings must be deduplicated')

-- A truly unrelated native body convention is left unchanged with a warning,
-- rather than causing indefinite preparation or hiding an entire foreign mesh.
local unknown=asset('/Foreign/Body.Body',{'skin'})
config.FinalBody.BodyData.BodyMesh=soft('/Foreign/Body.Body');m.asset=unknown;s.preparing=true
assert(C.guard(s)and #m.writes==2,'Unsupported native layouts must not be edited')
assert(not C.compatible_body(person.actor,custom))

-- Cleanup retries partial failure, skips a stale asset, and respects a later
-- visible write instead of forcing an older hidden snapshot back onto it.
local cleanup,owner,body,outfit=fixture('cleanup')
outfit.Top={BodyFlags=(1<<15)|(1<<20)};assert(C.guard(cleanup))
body.fail_restore=20
assert(not pcall(C.restore,cleanup)and not cleanup.clothing_coverage.restored)
body.fail_restore=nil;C.restore(cleanup)
assert(body:IsMaterialSectionShown(15,1)and body:IsMaterialSectionShown(20,1))
assert(not C.original_visibility(cleanup,owner,body,native))
local external,ep,em,eg=fixture('external')
em:ShowMaterialSection(15,15,false,0);eg.Top={BodyFlags=1<<15};C.guard(external)
em:ShowMaterialSection(15,15,true,0);C.restore(external)
assert(em:IsMaterialSectionShown(15,0),'A later visible write must win')
print('Clothing coverage passed: clothed hubs, multi-region native flags, all LODs, removal/redress, native/custom remap, layered masks, pending layouts and retryable cleanup.')

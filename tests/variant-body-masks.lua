package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Body=require('SceneZOI.BodyRegion')
local native,custom={},{}
local states={
 [native]={[5]={[0]=true,[1]=false},[6]={[0]=false,[1]=true}},
 [custom]={[5]={[0]=false,[1]=true},[6]={[0]=true,[1]=false}},
}
local asset=native
local writes={}
local mesh={GetSkeletalMeshAsset=function()return asset end,GetNumMaterials=function()return 8 end,
 GetNumLODs=function()return 2 end,
 IsMaterialSectionShown=function(_,section,lod)return states[asset][section][lod]end,
 ShowMaterialSection=function(_,material,section,shown,lod)
  assert(material==section);states[asset][section][lod]=shown
  writes[#writes+1]={asset=asset,section=section,lod=lod,shown=shown}
 end}
local setting={Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=true}}
local actor={Mesh=mesh,AppearanceComponent={AppearanceSetting=setting}}
local function provider(section)
 setting.Body.bUseMeshMerge,setting.FinalBody.bUseMeshMerge=false,false
 return {body_region={actor=actor,profile={section=section},coverage_committed=true,base_merge=true,final_merge=true}}
end

-- A rebuilt component can keep its identity while switching its skeletal asset.
local old=provider(5);Body.guard(old)
assert(not states[native][5][0]and not states[native][5][1])
local Host=require('SceneZOI.Subsystems')
local person={id='one',role='lead',actor=actor}
local current={participants={person},retained_subsystems={}}
local host=Host.new(current,{})
local item={owner_id=person.id,context=old,engine={id='attachment'}}
host.items={item};host.retained.region=item
local visibility=host:body_visibility(person,mesh,native)
assert(visibility[5][0]and visibility[5][1]==false and not visibility[6],
 'Whole-body capture must recover original section masks hidden by an existing provider')
visibility[5][0]=false
assert(host:body_visibility(person,mesh,native)[5][0], 'Visibility reads must return independent copies')
assert(not host:body_visibility({id='other'},mesh,native)and not host:body_visibility(person,{},native)
 and not host:body_visibility(person,mesh,custom),'Snapshots cannot cross participant, component or asset identity')
host.items={}
assert(host:body_visibility(person,mesh,native)[5][0], 'Session-retained providers still own their original mask snapshot')
item.restored=true
assert(not host:body_visibility(person,mesh,native),'A retired provider cannot supply a stale baseline')
item.restored=nil
asset=custom
local count=#writes;Body.restore(old)
assert(#writes==count and not states[custom][5][0]and states[custom][5][1],
 'An old provider must not replay native-asset visibility onto the new custom asset')
assert(setting.Body.bUseMeshMerge and setting.FinalBody.bUseMeshMerge)
assert(not host:body_visibility(person,mesh,native),'Completed cleanup removes the old owned mask snapshot')

local next_provider=provider(6);Body.guard(next_provider)
assert(not states[custom][6][0]and not states[custom][6][1])
Body.restore(old)
assert(not states[custom][6][0],'Repeated old cleanup must not expose a region owned by the new provider')
Body.restore(next_provider)
assert(states[custom][6][0]and not states[custom][6][1])
assert(not states[custom][5][0]and states[custom][5][1],'Unrelated section masks must remain unchanged')

-- Returning to the original body captures its current native mask rather than
-- applying a snapshot retained by the former provider.
asset=native;states[native][5]={[0]=false,[1]=true}
local returned=provider(5);Body.guard(returned);Body.restore(returned)
assert(not states[native][5][0]and states[native][5][1])

-- Retirement precedes the next provider even if both use the same asset/section.
states[native][5]={[0]=true,[1]=false}
old=provider(5);Body.guard(old)
local fail=true
old.body_region.patch={K2_DestroyComponent=function()if fail then error('temporary destroy failure')end end}
assert(not pcall(Body.restore,old)and not states[native][5][0],
 'A failed patch cleanup retains its masked region for retry')
fail=false;Body.restore(old)
assert(states[native][5][0]and not states[native][5][1])
next_provider=provider(5);Body.guard(next_provider)
Body.restore(old);assert(not states[native][5][0])
Body.restore(next_provider);assert(states[native][5][0]and not states[native][5][1])
print('Variant body masks passed: native/custom/native asset changes, independent sections, no cross-provider restoration, retryable patch cleanup and idempotent retirement.')

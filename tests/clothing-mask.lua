package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Profiles=require('SceneZOI.Profiles')
local p={coverage_bit=5,section=5,full_coverage_exception=false}
Profiles.set({body={['designer.region']=p}})
local garments={Top={BodyFlags=0},Bottom={BodyFlags=1<<5}}
function garments:ToTable()local rows={};for k,v in pairs(self)do if type(v)=='table'then rows[k]=v end end;return rows end
local shown={[0]=true,[1]=true};local asset={GetName=function()return 'TestBody'end}
local mesh={GetSkeletalMeshAsset=function()return asset end,GetNumMaterials=function()return 8 end,
 GetNumLODs=function()return 2 end,GetMaterialIndex=function()error('Body material names must not be queried')end,
 IsMaterialSectionShown=function(_,section,lod)assert(section==5);return shown[lod]end,
 ShowMaterialSection=function(_,material,section,value,lod)assert(material==5 and section==5);shown[lod]=value end}
local actor={Mesh=mesh,AppearanceComponent={AppearanceSetting={FinalStyle={Outfit={Garments=garments}}}}}
local Body=require('SceneZOI.BodyRegion')
assert(Body.guard_clothing(actor,'designer.region')==2 and not shown[0]and not shown[1])
assert(Body.guard_clothing(actor,'designer.region')==0,'Idempotent guards must not rewrite hidden sections')
shown[0]=true;shown[1]=true;garments.Shoes={BodyFlags=1<<2}
assert(Body.guard_clothing(actor,'designer.region')==2,'Unrelated clothing edits must retain the remaining covering garment mask')
garments.Bottom=nil;shown[0]=true;shown[1]=false
assert(Body.guard_clothing(actor,'designer.region')==0 and shown[0]and not shown[1],'Removing coverage must not create a sticky hidden mask or expose another owner')
garments.CustomCoat={BodyFlags=1<<5};assert(Body.guard_clothing(actor,'designer.region')==1,'Coverage comes from flags, not garment categories')
shown[0]=true;local old=asset;asset={GetName=function()return 'OtherBody'end};assert(Body.guard_clothing(actor,'designer.region')==1 and not shown[0],'A renamed body with the same section convention must remain supported');asset=old;shown[0]=true
actor.Mesh=nil;assert(Body.guard_clothing(actor,'designer.region')==0,'An unavailable/rebuilding body must remain retryable');actor.Mesh=mesh
local Host=require('SceneZOI.Subsystems');local person={id='1',actor=actor,body='male',role='lead'}
local s={node={participants={lead={body='male'}},tracks={lead='animation'},anchor_participant='lead',attachments={test={participant='lead',body_profile='designer.region'}}},bindings={lead=person},participants={person}}
local host=Host.new(s,{});assert(#host.items==0,'Reproduce a covered body with no instantiated attachment')
host:guard();assert(not shown[0]and person.clothing_mask_repairs==1,'The host must repair clothing even when no attachment engine exists')
garments.CustomCoat=nil;shown[0]=true;host:guard();assert(shown[0],'The host must honor actual undressing')
s.bindings=nil;garments.Bottom={BodyFlags=1<<5};host:guard();assert(not shown[0],'Preparation before the first committed binding must still guard coverage')
print('Clothing-mask regression passed: data-defined section 5, all LODs, skipped attachment, unrelated/manual edits, custom slots, undressing, renamed/rebuilding mesh and independent hidden owners.')

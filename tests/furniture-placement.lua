package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local location={X=176000,Y=-82000,Z=300};local rotation={Pitch=0,Yaw=90,Roll=0};local scale={X=1,Y=1,Z=1}
local profile={id='author.futon',kind='bed.single',surface_height_cm=5,offset_cm={x=2,y=3,z=0},yaw_degrees=0}
local actor={ObjectDataTableId='Futon'}
function actor:GetTransform()return {Translation=V.copy(location),Scale3D=V.copy(scale)}end
function actor:K2_GetActorLocation()return location end
function actor:K2_GetActorRotation()return rotation end
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {furniture={objects={Futon=profile}}}end}
inzoi={FB1EntityId=function()return {}end,EB1ManagerType={Entity=1},UB1System={Get=function()return {ManagerMap={Find=function()return {GameObjectMap={Find=function(_,e)assert(e.Value==50);return actor end}}end}}end}}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FQuat=function(x,y,z,w)return {X=x,Y=y,Z=z,W=w}end,
 FTransform=function(...)assert(select('#',...)==0,'Reflected FTransform does not support the assumed positional constructor');return {}end,
 UKismetMathLibrary={TransformLocation=function(t,v)return {X=t.Translation.X-v.Y,Y=t.Translation.Y+v.X,Z=t.Translation.Z+v.Z}end}}
local F=require('SceneZOI.Furniture');local f=F.prepare('50',{furniture={kind='bed.single',surface_height_cm=45}})
assert(f.anchor.Translation.X==175997 and f.anchor.Translation.Y==-81998 and f.anchor.Translation.Z==260,'Apply furniture world position and authored-to-support offset exactly once')
assert(math.abs(f.anchor.Rotation.Z-math.sqrt(.5))<1e-9 and math.abs(f.anchor.Rotation.W-math.sqrt(.5))<1e-9 and f.anchor.Rotation.X==0 and f.anchor.Rotation.Y==0,'Anchor must be upright with furniture yaw')
local ground=F.prepare('50',{furniture={kind='bed.single',surface_height_cm=0}})
assert(ground.anchor.Translation.Z==305,'Ground-authored clips use the profile height directly')
assert(f.anchor.Scale3D.X==1 and F.valid(f));assert(f.original~=location,'Restoration/validation snapshot must hold plain independent coordinates')
location.X=location.X+1;assert(not F.valid(f));location.X=location.X-1;assert(F.valid(f))
scale.X=2;assert(not pcall(F.prepare,'50',{furniture={kind='bed.single',surface_height_cm=45}}));scale.X=1
rotation.Pitch=10;assert(not pcall(F.prepare,'50',{furniture={kind='bed.single',surface_height_cm=45}}))
print('Furniture placement passed: reflected default construction, explicit quaternion/translation/scale, realistic world coordinates, rotated offsets, low-bed height correction and independent numeric snapshot.')

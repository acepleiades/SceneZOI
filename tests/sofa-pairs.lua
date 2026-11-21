package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local D=require('SceneZOI.FurnitureData');local P=require('SceneZOI.Protocol');local Json=require('SceneZOI.Json')
local function spot(id,run,x,y,yaw)return {id=id,run=run,offset_cm={x=x,y=y,z=0},yaw_degrees=yaw,slots={{component_name='Seat_'..id,slot_name='Sit_'..id}}}end
local profile={schema_version=1,id='author.sofa',kind='sofa.pair',objects={'Sofa'},surface_height_cm=44,
 sitting_spots={spot('a','front',-120,0,0),spot('b','front',-40,0,0),spot('c','side',40,0,90),spot('d','side',40,80,90)},
 seat_pairs={{id='ab',spots={'a','b'}},{id='cd',spots={'c','d'}}}}
D.profile(profile)
local bad=V.copy(profile);bad.seat_pairs[1].spots={'b','c'};assert(not pcall(D.profile,bad),'Never join different straight runs/corner facings')
bad=V.copy(profile);bad.sitting_spots[2].slots=V.copy(bad.sitting_spots[1].slots);assert(not pcall(D.profile,bad),'Raw slot cannot stand for two physical seats')
bad=V.copy(profile);bad.sitting_spots[3]=spot('c','front',40,0,0);bad.seat_pairs={{id='ac',spots={'a','c'}}};assert(not pcall(D.profile,bad),'Pairs must be adjacent, not skip the middle seat')
bad=V.copy(profile);bad.seat_pairs[2].spots={'b','a'};assert(not pcall(D.profile,bad),'The reversed pair is the same pair')
local actor={ObjectDataTableId='Sofa',GetTransform=function()return {Scale3D={X=1,Y=1,Z=1},Translation={X=100,Y=200,Z=300}}end,
 K2_GetActorLocation=function()return {X=100,Y=200,Z=300}end,K2_GetActorRotation=function()return {Pitch=0,Yaw=90,Roll=0}end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {furniture={objects={Sofa=profile}}}end}
inzoi={FB1EntityId=function()return {}end,EB1ManagerType={Entity=1},UB1System={Get=function()return {ManagerMap={Find=function()return {GameObjectMap={Find=function()return actor end}}end}}end}}
UE={FVector=function(x,y,z)return {X=x,Y=y,Z=z}end,FQuat=function(x,y,z,w)return {X=x,Y=y,Z=z,W=w}end,FTransform=function()return {}end,
 UKismetMathLibrary={TransformLocation=function(t,v)return {X=t.Translation.X-v.Y,Y=t.Translation.Y+v.X,Z=t.Translation.Z+v.Z}end}}
local F=require('SceneZOI.Furniture');local Sessions=require('SceneZOI.Sessions');Sessions.reset()
F.reply(nil,P.pack('status','50','free',P.encode(Json.encode(Json.array({'ab','cd'})))))
local available,pair=F.available('50');assert(available and pair.id=='ab')
local a=F.prepare('50',{furniture={kind='sofa.pair',surface_height_cm=44}},'ab')
assert(a.anchor.Translation.X==100 and a.anchor.Translation.Y==120 and a.anchor.Translation.Z==300,'Root is the world-transformed pair midpoint with authored height removed once')
local b=F.prepare('50',{furniture={kind='sofa.pair',surface_height_cm=44}},'cd')
assert(b.anchor.Translation.X==60 and b.anchor.Translation.Y==240 and math.abs(b.anchor.Rotation.Z-1)<1e-9,'Second straight run uses its own midpoint and facing')
assert(a.selected_pair_id=='ab'and #a.spot_ids==2 and #a.slots==2)
assert(Sessions.reserve('first',{'1','2'},'50',a.spot_ids))
assert(Sessions.reserve('second',{'3','4'},'50',b.spot_ids),'Disjoint pairs can run on one four-seat sofa')
assert(not Sessions.reserve('overlap',{'5','6'},'50',{'b','c'}),'One overlapping seat is enough to reject a pair')
assert(not Sessions.reserve('whole',{'5','6'},'50'),'Whole-object reservations cannot bypass physical seat ownership')
Sessions.release('first');assert(F.available('50','ab')and not F.available('50','cd'),'Released pair is free while the other scene retains its seats')
Sessions.transfer('second','third');assert(Sessions.furniture_holder('50',{'c'})=='third')
Sessions.release('third');assert(F.available('50','cd'))
local Pair=require('SceneZOI.FurniturePairs');assert(Pair.same_slots(a.slots,{a.slots[2],a.slots[1]}),'Native ordering must not change captured slot identity')
F.reply(nil,P.pack('status','50','free',P.encode(Json.encode(Json.array({'cd'}))),P.encode(Json.encode({ab=Json.array({'1','2'})}))))
assert(not F.available('50','ab')and F.pickable('50'),'Occupied but ordinarily preparable seats may open the roster picker')
assert(F.available('50','ab',{'1','2'})and not F.available('50','ab',{'1','3'}),'Only the exact selected occupants may be cleared; a bystander blocks the pair')
F.reply(nil,P.pack('status','50','free',P.encode(Json.encode(Json.array({'cd'}))),P.encode(Json.encode({ab='invalid'}))))
assert(not F.available('50','ab',{'1','2'})and F.available('50','cd'),'Malformed preparation hints fail closed without hiding a valid spare pair')
print('Sofa pairs passed: physical adjacency and run validation, transformed midpoint/facing, disjoint/overlapping reservations and exact slot identity.')

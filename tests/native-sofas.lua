package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation')
local now,queries=100,0;os.time=function()return now end
local function native_array(rows)
 rows.Num=function(self)return rawlen(self)end
 return setmetatable(rows,{__len=function()error('Native TArray has no Lua length operator')end})
end
local function transform(x,y)return {Translation={X=x or 0,Y=y or 0,Z=0},Rotation={X=0,Y=0,Z=0,W=1}}end
local slots={}
local function add(name,x,tags,kind,age)
 slots[#slots+1]={ComponentName=name,SlotName=name,ParentComponentName='Mesh',ParentSlotName='None',ParentSocketName='None',
  RelativeTransform=transform(x,70),SlotComponentData={SlotType=kind or 1,InteractionSlot={BodyAge=age or 0,EnableOnlyInteractionTags=tags}}}
end
add('arbitraryA',45,{'Sit'});add('arbitraryB',-45,{'Sit'});add('passoutA',45,{'Sit_PassOut'})
add('prop',0,{},2);add('standingChild',0,{'Baby_Stand'},1,2)
local actor={ObjectDataTableId='ModAddedModel',RuntimeSlotInfos=native_array(slots)}
function actor:GetTransform()return transform()end
function actor:K2_GetComponentsByClass()return {{GetName=function()return'Mesh'end,K2_GetComponentToWorld=function()return transform()end}}end
inzoi={EB1SlotType={Interaction=1},EB1BodyAgeType={Default=0,Adult=1},cli={execute=function(command)
 queries=queries+1;assert(command=='data.table_get alias=Object row="ModAddedModel"')
 return true,'',J.encode({objectTags={'Object_Sofa'}})
end}}
UE={USceneComponent={StaticClass=function()return 1 end},UKismetMathLibrary={
 InvertTransform=function(t)return t end,ComposeTransforms=function(a)return a end}}
local log={};package.loaded['SceneZOI.Diagnostics']={record=function(_,fields)log[#log+1]=fields end}
local M=require('SceneZOI.NativeSofas')
assert(M.is_sofa({objectTags={'Object_Sofa'}})and M.is_sofa({filterCategory='Sofa'}))
assert(not M.is_sofa({displayName='Sofa',objectTags={'Seat'},filterCategory='Chair'}),'Translated names never classify furniture')
local p=assert(M.profile('90',actor));assert(#p.sitting_spots==2 and #p.seat_pairs==1)
assert(queries==1 and #log==1)
for _=1,100 do assert(M.profile('90',actor)==p)end
assert(queries==1 and #log==1,'Picker polling reuses metadata/layout without per-frame CLI calls or logs')
now=103;assert(M.profile('90',actor)and queries==1,'A layout refresh reuses the cached object row')
assert(M.peek('90',actor))
local count=0;local original=M.profile;M.profile=function()count=count+1 end
M.begin_scan({{id='1',actor=actor},{id='2',actor=actor},{id='3',actor=actor},{id='4',actor=actor},{id='5',actor=actor}})
M.tick();assert(count<=2 and count>0,'A city scan is bounded per render tick');M.tick();M.tick();assert(count==5)
now=114;M.tick();assert(M.scan_due(),'An empty queue must not postpone future discovery forever')
M.cache['1']={actor=actor,model=actor.ObjectDataTableId,slot_count=actor.RuntimeSlotInfos:Num(),background_retry=300}
count=0;M.begin_scan({{id='1',actor=actor}});M.tick()
assert(count==0,'Unchanged non-sofas use a cheap native-count check during background scans')
M.cache['1'].slot_count=-1;M.begin_scan({{id='1',actor=actor}});M.tick()
assert(count==1,'Native slot initialization/rebuild invalidates a negative discovery cache')
M.profile=original
M.prune({});assert(not next(M.cache)and not next(M.models)and not next(M.reported),'Unload drops object wrappers and model caches')
print('Native sofa discovery passed: semantic tags/category, native-array iteration, posture filtering, cached reads, bounded background work and unload cleanup.')

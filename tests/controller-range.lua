package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local R=require('SceneZOI.ControllerRange')
local limit=require('SceneZOI.Config').controller_max_distance_cm
local controlled='1'
local function actor(x,y,z)return {K2_GetActorLocation=function()return {X=x,Y=y or 0,Z=z or 0}end}end
local actors={['1']=actor(0),['2']=actor(0),['3']=actor(limit+1),['4']=actor(limit+1000)}
UE={UGameplayStatics={GetPlayerController=function(context)
 assert(context~=nil,'Never query with a released actor')
 return {GetCharacterEntityId=function()return {Value=controlled}end}
end}}
local current={participants={{id='1',actor=actors['1']},{id='2',actor=actors['2']}},node={anchor_participant='lead'},anchor={Translation={X=0,Y=0,Z=0}}}
for _,id in ipairs({'1','2'})do controlled=id;for _=1,10 do assert(not R.update(current,actors,.2))end end
controlled='3';for _=1,2 do assert(not R.update(current,actors,.2))end
controlled='2';assert(not R.update(current,actors,.2),'Participant control resets the grace timer')
controlled='3';for _=1,2 do assert(not R.update(current,actors,.2))end
local far,cm,id=R.update(current,actors,.2);assert(far and cm==limit+1 and id=='3')
actors['3']=actor(limit);for _=1,10 do assert(not R.update(current,actors,.2),'Boundary is inclusive')end
actors['3']=actor(0,limit*.6+1,limit*.8+1);for _=1,2 do assert(not R.update(current,actors,.2))end;assert(R.update(current,actors,.2),'Use 3D scene-anchor distance')
controlled='missing';assert(not R.update(current,actors,.2),'Unknown actor is not proof of distance')
current.anchor=nil;actors['3']=actor(limit+1);controlled='3';for _=1,2 do assert(not R.update(current,actors,.2))end;assert(R.update(current,actors,.2),'Initial preparation has a participant-origin fallback')
-- The anchor role need not be first, even before arriving bindings exist.
current.participants[1].role='other';current.participants[2].role='lead'
actors['2']=actor(limit);current.participants[2].actor=actors['2'];actors['3']=actor(limit+1)
for _=1,10 do assert(not R.update(current,actors,.2),'Preparation must measure from its declared anchor role, not roster order')end
actors['3']=actor(limit*2+1);for _=1,2 do assert(not R.update(current,actors,.2))end;assert(R.update(current,actors,.2))
local stale=actor(0);assert(R.focus_actor(actors,stale)~=stale and R.focus_actor({},stale)==nil)
assert(R.focus_actor(actors,actors['3'])==actors['3'])
UE.UGameplayStatics.GetPlayerController=function()error('Released native context')end
assert(not R.update(current,actors,.2),'Transient controller lookup must not fail the scene')
print('Controller range passed: live possession, participant swaps, nearby spectators, 3D threshold/grace, preparation, transient lookup and stale focus contexts.')

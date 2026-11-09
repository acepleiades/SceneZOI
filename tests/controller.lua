package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local R=require('SceneZOI.Controller')
local controlled='1'
local function actor()return {}end
local actors={['1']=actor(),['2']=actor()}
UE={UGameplayStatics={GetPlayerController=function(context)
 assert(context~=nil,'Never query with a released actor')
 return {GetCharacterEntityId=function()return {Value=controlled}end}
end}}
assert(R.controlled_id(actors)=='1');controlled='2';assert(R.controlled_id(actors)=='2','Possession is read live')
assert(R.controlled_id({})==nil,'No loaded actor means no answer')
local stale=actor();assert(R.focus_actor(actors,stale)~=stale and R.focus_actor({},stale)==nil)
assert(R.focus_actor(actors,actors['2'])==actors['2'])
UE.UGameplayStatics.GetPlayerController=function()return nil end
assert(R.controlled_id(actors)==nil,'A missing controller is not an answer')
print('Controller lookup passed: live possession, missing controller and stale focus contexts.')

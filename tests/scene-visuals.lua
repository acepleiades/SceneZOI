package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
UE={UKismetSystemLibrary={IsValid=function(v)return not v.dead end}}
local function marker(hidden)
 local c={bHiddenInGame=hidden}
 function c:SetHiddenInGame(v,children)
  assert(children==false,'Only hide the selected-marker component')
  self.bHiddenInGame=v
  if self.fail then self.fail=false;error('partial marker mutation')end
 end
 return c
end
local V=require('SceneZOI.SceneVisuals')
local a,b,c=marker(false),marker(false),marker(true)
local actors={['1']={PlayerSelectedFxComponent=a},['2']={PlayerSelectedFxComponent=b},['3']={PlayerSelectedFxComponent=c}}
V.tick(actors,true,{['1']=true});assert(a.bHiddenInGame and not b.bHiddenInGame,'Only scene participants are hidden')
-- Participants of every active scene count.
V.tick(actors,true,{['1']=true,['2']=true});assert(a.bHiddenInGame and b.bHiddenInGame)
-- A participant who left the set is restored while the rest stay hidden.
V.tick(actors,true,{['2']=true});assert(not a.bHiddenInGame and b.bHiddenInGame)
V.tick(actors,false);assert(not b.bHiddenInGame)
-- An original hidden flag is preserved.
V.tick(actors,true,{['3']=true});assert(c.bHiddenInGame);V.tick(actors,false);assert(c.bHiddenInGame)
-- A failed restore retries, and another owner's later change is not overwritten.
V.tick(actors,true,{['1']=true});a.fail=true;V.tick(actors,false);assert(not a.bHiddenInGame);a.fail=nil
V.tick(actors,true,{['1']=true});a.bHiddenInGame=false;V.tick(actors,false);assert(a.bHiddenInGame==false)
-- A released component is forgotten.
V.tick(actors,true,{['1']=true});a.dead=true;local status=V.tick({},true,{});assert(status.markers==0)
print('Scene visuals passed: participant markers across scenes, restoration, retries and released components.')

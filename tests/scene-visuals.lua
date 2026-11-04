package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local widgets={};local enumerate_failure=false
UE={UKismetSystemLibrary={IsValid=function(v)return not v.dead end},UWidgetBlueprintLibrary={GetAllWidgetsOfClass=function()
 if enumerate_failure then error('temporary widget lookup failure')end;return widgets end}}
inzoi={UB1SpeechBubbleWidget={StaticClass=function()return 'bubble'end}}
local function marker(hidden)
 local c={bHiddenInGame=hidden}
 function c:SetHiddenInGame(v,children)
  assert(children==false,'Only hide the selected-marker component')
  self.bHiddenInGame=v
  if self.fail then self.fail=false;error('partial marker mutation')end
 end
 return c
end
local function bubble(alpha)
 local w={alpha=alpha}
 function w:GetRenderOpacity()return self.alpha end
 function w:SetRenderOpacity(v)
  self.alpha=v
  if self.fail then self.fail=false;error('partial bubble mutation')end
 end
 return w
end
local V=require('SceneZOI.SceneVisuals')
local a,b=marker(false),marker(true);local one,two=bubble(1),bubble(.6)
local portrait,background=bubble(.8),bubble(1);one.BW_Image_Portrait=portrait;one.BW_WidgetSwitcher_BubbleType=background
local members={a=true,b=true};local outsider=marker(false)
local actors={a={PlayerSelectedFxComponent=a},b={PlayerSelectedFxComponent=b},outside={PlayerSelectedFxComponent=outsider},unsupported={}}
widgets={one,two}
V.tick(actors,false);assert(not a.bHiddenInGame and one.alpha==1,'No mutation outside scene ownership')
local s=V.tick(actors,true,members);assert(s.markers==2 and s.bubbles==4 and not s.error)
assert(a.bHiddenInGame and b.bHiddenInGame and one.alpha==0 and two.alpha==0 and portrait.alpha==0 and background.alpha==0)
assert(not outsider.bHiddenInGame,"An outside-roster controlled Zoi keeps its normal marker")
-- Repeated samples and engine refreshes cannot recapture our suppressed values.
a.bHiddenInGame=false;one.alpha=1;portrait.alpha=.8; background.alpha=1
for _=1,5 do V.tick(actors,true,members)end
V.tick(actors,false)
assert(not a.bHiddenInGame and b.bHiddenInGame and one.alpha==1 and two.alpha==.6 and portrait.alpha==.8 and background.alpha==1)
-- A roster change restores an old owner; re-entry captures the same original flag.
V.tick(actors,true,members);members.a=nil;V.tick(actors,true,members)
assert(not a.bHiddenInGame and not outsider.bHiddenInGame)
members.a=true;V.tick(actors,true,members);assert(a.bHiddenInGame)
V.restore()
-- Control switches/replaced effects and newly spawned nearby bubbles are covered.
local c=marker(false);V.tick(actors,true,members);actors.a.PlayerSelectedFxComponent=c
local three=bubble(1);widgets[#widgets+1]=three
V.tick(actors,true,members);assert(not a.bHiddenInGame and c.bHiddenInGame and three.alpha==0)
-- Optional widget failures do not prevent markers from being suppressed/restored.
enumerate_failure=true;local status=V.tick(actors,true,members);assert(status.error and c.bHiddenInGame)
enumerate_failure=false;V.tick(actors,false);assert(not c.bHiddenInGame and three.alpha==1)
-- Retain ownership across partial writes and retry restoration independently.
c.fail=true;one.fail=true;V.tick(actors,true,members);V.tick(actors,true,members)
c.fail=true;one.fail=true
local ok=V.restore();assert(not ok)
assert(V.restore());assert(not c.bHiddenInGame and one.alpha==1)
-- Another owner changing presentation after our last write wins on release.
V.tick(actors,true,members);c.bHiddenInGame=false;one.alpha=.3
V.restore();assert(not c.bHiddenInGame and one.alpha==.3)
-- Invalid native handles retire without blocking other independent restorations.
V.tick(actors,true,members);c.dead=true;two.dead=true;actors.a=nil
local clean=V.tick({},false);assert(clean.markers==0 and clean.bubbles==0 and three.alpha==1)
print('Scene visuals passed: original flags/opacity, repeated sessions, refreshed/replaced FX, late bubbles, partial failures, independent retry and invalid/foreign state.')

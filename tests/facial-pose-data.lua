package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local D=require('SceneZOI.FacialPoseData');local V=require('SceneZOI.DataValidation')
local good={schema_version=1,id='example.brow',poses={female={{bone='FACIAL_L_Brow',parent='FACIAL_C_FacialRoot',position={0,0,0},rotation={0,0,0,1}}}}}
assert(D.validate(good,'example'))
local bad=V.copy(good);bad.poses.female[1].rotation[4]=0;assert(not pcall(D.validate,bad))
bad=V.copy(good);bad.poses.female[1].parent='FACIAL_L_Brow';assert(not pcall(D.validate,bad))
bad=V.copy(good);bad.poses.female[1].bone='pelvis';assert(not pcall(D.validate,bad))
local result=D.compile({{source='bad',owner='example',data=bad},{source='good',owner='example',data=good}})
assert(#result.warnings==1 and result.poses['example.brow'],'Bad file poisoned independent pose declarations')
local Files={value={}}
function Files.get()return Files.value end
function Files.documents(kind)assert(kind=='facial_pose');return {{source='good',owner='example',data=good}}end
package.loaded['SceneZOI.DataFiles']=Files
local L=require('SceneZOI.FacialPoseLibrary')
local first=L.refresh();assert(first==L.refresh(),'Unchanged discovery recompiled poses')
Files.value={};assert(first~=L.refresh(),'New discovery did not refresh poses')
assert(not L.owns_eyes('example.brow','female'))
good.poses.female[1].bone='FACIAL_L_Eye';Files.value={};L.refresh();assert(L.owns_eyes('example.brow','female'))
print('Facial pose declarations: validation, transactional bad-file isolation, discovery caching and eye ownership passed.')

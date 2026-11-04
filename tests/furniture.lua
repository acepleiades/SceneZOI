package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local F=require('SceneZOI.FurnitureData');local V=require('SceneZOI.DataValidation');local Json=require('SceneZOI.Json')
local p={schema_version=1,id='author.bed',kind='bed.single',objects={'ModelA','ModelB'},surface_height_cm=5}
F.profile(p);assert(F.compatible({furniture={kind='bed.single'}},p));assert(not F.compatible({},p));assert(not F.compatible({furniture={kind='bed.queen'}},p));assert(F.compatible({},nil))
local compiled=F.compile({by_kind={furniture_profile={{source='a',data=p},{source='bad',data={}}}}})
assert(compiled.objects.ModelA.id==p.id and #compiled.warnings==1)
local bad=V.copy(p);bad.surface_height_cm=0/0;assert(not pcall(F.profile,bad));bad=V.copy(p);bad.objects={'ModelA','ModelA'};assert(not pcall(F.profile,bad))
local Choose=require('SceneZOI.StartingScenes');inzoi={EB1BodyAgeType={Adult=1}}
local roles={lead={body='male'},partner={body='female'}}
local nodes={standing={starting_hub=true,participants=roles},single={starting_hub=true,participants=roles,furniture={kind='bed.single'}},queen={starting_hub=true,participants=roles,furniture={kind='bed.queen'}}}
local roster={{id='1',body='male'},{id='2',body='female'}}
assert(Choose.choose(nodes,roster).node=='standing');assert(Choose.choose(nodes,roster,nil,p).node=='single')
local scene=require('SceneZOI.SceneData')
local native=Json.decode(TEST_SCENE_PACKS).scenezoi
local ids={};for _,n in ipairs(native.nodes)do ids[n.id]=n;scene.node(n,'scenezoi')end
assert(ids['scenezoi.bed_single_idle'].duration==4 and ids['scenezoi.bed_queen_idle'].duration==4)
assert(V.equal(ids['scenezoi.bed_single_idle'].tracks,ids['scenezoi.bed_queen_idle'].tracks));assert(#native.nodes==3)
print('Furniture data passed: profile validation/isolation, independent single/queen contexts, standing-entry exclusion and actual neutral hubs.')

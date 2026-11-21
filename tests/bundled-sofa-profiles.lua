-- Real bundled topology: approach aliases are not additional physical seats.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation')
local F=require('SceneZOI.FurnitureData');local Pair=require('SceneZOI.FurniturePairs')
local pack=J.decode(TEST_SCENE_PACKS).scenezoi
local function read(path)local file=assert(io.open(path,'rb'));local raw=file:read('*a');file:close();return J.decode(raw)end
local docs={}
for _,entry in ipairs(pack.data_files)do if entry.kind=='furniture_profile'then
 docs[#docs+1]={source=entry.file,data=read('packs/'..entry.file)}
end end
local compiled=F.compile({by_kind={furniture_profile=docs}})
assert(#docs==10 and #compiled.warnings==0,table.concat(compiled.warnings,';'))
local topology={
 two={models={'Sofa01_v09','Sofa01_v15'},pairs=1,spots={left={'L','L1'},right={'R','R1'}}},
 three={models={'Sofa02_v03','Sofa02_v06'},pairs=2,spots={left={'L','L1'},center={'C','C1'},right={'R','R1'}}},
 corner_three={models={'Sofa03_v01'},pairs=1,spots={front_left={'L'},front_right={'R'},side={'R1'}}},
 corner_four={models={'Sofa04_v01'},pairs=2,spots={front_left={'L'},front_right={'R'},side_left={'L1'},side_right={'R1'}}},
 curtain={models={'E01_Sofa05'},pairs=1,spots={left={'L','L1'},right={'R','R1'}}},
}
local profile_count,model_count=0,0
for suffix,expected in pairs(topology)do
 local id='scenezoi.sofa.pair.'..suffix
 local profile=assert(compiled.profiles[id],id)
 profile_count=profile_count+1
 assert(profile.kind=='sofa.pair'and #profile.seat_pairs==expected.pairs)
 local spots={}
 for _,spot in ipairs(profile.sitting_spots)do
  assert(expected.spots[spot.id]and not spots[spot.id]);spots[spot.id]=spot
  local names={}
  for _,slot in ipairs(spot.slots)do
   assert(slot.slot_name==slot.component_name,'Bundled native slot/group names match this measured topology')
   names[#names+1]=slot.component_name:gsub('^InteractionSlot_','')
  end
  table.sort(names);local aliases=V.copy(expected.spots[spot.id]);table.sort(aliases)
  assert(V.equal(names,aliases),id..' aliases must belong to the same physical spot')
 end
 local physical_count=0;for spot_id in pairs(expected.spots)do assert(spots[spot_id]);physical_count=physical_count+1 end
 assert(#profile.sitting_spots==physical_count)
 assert(#profile.objects==#expected.models)
 for _,model in ipairs(expected.models)do
  model_count=model_count+1
  assert(compiled.objects[model]and compiled.objects[model].id==id,model..' must resolve to its measured profile')
 end
 for _,pair in ipairs(profile.seat_pairs)do
  local a,b=spots[pair.spots[1]],spots[pair.spots[2]]
  assert(a.run==b.run and a.yaw_degrees==b.yaw_degrees,'No diagonal pair across a corner')
 end
 if suffix=='three'then
  assert(Pair.overlap(profile.seat_pairs[1].spots,profile.seat_pairs[2].spots),'Three physical seats share their middle seat')
 elseif suffix=='corner_four'then
  assert(not Pair.overlap(profile.seat_pairs[1].spots,profile.seat_pairs[2].spots),'Four-seat corner has two disjoint straight pairs')
 elseif suffix=='corner_three'then
  assert(not V.equal(profile.seat_pairs[1].spots,{'front_left','side'}),'An isolated perpendicular seat is not a second pair')
 end
end
assert(profile_count==5 and model_count==7)
print('Bundled sofa profiles passed: seven model IDs, physical2/3/4-seat and DLC2-seat topology, same-seat approach aliases, middle-seat overlap and disjoint corner pairs. Coordinates require separate native/visual verification.')

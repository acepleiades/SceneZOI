-- Physical sitting spots, not raw slot count, define a sofa's reservable pairs.
local V=require('SceneZOI.DataValidation')
local M={}
function M.validate(profile)
 if profile.kind~='sofa.pair'then
  assert(profile.sitting_spots==nil and profile.seat_pairs==nil,'Sitting spots require sofa.pair furniture');return
 end
 V.array(profile.sitting_spots,64);V.array(profile.seat_pairs,128)
 assert(#profile.sitting_spots>=2 and #profile.seat_pairs>0,'A sofa needs physical sitting spots and allowed pairs')
 local spots,slots={},{}
 for _,spot in ipairs(profile.sitting_spots)do
  V.fields(spot,{'id','run','offset_cm','yaw_degrees','slots'},{'id','run','offset_cm','yaw_degrees','slots'})
  V.id(spot.id);V.id(spot.run);assert(not spots[spot.id],'Duplicate sitting spot');spots[spot.id]=spot
  V.fields(spot.offset_cm,{'x','y','z'},{'x','y','z'})
  for _,key in ipairs({'x','y','z'})do V.number(spot.offset_cm[key],-10000,10000)end
  V.number(spot.yaw_degrees,-360,360);V.array(spot.slots,32);assert(#spot.slots>0,'Sitting spot has no native slots')
  for _,slot in ipairs(spot.slots)do
   V.fields(slot,{'component_name','slot_name'},{'component_name','slot_name'});V.name(slot.component_name);V.name(slot.slot_name)
   local key=slot.component_name..'\0'..slot.slot_name
   assert(not slots[key],'A native slot cannot belong to two physical spots');slots[key]=true
  end
 end
 local pair_ids,combinations={},{}
 for _,pair in ipairs(profile.seat_pairs)do
  V.fields(pair,{'id','spots','label'},{'id','spots'});V.id(pair.id);if pair.label~=nil then V.name(pair.label)end;assert(not pair_ids[pair.id],'Duplicate seat pair');pair_ids[pair.id]=true
  V.array(pair.spots,2);assert(#pair.spots==2 and pair.spots[1]~=pair.spots[2],'A seat pair needs two different spots')
  local a,b=spots[pair.spots[1]],spots[pair.spots[2]];assert(a and b,'Unknown sitting spot')
  local ids={a.id,b.id};table.sort(ids);local key=table.concat(ids,'+')
  assert(not combinations[key],'Duplicate sitting-spot combination');combinations[key]=true
  assert(a.run==b.run and math.abs((a.yaw_degrees-b.yaw_degrees+180)%360-180)<.01,'Seat pair must face the same way on one straight run')
  local x,y,z=b.offset_cm.x-a.offset_cm.x,b.offset_cm.y-a.offset_cm.y,b.offset_cm.z-a.offset_cm.z
  local length=x*x+y*y;assert(length>1 and math.abs(z)<1,'Seat pair must share one sitting surface')
  for _,other in pairs(spots)do if other~=a and other~=b and other.run==a.run then
   local dx,dy=other.offset_cm.x-a.offset_cm.x,other.offset_cm.y-a.offset_cm.y
   local t=(dx*x+dy*y)/length
   assert(not(t>0 and t<1 and math.abs(dx*y-dy*x)/math.sqrt(length)<1),'Seat pair skips an intermediate sitting spot')
  end end
 end
end
function M.find(profile,id)
 for _,pair in ipairs(profile.seat_pairs or {})do if pair.id==id then return pair end end
end
function M.spots(profile,pair)
 local result={};for _,id in ipairs(pair.spots)do for _,spot in ipairs(profile.sitting_spots)do if spot.id==id then result[#result+1]=spot;break end end end
 assert(#result==2,'Unknown sitting spot');return result
end
function M.overlap(a,b)
 if not a or not b then return true end
 for _,x in ipairs(a)do for _,y in ipairs(b)do if x==y then return true end end end
 return false
end
function M.same_slots(a,b)
 local function keys(rows)
  V.array(rows,64);local result={}
  for _,row in ipairs(rows)do V.fields(row,{'component_name','slot_name'},{'component_name','slot_name'});V.name(row.component_name);V.name(row.slot_name);result[#result+1]=row.component_name..'\0'..row.slot_name end
  table.sort(result);return result
 end
 local ok,x,y=pcall(function()return keys(a),keys(b)end)
 return ok and V.equal(x,y)
end
return M

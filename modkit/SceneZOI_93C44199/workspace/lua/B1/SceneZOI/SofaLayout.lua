-- A native Sit slot is an approach/root marker. The stock sofa pose places
-- the cushion contact 53 cm behind it, on a 44 cm support plane. Keep this
-- animation convention separate from object IDs and from the reservation.
local M={approach_depth_cm=53,surface_height_cm=44}
local V=require('SceneZOI.DataValidation')
local function angle(a,b)return math.abs((a-b+180)%360-180)end
local function round(value)return math.floor(value*1000+.5)/1000 end
local function same(a,b,depth)
 if angle(a.yaw_degrees,b.yaw_degrees)>.009 then return false end
 local r=math.rad(a.yaw_degrees);local dx,dy=b.position.x-a.position.x,b.position.y-a.position.y
 return math.abs(dx*math.cos(r)+dy*math.sin(r))<.5 and
  math.abs(-dx*math.sin(r)+dy*math.cos(r))<=depth and math.abs(a.position.z-b.position.z)<.5
end
local function aligned(a,b)
 if angle(a.yaw_degrees,b.yaw_degrees)>.009 then return false end
 local r=math.rad(a.yaw_degrees);local dx,dy=b.position.x-a.position.x,b.position.y-a.position.y
 return math.abs(-dx*math.sin(r)+dy*math.cos(r))<.5 and math.abs(a.position.z-b.position.z)<.5
end
local function slotkey(row)return row.component_name..'\0'..row.slot_name end
local function has(row,tag)for _,value in ipairs(row.tags)do if value==tag then return true end end;return false end
function M.build(model,entity_id,rows)
 V.name(model);assert(type(entity_id)=='string'and entity_id:match('^%d+$'),'Invalid sofa entity')
 V.array(rows,512)
 local ordered=V.copy(rows);table.sort(ordered,function(a,b)return slotkey(a)<slotkey(b)end)
 local seeds,seen={},{}
 for _,row in ipairs(ordered)do
  V.name(row.component_name);V.name(row.slot_name);assert(not seen[slotkey(row)],'Duplicate native sofa slot');seen[slotkey(row)]=true
  V.fields(row.position,{'x','y','z'},{'x','y','z'})
  for _,axis in ipairs({'x','y','z'})do V.number(row.position[axis],-10000,10000)end
  V.number(row.yaw_degrees,-360,360);V.array(row.tags,64)
  if has(row,'Sit')then
   local matched
   for _,seed in ipairs(seeds)do if same(seed,row,.5)then assert(not matched,'Ambiguous native sitting spot');matched=seed end end
   if not matched then seeds[#seeds+1]=row end
  end
 end
 if #seeds<2 then return nil,'not_enough_sitting_spots'end
 assert(#seeds<=64,'Too many native sitting spots')
 local profile={schema_version=1,id='scenezoi.sofa.native.'..entity_id,kind='sofa.pair',objects={model},
  surface_height_cm=M.surface_height_cm,sitting_spots={},seat_pairs={}}
 for index,seed in ipairs(seeds)do
  local r=math.rad(seed.yaw_degrees)
  profile.sitting_spots[index]={id='seat_'..index,run='run_'..index,yaw_degrees=round(seed.yaw_degrees),
   offset_cm={x=round(seed.position.x+M.approach_depth_cm*math.sin(r)),
    y=round(seed.position.y-M.approach_depth_cm*math.cos(r)),z=round(seed.position.z)},slots={}}
 end
 for _,row in ipairs(ordered)do
  local index
  for i,seed in ipairs(seeds)do if same(seed,row,15)then assert(not index,'Ambiguous native sofa alias');index=i end end
  -- An unmatched alternate sitting posture could occupy an unreserved seat.
  assert(index,'Native sitting alias does not identify a physical seat')
  local slots=profile.sitting_spots[index].slots
  slots[#slots+1]={component_name=row.component_name,slot_name=row.slot_name}
 end
 for i,a in ipairs(seeds)do
  for j=1,i-1 do if aligned(a,seeds[j])then profile.sitting_spots[i].run=profile.sitting_spots[j].run;break end end
 end
 for i,a in ipairs(seeds)do for j=i+1,#seeds do local b=seeds[j]
  if aligned(a,b)and profile.sitting_spots[i].run==profile.sitting_spots[j].run then
   local dx,dy=b.position.x-a.position.x,b.position.y-a.position.y;local length=dx*dx+dy*dy
   local adjacent=length>=25^2 and length<=160^2
   for k,c in ipairs(seeds)do if k~=i and k~=j and aligned(a,c)then
    local x,y=c.position.x-a.position.x,c.position.y-a.position.y;local t=(x*dx+y*dy)/length
    if t>0 and t<1 then adjacent=false end
   end end
   if adjacent then profile.seat_pairs[#profile.seat_pairs+1]={id='seats_'..i..'_'..j,spots={'seat_'..i,'seat_'..j}}end
  end
 end end
 if #profile.seat_pairs==0 then return nil,'no_adjacent_sitting_pair'end
 require('SceneZOI.FurniturePairs').validate(profile)
 return profile
end
return M

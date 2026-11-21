local P=require('SceneZOI.Protocol')
local V=require('SceneZOI.DataValidation')
local Pairs=require('SceneZOI.FurniturePairs')
local M={status={},elapsed=0}
local function entity(id)local e=inzoi.FB1EntityId();e.Value=tonumber(id);return e end
function M.actor(id)
 local manager=inzoi.UB1System.Get().ManagerMap:Find(inzoi.EB1ManagerType.Entity)
 return manager and manager.GameObjectMap:Find(entity(id))
end
function M.profile(id)
 local actor=M.actor(id);if not actor then return end
 local p=(require('SceneZOI.Catalog').get_snapshot().furniture or {}).objects
 return p and p[tostring(actor.ObjectDataTableId)],actor
end
-- Search uses recent B2 status as a hint. Only acquire reserves the object.
function M.available(id,pair_id,allowed_ids)
 local p,a=M.profile(id);local state=M.status[id]
 if not(p and a and state and os.time()-state.time<=3)then return end
 if p.kind~='sofa.pair'then return not pair_id and state.free and not require('SceneZOI.Sessions').furniture_holder(id)and p or nil end
 local candidates={};for _,pair in ipairs(p.seat_pairs)do candidates[#candidates+1]=pair end
 table.sort(candidates,function(x,y)return x.id<y.id end)
 local allowed={};for _,who in ipairs(allowed_ids or {})do allowed[who]=true end
 for _,pair in ipairs(candidates)do
  local clearable=state.clearable and state.clearable[pair.id]
  local can_clear=type(clearable)=='table'and #clearable>0
  for _,who in ipairs(clearable or {})do if not allowed[who]then can_clear=false end end
  if(not pair_id or pair.id==pair_id)and(state.pairs and state.pairs[pair.id]or can_clear)and not require('SceneZOI.Sessions').furniture_holder(id,pair.spots)then return p,pair end
 end
end
-- Before the roster is chosen, show a picker only for a free or preparable pair.
-- This hint never authorizes clearing anyone; available() rechecks the final roster.
function M.pickable(id)
 local state=M.status[id];local people={}
 for _,ids in pairs(state and state.clearable or {})do for _,who in ipairs(ids)do people[#people+1]=who end end
 return M.available(id,nil,people)
end
function M.choices(id,allowed_ids)
 local profile=M.profile(id);local rows=require('SceneZOI.Json').array({})
 if not profile or profile.kind~='sofa.pair'then return rows end
 local pairs={};for _,pair in ipairs(profile.seat_pairs)do pairs[#pairs+1]=pair end
 table.sort(pairs,function(a,b)return a.id<b.id end)
 for index,pair in ipairs(pairs)do if M.available(id,pair.id,allowed_ids)then
  local spots=Pairs.spots(profile,pair);local x=(spots[1].offset_cm.x+spots[2].offset_cm.x)*.5;local y=(spots[1].offset_cm.y+spots[2].offset_cm.y)*.5
  rows[#rows+1]={id=pair.id,label=require('SceneZOI.Localization').text(pair.label or 'Seat pair {number}',{number=index}),x=x,y=y}
 end end
 return rows
end
function M.reply(actor,content)
 local f=P.unpack(content);if not f then return end
 if f[1]=='status'then
  local available
  if f[4]and f[4]~='none'then
   local ok,ids=pcall(require('SceneZOI.Json').decode,P.decode(f[4])or '')
   if ok and type(ids)=='table'then available={};for _,id in ipairs(ids)do if type(id)=='string'then available[id]=true end end end
  end
  local clearable
  if f[5]and f[5]~='none'then
   local ok,value=pcall(function()
    local map=require('SceneZOI.Json').decode(P.decode(f[5])or '');assert(V.object(map),'Invalid clearable pair status')
    for pair,ids in pairs(map)do V.id(pair);V.array(ids,32);assert(#ids>0,'Empty clearable occupants');for _,who in ipairs(ids)do assert(type(who)=='string'and who:match('^%d+$'),'Invalid furniture occupant')end end
    return map
   end)
   if ok then clearable=value end
  end
  M.status[f[2]]={free=f[3]=='free',pairs=available,clearable=clearable,time=os.time()};return
 end
 require('SceneZOI.Runtime').furniture_reply(actor,f)
end
function M.tick(dt,actor)
 M.elapsed=M.elapsed+dt;if M.elapsed<.5 or not actor then return end;M.elapsed=0
 local profiles=require('SceneZOI.Catalog').get_snapshot().furniture
 if not profiles then return end
 local manager=inzoi.UB1System.Get().ManagerMap:Find(inzoi.EB1ManagerType.Entity)
 if not manager then return end
 for key,obj in pairs(manager.GameObjectMap:ToTable())do
  if profiles.objects[tostring(obj.ObjectDataTableId)]then
   local profile=profiles.objects[tostring(obj.ObjectDataTableId)]
   require('SceneZOI.SimulationRoute').send(actor,'SceneZOI.Furniture',P.pack('status',tostring(key.Value),'status',
    profile.kind=='sofa.pair'and P.encode(require('SceneZOI.Json').encode(profile))or 'none'))
  end
 end
end
function M.prepare(id,node,pair_id)
 local profile,actor=M.profile(id)
 assert(require('SceneZOI.FurnitureData').compatible(node,profile),'Furniture is incompatible with this scene')
 assert(profile and actor,'Furniture is no longer loaded')
 local transform=actor:GetTransform();local scale=transform.Scale3D
 assert(math.abs(scale.X-1)<.001 and math.abs(scale.Y-1)<.001 and math.abs(scale.Z-1)<.001,'Scaled furniture is not supported yet')
 local o=V.copy(profile.offset_cm or {});local pair,spots
 local facing=profile.yaw_degrees or 0
 if profile.kind=='sofa.pair'then
  if pair_id then pair=Pairs.find(profile,pair_id)else local _,available=M.available(id);pair=available end
  assert(pair,'Furniture sitting pair is unavailable')
  spots=Pairs.spots(profile,pair)
  for _,axis in ipairs({'x','y','z'})do o[axis]=(o[axis]or 0)+(spots[1].offset_cm[axis]+spots[2].offset_cm[axis])*.5 end
  facing=facing+spots[1].yaw_degrees
 else assert(not pair_id,'A bed does not have sitting pairs')end
 -- Align the authored support plane to the profile's surface in object space.
 local point=UE.UKismetMathLibrary.TransformLocation(transform,UE.FVector(o.x or 0,o.y or 0,(o.z or 0)+profile.surface_height_cm-node.furniture.surface_height_cm))
 local rotation=actor:K2_GetActorRotation()
 assert(math.abs(rotation.Pitch)<.01 and math.abs(rotation.Roll)<.01,'Tilted furniture is not supported yet')
 local yaw=rotation.Yaw+facing
 local original=actor:K2_GetActorLocation()
 local anchor=UE.FTransform()
 anchor.Translation=point
 local half=math.rad(yaw)*.5
 anchor.Rotation=UE.FQuat(0,0,math.sin(half),math.cos(half))
 anchor.Scale3D=UE.FVector(1,1,1)
 local slots={};for _,spot in ipairs(spots or {})do for _,slot in ipairs(spot.slots)do slots[#slots+1]=V.copy(slot)end end
 return {id=id,profile=V.copy(profile),anchor=anchor,original={X=original.X,Y=original.Y,Z=original.Z},yaw=rotation.Yaw,
  selected_pair_id=pair and pair.id,spot_ids=pair and V.copy(pair.spots),slots=pair and slots}
end
function M.valid(f)
 local actor=M.actor(f.id);if not actor then return false end
 local p=actor:K2_GetActorLocation();local r=actor:K2_GetActorRotation();local transform=actor:GetTransform();local s=transform.Scale3D
 local detail=string.format('bed=%s position=%.4f,%.4f,%.4f original=%.4f,%.4f,%.4f yaw=%.4f original_yaw=%.4f pitch=%.4f roll=%.4f scale=%.4f,%.4f,%.4f',f.id,p.X,p.Y,p.Z,f.original.X,f.original.Y,f.original.Z,r.Yaw,f.yaw,r.Pitch,r.Roll,s.X,s.Y,s.Z)
 -- Keep the same upright requirement after entry that prepare enforces.
 return math.abs(p.X-f.original.X)<.1 and math.abs(p.Y-f.original.Y)<.1 and math.abs(p.Z-f.original.Z)<.1 and math.abs(r.Yaw-f.yaw)<.01 and math.abs(r.Pitch)<.01 and math.abs(r.Roll)<.01 and math.abs(s.X-1)<.001 and math.abs(s.Y-1)<.001 and math.abs(s.Z-1)<.001,detail
end
function M.find(args,actors,data)
 assert(type(args.origin_id)=='string'and args.origin_id:match('^%d+$'),'Invalid origin ID')
 local origin=assert(actors[args.origin_id],'Origin Zoi is not loaded'):K2_GetActorLocation()
 local radius=args.radius_m or 25;V.number(radius,0,1000)
 if args.include_unavailable~=nil then V.boolean(args.include_unavailable)end
 local node=args.scene_id and assert(data.nodes[args.scene_id],'Unknown scene')
 local manager=inzoi.UB1System.Get().ManagerMap:Find(inzoi.EB1ManagerType.Entity)
 local rows=require('SceneZOI.Json').array({})
 for key,obj in pairs(manager and manager.GameObjectMap:ToTable()or {})do
  local id=tostring(key.Value);local profile=(data.furniture or {}).objects and data.furniture.objects[tostring(obj.ObjectDataTableId)]
  if profile and(not node or require('SceneZOI.FurnitureData').compatible(node,profile))then
   local point=obj:K2_GetActorLocation();local distance=math.sqrt((point.X-origin.X)^2+(point.Y-origin.Y)^2+(point.Z-origin.Z)^2)/100
   if distance<=radius then
    local status=M.status[id];local fresh=status and os.time()-status.time<=3
    local candidates=profile.seat_pairs or {false}
    for _,pair in ipairs(candidates)do
     local pair_id=pair and pair.id or nil
     local available=M.available(id,pair_id,args.participants)~=nil
     if available or args.include_unavailable then rows[#rows+1]={furniture_id=id,furniture_pair_id=pair_id,
      sitting_spots=pair and V.copy(pair.spots),distance_m=distance,profile=V.copy(profile),available=available,
      status=fresh and(available and 'available'or 'occupied')or 'unknown',reservation=false}end
    end
   end
  end
 end
 table.sort(rows,function(a,b)if a.distance_m~=b.distance_m then return a.distance_m<b.distance_m end;if a.furniture_id~=b.furniture_id then return a.furniture_id<b.furniture_id end;return(a.furniture_pair_id or '')<(b.furniture_pair_id or '')end)
 return {furniture=rows,count=#rows,reservation=false,status_cache_seconds=3}
end
return M

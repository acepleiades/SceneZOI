local P=require('SceneZOI.Protocol')
local V=require('SceneZOI.DataValidation')
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
function M.available(id)
 local p,a=M.profile(id);local state=M.status[id]
 return p and a and state and state.free and os.time()-state.time<=3 and p or nil
end
function M.reply(actor,content)
 local f=P.unpack(content);if not f then return end
 if f[1]=='status'then
  M.status[f[2]]={free=f[3]=='free',time=os.time()};return
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
   inzoi.message.send_to_sim(actor:GetEntityId(),'SceneZOI.Furniture',P.pack('status',tostring(key.Value)))
  end
 end
end
function M.prepare(id,node)
 local profile,actor=M.profile(id)
 assert(require('SceneZOI.FurnitureData').compatible(node,profile),'Furniture is incompatible with this scene')
 assert(profile and actor,'Furniture is no longer loaded')
 local transform=actor:GetTransform();local scale=transform.Scale3D
 assert(math.abs(scale.X-1)<.001 and math.abs(scale.Y-1)<.001 and math.abs(scale.Z-1)<.001,'Scaled furniture is not supported yet')
 local o=profile.offset_cm or {}
 local point=UE.UKismetMathLibrary.TransformLocation(transform,UE.FVector(o.x or 0,o.y or 0,(o.z or 0)+profile.surface_height_cm-node.furniture.surface_height_cm))
 local rotation=actor:K2_GetActorRotation()
 assert(math.abs(rotation.Pitch)<.01 and math.abs(rotation.Roll)<.01,'Tilted furniture is not supported yet')
 local yaw=rotation.Yaw+(profile.yaw_degrees or 0)
 local original=actor:K2_GetActorLocation()
 local anchor=UE.FTransform()
 anchor.Translation=point
 local half=math.rad(yaw)*.5
 anchor.Rotation=UE.FQuat(0,0,math.sin(half),math.cos(half))
 anchor.Scale3D=UE.FVector(1,1,1)
 return {id=id,profile=V.copy(profile),anchor=anchor,original={X=original.X,Y=original.Y,Z=original.Z},yaw=rotation.Yaw}
end
function M.valid(f)
 local actor=M.actor(f.id);if not actor then return false end
 local p=actor:K2_GetActorLocation();local r=actor:K2_GetActorRotation();local transform=actor:GetTransform();local s=transform.Scale3D
 local detail=string.format('bed=%s position=%.4f,%.4f,%.4f original=%.4f,%.4f,%.4f yaw=%.4f original_yaw=%.4f scale=%.4f,%.4f,%.4f',f.id,p.X,p.Y,p.Z,f.original.X,f.original.Y,f.original.Z,r.Yaw,f.yaw,s.X,s.Y,s.Z)
 return math.abs(p.X-f.original.X)<.1 and math.abs(p.Y-f.original.Y)<.1 and math.abs(p.Z-f.original.Z)<.1 and math.abs(r.Yaw-f.yaw)<.01 and math.abs(s.X-1)<.001 and math.abs(s.Y-1)<.001 and math.abs(s.Z-1)<.001,detail
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
    local available=M.available(id)~=nil
    local status=M.status[id];local fresh=status and os.time()-status.time<=3
    if available or args.include_unavailable then rows[#rows+1]={furniture_id=id,distance_m=distance,profile=V.copy(profile),available=available,status=fresh and(status.free and 'available'or 'occupied')or 'unknown',reservation=false}end
   end
  end
 end
 table.sort(rows,function(a,b)if a.distance_m~=b.distance_m then return a.distance_m<b.distance_m end;return a.furniture_id<b.furniture_id end)
 return {furniture=rows,count=#rows,reservation=false,status_cache_seconds=3}
end
return M

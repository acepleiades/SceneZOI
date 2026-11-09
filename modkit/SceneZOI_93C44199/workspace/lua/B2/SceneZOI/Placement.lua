-- Finds floor for a standing scene that would otherwise crowd another one.
local M={}
local RING_CM,RINGS,DIRECTIONS=75,8,12

local function path_system()
 return assert(inzoi.getB2Manager('FB2PathFindSystem'),'Path finding is unavailable')
end
local function on_floor(system,point)
 return system:IsOnWalkableGrid(point)==true
end
local function clear(x,y,taken,spacing)
 for _,spot in ipairs(taken)do
  local dx,dy=spot[1]-x,spot[2]-y
  if dx*dx+dy*dy<spacing*spacing then return false end
 end
 return true
end

function M.walkable(owner)
 local ok,result=pcall(function()return on_floor(path_system(),owner:GetLocation())end)
 return ok and result
end

-- Nearest walkable point at least `spacing` from every other scene, searching outward in rings.
function M.find(owner,spacing,encoded)
 assert(type(spacing)=='number'and spacing>0,'Invalid spacing')
 local taken={}
 for x,y in tostring(encoded or ''):gmatch('(-?[%d.]+),(-?[%d.]+)')do taken[#taken+1]={tonumber(x),tonumber(y)}end
 local system,origin=path_system(),owner:GetLocation()
 for ring=1,RINGS do
  local radius=ring*RING_CM
  for step=0,DIRECTIONS-1 do
   local angle=step/DIRECTIONS*math.pi*2
   local x,y=origin.X+math.cos(angle)*radius,origin.Y+math.sin(angle)*radius
   if clear(x,y,taken,spacing)and on_floor(system,UE.FVector(x,y,origin.Z))then
    return string.format('%.1f',x),string.format('%.1f',y),string.format('%.1f',origin.Z)
   end
  end
 end
 error('No safe floor nearby')
end

return M

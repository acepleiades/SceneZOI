-- The tested facial rig looks along +Z; local X is lateral and local Y is down.
-- Unreal eye Pitch turns sideways and eye Roll turns vertically, as in the
-- game's HeadAnimInstance. Limits are read from that active instance, never enlarged.
local M = {}
function M.multiply(a,b)
    return {X=a.W*b.X+a.X*b.W+a.Y*b.Z-a.Z*b.Y,
        Y=a.W*b.Y-a.X*b.Z+a.Y*b.W+a.Z*b.X,
        Z=a.W*b.Z+a.X*b.Y-a.Y*b.X+a.Z*b.W,
        W=a.W*b.W-a.X*b.X-a.Y*b.Y-a.Z*b.Z}
end

function M.inverse(q)
    local n=q.X*q.X+q.Y*q.Y+q.Z*q.Z+q.W*q.W
    assert(n>0.000001,"Invalid eye quaternion")
    return {X=-q.X/n,Y=-q.Y/n,Z=-q.Z/n,W=q.W/n}
end

function M.quaternion(pitch,roll)
    local p,r=math.rad(pitch)/2,math.rad(roll)/2
    -- Unreal's positive Pitch/Roll use negative local Y/X quaternion axes.
    return M.multiply({X=0,Y=-math.sin(p),Z=0,W=math.cos(p)},
        {X=-math.sin(r),Y=0,Z=0,W=math.cos(r)})
end
local function clamp(value, limit) return math.max(-math.abs(limit), math.min(math.abs(limit), value)) end

function M.angles(direction, limit)
    local x, y, z = direction.X, direction.Y, direction.Z
    if x*x+y*y+z*z < 0.000001 then return 0, 0 end
    local pitch = -math.deg(math.atan(x, z))
    local roll = math.deg(math.atan(y, math.sqrt(x*x+z*z)))
    return clamp(pitch, limit.Pitch), clamp(roll, limit.Roll)
end

return M

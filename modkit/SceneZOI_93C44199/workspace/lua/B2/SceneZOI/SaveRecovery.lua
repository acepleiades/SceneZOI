-- Only original, scene-owned state is persisted; no scene resumes from a save.
local M={}
local function vector(v,keys)
    local result={}
    for i,key in ipairs(keys)do
        local n=v[key];assert(type(n)=='number'and n==n and math.abs(n)<1e12,'Invalid restoration coordinate')
        result[i]=n
    end
    return result
end
function M.capture(lease,furniture)
    if not lease then return nil end
    return {version=1,token=lease.token,collision=lease.collision,local_value=lease.local_value,follow_parent=lease.follow_parent,
        location=vector(lease.entry_location,{'X','Y','Z'}),rotation=vector(lease.entry_rotation,{'Pitch','Yaw','Roll'}),
        outfit=lease.outfit==true,body_merge=lease.body_merge and {base=lease.body_merge.base,final=lease.body_merge.final},
        furniture=furniture or {}}
end
function M.lease(data)
    if type(data)~='table'or data.version==nil then return nil end
    assert(data.version==1 and type(data.token)=='string'and #data.token<=256,'Invalid recovery version/token')
    for _,key in ipairs({'collision','local_value','follow_parent','outfit'})do assert(type(data[key])=='boolean','Invalid recovery flag')end
    local l=vector(data.location,{1,2,3});local r=vector(data.rotation,{1,2,3})
    local merge=data.body_merge
    if merge then assert(type(merge)=='table'and type(merge.base)=='boolean'and type(merge.final)=='boolean','Invalid recovery body layout')end
    local lent=data.lent_costume
    if lent~=nil then assert(type(lent)=='string'and #lent<=128 and lent:match('^[%w_%-]+$'),'Invalid recovery outfit')end
    local furniture={}
    assert(type(data.furniture)=='table'and #data.furniture<=4,'Invalid recovery furniture')
    for _,id in ipairs(data.furniture)do assert(type(id)=='string'and id:match('^%d+$'),'Invalid recovery furniture ID');furniture[#furniture+1]=id end
    return {token=data.token,releasing=true,remaining=0,restored={},collision=data.collision,local_value=data.local_value,
        follow_parent=data.follow_parent,outfit=data.outfit,lent_costume=lent,recovering=true,body_merge=merge and {base=merge.base,final=merge.final},
        entry_location=UE.FVector(table.unpack(l)),entry_rotation=UE.FRotator(table.unpack(r)),saved_furniture=furniture}
end
return M

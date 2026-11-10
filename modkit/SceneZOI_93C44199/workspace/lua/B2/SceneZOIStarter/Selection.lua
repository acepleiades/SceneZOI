-- Native picker adapter. Session membership is chosen here; no gameplay group is created.
local Protocol=require("SceneZOI.Protocol")
local Departure=require("SceneZOIStarter.GroupDeparture")
local Config=require("SceneZOI.Config")
local M={}
local pending,bound
local function id(value)return Protocol.id(value)end
local function entity(value)local v=inzoi.FB1EntityId();v.Value=tonumber(value);return v end
local function send(p,kind,detail)
    inzoi.message.send_to_client(entity(p.owner_id),"SceneZOIStarter.Selection",Protocol.pack(p.token,kind,detail or "none"))
end
function M.bind()bound=true end
function M.open(owner,token)
    assert(bound,"Native scene selection hooks are unavailable")
    assert(not pending,"A native scene selection is already open")
    local ok,_,data=inzoi.cli.execute("entity.get_possessed")
    local owner_id=id(owner:GetEntityId())
    assert(ok and data and data:match('"entity_id"%s*:%s*"?(%d+)')==owner_id,"Only the controlled Zoi can open Scene Mode")
    local p={token=token,owner_id=owner_id,last_heartbeat=os.time()}
    Departure.leave(owner)
    -- Let native departure packets reach B1 before it chooses Create versus Edit.
    pending=p;p.opening=2
end
function M.message(owner,fields)
    local p=pending
    if not p or p.owner_id~=id(owner:GetEntityId()) or p.token~=fields[1] then return end
    if fields[2]=="heartbeat" then p.last_heartbeat=os.time()
    elseif fields[2]=="shown" then send(p,"armed")
    elseif fields[2]=="solo" then if not p.ids then p.ids={p.owner_id};p.confirmed=not p.expired end
    elseif fields[2]=="closed" then p.closing=0
    elseif fields[2]=="cancel" then M.cancel(p.token) end
end
function M.create(leader,characters)
    local p=pending
    if not p or id(leader)~=p.owner_id then return false end
    -- The game lists the controlled Zoi only while it stays selected.
    local ids,seen={},{}
    for _,character in ipairs(characters) do
        local value=id(character:GetEntityId())
        if not seen[value] then seen[value]=true;ids[#ids+1]=value end
    end
    table.sort(ids,function(a,b)
        if a==b then return false end
        if a==p.owner_id then return true end
        if b==p.owner_id then return false end
        return tonumber(a)<tonumber(b)
    end)
    p.ids=ids;p.confirmed=not p.expired and #ids>=1 and #ids<=Config.picker_cap
    return true
end
function M.tick()
    local p=pending;if not p then return end
    if os.time()-p.last_heartbeat>8 and not p.expired then
        p.expired=true;send(p,"error",Protocol.encode("Native selection heartbeat expired"))
    end
    if p.opening then
        p.opening=p.opening-1
        if p.opening==0 then
            p.opening=nil
            local ok,err=pcall(function()
                local characters=assert(inzoi.getB2Manager("FB2EntityManager"))
                local owner=assert(characters:FindCharacter(entity(p.owner_id)),"The controlled Zoi is no longer loaded")
                assert(owner:GetZoiGroupId().Value==inzoi.FB1ZoiGroupId().Value,"The controlled Zoi rejoined a gameplay group")
                inzoi.getB2Manager("FB2ZoiGroupManager"):RequestOpenZoiGroupCreateWidget(owner,inzoi.EB1ZoiGroupEditReason.CreateGroup,nil)
            end)
            if not ok then pending=nil;send(p,"error",Protocol.encode(tostring(err)));return end
        end
    end
    if p.closing then
        p.closing=p.closing+1
        if p.closing<3 then return end
        if p.confirmed then
            local ok,err=pcall(function()
                local success,_,data=inzoi.cli.execute("entity.get_possessed")
                assert(success and data and data:match('"entity_id"%s*:%s*"?(%d+)')==p.owner_id,"The controlled Zoi changed during selection")
                local manager=assert(inzoi.getB2Manager("FB2EntityManager"))
                local roster={}
                for _,value in ipairs(p.ids) do roster[#roster+1]=assert(manager:FindCharacter(entity(value)),"A selected Zoi is no longer loaded") end
                for _,character in ipairs(roster) do Departure.leave(character) end
            end)
            if not ok then pending=nil;send(p,"error",Protocol.encode(tostring(err)));return end
        end
        send(p,p.confirmed and "selected" or "cancelled",p.confirmed and table.concat(p.ids,"+") or "none")
        pending=nil
    end
end
function M.cancel(token)
    if pending and pending.token==token then pending=nil end
end
function M.clear()
    pending=nil
    bound=false
end
return M

local Selection=require("SceneZOIStarter.Selection")
local Protocol=require("SceneZOI.Protocol")
local M={}
---@param self table
---@param owner FB2Character
---@param kind string
---@param content string
function M.on_lua_message(self,owner,kind,content)
    if kind=='SceneZOI.API.Depart'then
        local f=Protocol.unpack(content);if not f then return end
        local ok=pcall(require('SceneZOIStarter.GroupDeparture').leave,owner)
        local household=pcall(function()assert(inzoi.FB2ControllerSystem.IsPossessedHouseholdId(owner:GetHouseholdEntityId()))end)
        inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.API.DepartReply',Protocol.pack(f[1],ok and 'ok'or 'error',household and 'household'or 'npc'))
        return
    end
    if kind=='SceneZOI.FurnitureRecover'then
        local f=Protocol.unpack(content);if not f then return end
        if self.recovery_done and self.recovery_done[f[1]]then require('SceneZOI.SaveGuard').reply(owner,f[1],'furniture_recovered');return end
        local ok,beds=pcall(function()
            local rows=require('SceneZOI.Json').decode(assert(Protocol.decode(f[2])))
            assert(type(rows)=='table'and #rows<=4,'Invalid saved furniture')
            for _,id in ipairs(rows)do assert(type(id)=='string'and id:match('^%d+$'),'Invalid furniture ID')end
            return rows
        end)
        if ok then self.saved_beds=beds;self.recovery_request=f[1]end
        return
    end
    if kind=='SceneZOI.Furniture'then
        local ok,err=pcall(require('SceneZOI.FurnitureLease').message,owner,content)
        if not ok then
            local f=Protocol.unpack(content)
            if f then
                local leases=require('SceneZOI.FurnitureLease');local l=leases.leases[f[2]]
                if f[3]=='acquire' and l and l.token==f[1]then pcall(leases.release,f[2],l)end
            end
            if f then inzoi.message.send_to_client(owner:GetEntityId(),'SceneZOI.FurnitureReply',Protocol.pack(f[1],f[2],'error'))end
            print('[SceneZOI] Furniture request failed: '..tostring(err))
        end
        return
    end
    if kind~="SceneZOIStarter.Select" then return end
    local fields=Protocol.unpack(content)
    if not fields then return end
    local token=fields[1]
    local ok,err=pcall(function()
        if fields[2]=="open" then Selection.open(owner,token) else Selection.message(owner,fields) end
    end)
    if not ok then
        Selection.cancel(token)
        inzoi.message.send_to_client(owner:GetEntityId(),"SceneZOIStarter.Selection",Protocol.pack(token,"error",Protocol.encode(tostring(err))))
    end
end
---@param self table
---@param owner FB2Character
---@param dt number
function M.on_tick(self,owner,dt)
    if not self.saved_beds then return end
    local ok=pcall(require('SceneZOI.FurnitureLease').restore_saved,owner,self.saved_beds,self.recovery_request)
    if ok then
        local request=self.recovery_request;self.saved_beds=nil;self.recovery_request=nil
        self.recovery_done=self.recovery_done or {};self.recovery_done[request]=true
        require('SceneZOI.SaveGuard').reply(owner,request,'furniture_recovered')
    end
end
---@param self table
---@param owner FB2Character
function M.on_savegame(self,owner)
    require('SceneZOI.FurnitureLease').release_owner(owner)
    return {}
end
---@param self table
---@param owner FB2Character
function M.on_loadgame(self,owner)require('SceneZOI.FurnitureLease').release_owner(owner)end
---@param self table
---@param owner FB2Character
function M.on_end(self,owner)require('SceneZOI.FurnitureLease').release_owner(owner)end
return M

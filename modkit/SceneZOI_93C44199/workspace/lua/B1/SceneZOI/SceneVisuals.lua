-- Presentation-only leases on scene participants' selection markers. Never deactivate native FX.
-- Speech bubbles are handled at their source, per Zoi, by the B2 Scripts.B2Script_SpeechBubble chunk.
local M={}
local markers={}
local last_error
local function dead(object)
    local ok,valid=pcall(function()return UE.UKismetSystemLibrary.IsValid(object)end)
    return ok and valid==false
end
local function restore(leases,errors)
    for component,original in pairs(leases)do
        if dead(component)then leases[component]=nil
        else
            local ok,err=pcall(function()
                -- Another owner has already changed it; do not overwrite them.
                if component.bHiddenInGame==true then component:SetHiddenInGame(original,false)end
            end)
            if ok then leases[component]=nil else errors[#errors+1]=tostring(err)end
        end
    end
end
local function count(leases)local n=0;for _ in pairs(leases)do n=n+1 end;return n end

function M.restore()
    local errors={}
    restore(markers,errors)
    return #errors==0,table.concat(errors,'; ')
end

function M.tick(actors,active,members)
    local errors={}
    if active then
        local seen={}
        for id,actor in pairs(actors)do
            if members and members[id]then
                local ok,err=pcall(function()
                    local component=actor.PlayerSelectedFxComponent
                    if not component or dead(component)then return end
                    seen[component]=true
                    if markers[component]==nil then
                        local original=component.bHiddenInGame
                        if type(original)~='boolean'then return end
                        markers[component]=original
                    end
                    if not component.bHiddenInGame then component:SetHiddenInGame(true,false)end
                end)
                if not ok then errors[#errors+1]=tostring(err)end
            end
        end
        -- A replaced/unregistered actor must not retain our presentation flag.
        local retiring={}
        for component,original in pairs(markers)do if not seen[component]then retiring[component]=original end end
        restore(retiring,errors)
        for component in pairs(markers)do if not seen[component]and retiring[component]==nil then markers[component]=nil end end
    else
        local ok,err=M.restore();if not ok then errors[#errors+1]=err end
    end
    local message=table.concat(errors,'; '):sub(1,1000)
    if message~=''and message~=last_error then print('[SceneZOI] Overhead visuals will retry: '..message)end
    last_error=message~=''and message or nil
    return {markers=count(markers),error=last_error}
end
return M

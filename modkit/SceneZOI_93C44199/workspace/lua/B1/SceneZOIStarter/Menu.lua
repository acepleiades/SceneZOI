-- Hide only this integration's rendered entry. NPC injection bypasses the talk list's item array.
local M={}
local marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_demo"
local furniture_marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_furniture"
local last_error
local function update(actors,ready,dt)
    local _,actor=next(actors);if not actor then return end
    local controller=UE.UGameplayStatics.GetPlayerController(actor,0);if not controller then return end
    local controlled=tostring(controller:GetCharacterEntityId().Value)
    local controlled_actor=actors[controlled]
    if controlled_actor then require('SceneZOI.Furniture').tick(dt or 0,controlled_actor)end
    for _,class in ipairs({inzoi.UB1ObjectInteractionListEntry:StaticClass(),inzoi.UB1TalkInteractionListEntry:StaticClass()}) do
        for _,entry in ipairs(UE.UWidgetBlueprintLibrary.GetAllWidgetsOfClass(actor,nil,class,false)) do
            local data=entry.Data
            if data and tostring(data.InteractionBagId)==marker then
                entry:SetVisibility(ready and tostring(data.TargetEntityId.Value)==controlled and 0 or 1)
            elseif data and tostring(data.InteractionBagId)==furniture_marker then
                local profile=require('SceneZOI.Furniture').available(tostring(data.TargetEntityId.Value))
                local nodes=require('SceneZOI.Catalog').get_snapshot().nodes
                local eligible=false
                if profile then for _,node in pairs(nodes)do
                    if node.starting_hub and require('SceneZOI.FurnitureData').compatible(node,profile)then eligible=true;break end
                end end
                entry:SetVisibility(ready and eligible and 0 or 1)
            end
        end
    end
end
function M.tick(actors,ready,dt)
    local ok,err=pcall(update,actors,ready,dt)
    if not ok and tostring(err)~=last_error then
        last_error=tostring(err);print("[SceneZOI] Demo menu filtering failed: "..last_error)
    elseif ok then last_error=nil end
    return ok,err
end
return M

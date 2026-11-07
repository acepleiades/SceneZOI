-- Hide only this integration's rendered entry. NPC injection bypasses the talk list's item array.
local M={}
local marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_demo"
local furniture_marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_furniture"
local last_error
local collapsed=1
local hidden={}

local function restore(entry)
    local original=hidden[entry]
    if original==nil then return end
    hidden[entry]=nil
    -- Only undo our own visibility change; a fresh native value wins.
    if entry:GetVisibility()==collapsed then entry:SetVisibility(original)end
end

function M.stop()
    -- Entries may already be destroyed on world or mod teardown.
    for entry in pairs(hidden)do pcall(restore,entry)end
end

local function filter(entry,eligible,kept)
    if eligible then restore(entry);return end
    local visibility=entry:GetVisibility()
    if visibility~=collapsed then
        entry:SetVisibility(collapsed)
        hidden[entry]=visibility
    end
    if hidden[entry]~=nil then kept[entry]=true end
end
local function update(actors,ready,dt)
    local _,actor=next(actors);if not actor then M.stop();return end
    local controller=UE.UGameplayStatics.GetPlayerController(actor,0);if not controller then M.stop();return end
    local controlled=tostring(controller:GetCharacterEntityId().Value)
    local controlled_actor=actors[controlled]
    if controlled_actor then require('SceneZOI.Furniture').tick(dt or 0,controlled_actor)end
    local kept={}
    for _,class in ipairs({inzoi.UB1ObjectInteractionListEntry:StaticClass(),inzoi.UB1TalkInteractionListEntry:StaticClass()}) do
        for _,entry in ipairs(UE.UWidgetBlueprintLibrary.GetAllWidgetsOfClass(actor,nil,class,false)) do
            local data=entry.Data
            if data and(tostring(data.InteractionBagId)==marker or tostring(data.InteractionBagId)==furniture_marker)then
                local caption=entry.BW_Text_Content or entry.BW_CategoryText
                if caption then caption:SetText(require('SceneZOI.Localization').text('Start SceneZOI'))end
            end
            if data and tostring(data.InteractionBagId)==marker then
                filter(entry,ready and tostring(data.TargetEntityId.Value)==controlled,kept)
            elseif data and tostring(data.InteractionBagId)==furniture_marker then
                local profile=require('SceneZOI.Furniture').available(tostring(data.TargetEntityId.Value))
                local nodes=require('SceneZOI.Catalog').get_snapshot().nodes
                local eligible=false
                if profile then for _,node in pairs(nodes)do
                    if node.starting_hub and require('SceneZOI.FurnitureData').compatible(node,profile)then eligible=true;break end
                end end
                filter(entry,ready and eligible,kept)
            else
                restore(entry)
            end
        end
    end
    -- Native list rows can disappear before their next data binding.
    for entry in pairs(hidden)do if not kept[entry]then pcall(restore,entry)end end
end
function M.tick(actors,ready,dt)
    local ok,err=pcall(update,actors,ready,dt)
    if not ok then M.stop()end
    if not ok and tostring(err)~=last_error then
        last_error=tostring(err);print("[SceneZOI] Demo menu filtering failed: "..last_error)
    elseif ok then last_error=nil end
    return ok,err
end
return M

-- Style and filter owned entries. Native list widgets can be reused by other interactions.
local M={}
local Settings=require('SceneZOI.Settings')
local marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_demo"
local furniture_marker="_UIMod_SceneZOI_93C44199/scenezoi-starter~scenezoi_furniture"
local venue_kinds={['bed.single']=true,['bed.queen']=true,['sofa.pair']=true}
local last_error
local collapsed=1
local icon_visible=4 -- SelfHitTestInvisible
local changed={}

local function restore(widget)
    local previous=changed[widget]
    if not previous then return end
    changed[widget]=nil
    -- Only undo our own visibility change; a fresh native value wins.
    if widget:GetVisibility()==previous.applied then widget:SetVisibility(previous.original)end
end

function M.stop()
    -- Entries may already be destroyed on world or mod teardown.
    for widget in pairs(changed)do pcall(restore,widget)end
end

local function set_visibility(widget,value,kept)
    if not widget then return end
    kept[widget]=true
    local original=widget:GetVisibility()
    if original~=value then
        widget:SetVisibility(value)
        changed[widget]={original=original,applied=value}
    end
end

local function filter(entry,eligible,kept)
    if eligible then restore(entry) else set_visibility(entry,collapsed,kept)end
end

local function style(entry,is_object,kept)
    local tag=is_object and entry.SizeBox_Tag or not is_object and entry.BW_SizeBox_Tag
    set_visibility(tag,collapsed,kept)
    set_visibility(entry.BW_Image_Modkit,icon_visible,kept)
end
local function update(actors,ready,dt)
    local _,actor=next(actors);if not actor then M.stop();return end
    local controller=UE.UGameplayStatics.GetPlayerController(actor,0);if not controller then M.stop();return end
    local controlled=tostring(controller:GetCharacterEntityId().Value)
    local controlled_actor=actors[controlled]
    local furniture=require('SceneZOI.Furniture')
    if controlled_actor then furniture.tick(dt or 0,controlled_actor)end
    local kept={}
    local debug_start=Settings.debug_start_enabled()
    local object_class=inzoi.UB1ObjectInteractionListEntry:StaticClass()
    for _,class in ipairs({object_class,inzoi.UB1TalkInteractionListEntry:StaticClass()}) do
        for _,entry in ipairs(UE.UWidgetBlueprintLibrary.GetAllWidgetsOfClass(actor,nil,class,false)) do
            local data=entry.Data
            local key=data and tostring(data.InteractionBagId)
            local is_object=class==object_class
            if key==marker or key==furniture_marker then
                local solo=key==marker and not debug_start
                local caption=is_object and entry.BW_Text_Content or not is_object and entry.BW_CategoryText
                local eligible
                if caption then caption:SetText(require('SceneZOI.Localization').text(solo and 'Solo SceneZOI Session' or '(Debug) SceneZOI manual start'))end
                if key==marker then
                    eligible=ready and tostring(data.TargetEntityId.Value)==controlled
                else
                    local profile=ready and debug_start and furniture.pickable(tostring(data.TargetEntityId.Value))
                    if profile then
                        for _,node in pairs(require('SceneZOI.Catalog').get_snapshot().nodes)do
                            if node.starting_hub and require('SceneZOI.FurnitureData').compatible(node,profile)then eligible=true;break end
                        end
                    end
                end
                filter(entry,eligible,kept)
                if eligible then style(entry,is_object,kept)end
            elseif is_object and key and key:match("^_UIMod_[^/]+/[^~]+~scenezoi_furniture$") then
                -- An add-on can opt its native object trigger into the same
                -- profile lookup. Its picker owns participant and vacancy checks.
                local target=data.TargetEntityId and tostring(data.TargetEntityId.Value)
                local profile=controlled_actor and target and furniture.profile(target)
                local eligible=profile and venue_kinds[profile.kind]
                filter(entry,eligible,kept)
                if eligible then style(entry,true,kept)end
            else
                restore(entry)
            end
        end
    end
    -- Native list rows can disappear before their next data binding.
    for widget in pairs(changed)do if not kept[widget]then pcall(restore,widget)end end
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

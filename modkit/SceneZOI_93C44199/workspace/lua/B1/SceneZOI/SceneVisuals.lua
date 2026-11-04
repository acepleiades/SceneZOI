-- Presentation-only leases. Never deactivate native FX or stop bubble lifetimes.
local M={}
local markers,bubbles={},{}
local last_error
local function dead(object)
    local ok,valid=pcall(function()return UE.UKismetSystemLibrary.IsValid(object)end)
    return ok and valid==false
end
local function restore(leases,read,write,suppressed,errors)
    for object,original in pairs(leases)do
        if dead(object)then leases[object]=nil
        else
            local ok,err=pcall(function()
                -- Another owner has already changed it; do not overwrite them.
                if read(object)==suppressed then write(object,original)end
            end)
            if ok then leases[object]=nil else errors[#errors+1]=tostring(err)end
        end
    end
end
local function marker_read(c)return c.bHiddenInGame end
local function marker_write(c,v)c:SetHiddenInGame(v,false)end
local function bubble_read(w)return w:GetRenderOpacity()end
local function bubble_write(w,v)w:SetRenderOpacity(v)end
local function count(leases)local n=0;for _ in pairs(leases)do n=n+1 end;return n end

function M.restore()
    local errors={}
    restore(markers,marker_read,marker_write,true,errors)
    restore(bubbles,bubble_read,bubble_write,0,errors)
    return #errors==0,table.concat(errors,'; ')
end

local bubble_parts={
    'BW_WidgetSwitcher_BubbleType','BW_WidgetSwitcher_Icon','BW_WidgetSwitcher_Type',
    'BW_Overlay_SubIcon','BW_Overlay_Listen','BW_HorizontalBox_Dot','BW_Text_RoleName',
    'BW_Image_Category','BW_Image_Gradient_Negative','BW_Image_Gradient_Talking','BW_Image_Gradient_Think',
    'BW_Image_GroupBG','BW_Image_GroupIcon','BW_Image_New','BW_Image_Portrait','BW_Image_SubIcon',
    'BW_Image_Warning','Image_Icon','Text_Speech','BW_WBP_Listen',
}
local function suppress_bubble(part)
    if not part or dead(part)then return end
    if bubbles[part]==nil then bubbles[part]=bubble_read(part)end
    if bubble_read(part)~=0 then bubble_write(part,0)end
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
                    local original=marker_read(component)
                    if type(original)~='boolean'then return end
                    markers[component]=original
                end
                if not marker_read(component)then marker_write(component,true)end
            end)
            if not ok then errors[#errors+1]=tostring(err)end
            end
        end
        -- A replaced/unregistered actor must not retain our presentation flag.
        local retiring={}
        for c,v in pairs(markers)do if not seen[c]then retiring[c]=v end end
        restore(retiring,marker_read,marker_write,true,errors)
        for c in pairs(markers)do if not seen[c]and retiring[c]==nil then markers[c]=nil end end
        local _,context=next(actors)
        if context then
            local ok,err=pcall(function()
                local class=inzoi.UB1SpeechBubbleWidget:StaticClass()
                for _,widget in ipairs(UE.UWidgetBlueprintLibrary.GetAllWidgetsOfClass(context,nil,class,false))do
                    if not dead(widget)then
                        -- Capture before mutation so a partially failing setter can retry.
                        suppress_bubble(widget)
                        -- Bubble animations can refresh the wrapper independently of these
                        -- exported visual children. Keep each child's original opacity too.
                        for _,name in ipairs(bubble_parts)do suppress_bubble(widget[name])end
                    end
                end
            end)
            if not ok then errors[#errors+1]=tostring(err)end
        end
        for widget in pairs(bubbles)do if dead(widget)then bubbles[widget]=nil end end
    else
        local ok,err=M.restore();if not ok then errors[#errors+1]=err end
    end
    local message=table.concat(errors,'; '):sub(1,1000)
    if message~=''and message~=last_error then print('[SceneZOI] Overhead visuals will retry: '..message)end
    last_error=message~=''and message or nil
    return {markers=count(markers),bubbles=count(bubbles),error=last_error}
end
return M

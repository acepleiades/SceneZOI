-- Demo entry policy and the native picker adapter; separate from framework sessions.
local Config=require("SceneZOI.Config")
local Protocol=require("SceneZOI.Protocol")
local M={}
local pending,last_request,elapsed,host_token,ui_ready
local function cfg(command,key,value)
    local line=command.." mod_id="..Config.mod_id.." section="..Config.section.." key="..key
    if value then line=line.." value="..value end
    local ok,message,data=inzoi.cli.execute(line)
    if command=="uimod.cfg_load" and not ok then return nil end
    assert(ok,message);return data or message
end
local function publish(token,kind,detail,node,bindings) cfg("uimod.cfg_save","selection_state",Protocol.pack(token,kind,detail or "none",node or "none",bindings or "none",pending and pending.furniture or "none")) end
local function tell(p,kind) inzoi.message.send_to_sim(p.actor:GetEntityId(),"SceneZOIStarter.Select",Protocol.pack(p.token,kind)) end
local function widget()
    local ui=inzoi.UB1System.Get().ManagerMap:Find(inzoi.EB1ManagerType.UI)
    for _,handler in pairs(ui.UIHandlerMap:ToTable()) do
        if handler:IsA(inzoi.UB1ZoiGroupEditUIHandler:StaticClass()) then return handler.SelectWidget end
    end
    error("Native Zoi selector is unavailable")
end
local function restore_cap(p)
    if p.asset then p.asset.MaxZoiGroupMemberNum:Add(inzoi.EB1ZoiGroupType.Default,p.old_cap);p.asset=nil end
end
-- A lone Zoi can start only where a one-role starting scene fits its body and the clicked furniture.
local function solo_start(actor,furniture)
    require("SceneZOI.DataFiles").refresh()
    local Catalog=require("SceneZOI.Catalog");Catalog.refresh()
    local profile=furniture and require("SceneZOI.Furniture").available(furniture) or nil
    return require("SceneZOI.StartingScenes").choose(Catalog.get_snapshot().nodes,{require("SceneZOI.Traits").capture(actor)},nil,profile)~=nil
end
local function caption(p,solo)
    if p.solo_caption==solo then return end
    p.solo_caption=solo
    local text=p.widget.BW_WBP_ButtonOK.BW_Text
    if solo then
        p.ok_caption=p.ok_caption or tostring(text:GetText())
        text:SetText(require("SceneZOI.Localization").text("Start Solo"))
    elseif p.ok_caption then text:SetText(p.ok_caption) end
end
-- The Esc Game Menu over the picker. From B1 the open menu shows as a pause reason ("GameMenu", beside the picker's
-- own "ZoiGroupSelect") while blocked stays false; the panel's rule (a modal UI of type GameMenu) is kept as well.
local function game_menu_open()
    local ok,success,message,data=pcall(inzoi.cli.execute,"ui.get_blocking")
    if not ok or not success then return false end
    local parsed,state=pcall(require("SceneZOI.Json").decode,data or message or "")
    if not parsed or type(state)~="table" then return false end
    if type(state.pause_reasons)=="table" then
        for _,reason in ipairs(state.pause_reasons) do if reason=="GameMenu" then return true end end
    end
    return state.blocked==true and state.primary_kind=="modal_ui" and state.input_block_ui_type=="GameMenu"
end
-- While the Game Menu is up the picker is hidden, and it comes back as it was when the menu closes. A picker hidden
-- this way is still open: it is neither a close nor a cancel.
local function hide_for_menu(p)
    if p.menu_hidden~=nil then return end
    p.menu_hidden=p.widget:GetVisibility()
    p.widget:SetVisibility(2) -- Hidden: keeps its layout, takes no input
end
local function show_after_menu(p)
    if p.menu_hidden==nil then return end
    p.widget:SetVisibility(p.menu_hidden)
    p.menu_hidden=nil
end
local function release(p,close)
    restore_cap(p)
    if p.widget and p.menu_hidden~=nil then pcall(show_after_menu,p) end
    if p.widget and p.opened then
        if close and p.widget:IsVisible() then p.widget:OnClickedClose() end
        caption(p,false)
        p.widget.BW_WBP_GroupOption:SetVisibility(p.option_visibility)
        p.widget.BW_WBP_ButtonOK.BW_Button:SetIsEnabled(true)
    end
end
function M.boot()
    last_request=cfg("uimod.cfg_load","selection_request");elapsed=0
    -- Native cfg_load rejects missing keys; a new install has no request yet.
    if last_request==nil then
        last_request="none"
        cfg("uimod.cfg_save","selection_request",last_request)
    end
    host_token="host."..os.time().."."..math.random(1,1073741823);ui_ready=false
    cfg("uimod.cfg_save","selection_ui_ready","none")
    cfg("uimod.cfg_save","selection_launcher_ready","none")
    cfg("uimod.cfg_save","selection_host_ready",Protocol.pack(host_token,"ready","none"))
end
function M.is_ready()return ui_ready==true end
function M.reply(actor,content)
    local fields=Protocol.unpack(content)
    if pending and pending.actor==actor and fields and fields[1]==pending.token then
        if fields[2]=="armed" then pending.armed=true else pending.result=fields end
    end
end
function M.stop()
    local p=pending;if not p then return end
    pending=nil;release(p,true);tell(p,"cancel")
end
local function update(dt,actors,busy)
    elapsed=(elapsed or 0)+dt
    if elapsed>=.2 then
        elapsed=0
        local frontend=Protocol.unpack(cfg("uimod.cfg_load","selection_ui_ready"))
        local launcher=Protocol.unpack(cfg("uimod.cfg_load","selection_launcher_ready"))
        ui_ready=frontend and frontend[1]==host_token and frontend[2]=="ready" and
            launcher and launcher[1]=="launcher" and launcher[2]=="ready" or false
        local raw=cfg("uimod.cfg_load","selection_request")
        local fields=Protocol.unpack(raw)
        if raw~=last_request and fields then
            last_request=raw
            if fields[2]=="open" and busy then
                pcall(require('SceneZOI.Localization').toast,'A SceneZOI scene is already in progress. End it before starting another.')
                publish(fields[1],'unavailable','busy')
            elseif fields[2]=="open" and not pending then
                require("SceneZOI.Localization").refresh()
                local actor=actors[fields[3]]
                if not actor then
                    pcall(require('SceneZOI.Runtime').publish_actor_registration_status,fields[3])
                    error("The controlled Zoi is not loaded")
                end
                local furniture=fields[4]~='none'and fields[4]or nil
                if furniture then assert(require('SceneZOI.Furniture').available(furniture),'The bed is unavailable')end
                local w=widget();assert(not w:IsVisible(),"A native Zoi picker is already open")
                local checked,solo=pcall(solo_start,actor,furniture)
                if not checked then print("[SceneZOI] Solo start unavailable: "..tostring(solo)) end
                local asset=assert(UE.UObject.Load("/Game/Data/DataAsset/DA_ZoiGroup.DA_ZoiGroup"))
                pending={token=fields[1],actor=actor,widget=w,asset=asset,furniture=furniture,solo=checked and solo or false,
                    old_cap=asset.MaxZoiGroupMemberNum:Find(inzoi.EB1ZoiGroupType.Default),
                    option_visibility=w.BW_WBP_GroupOption:GetVisibility(),age=0,heartbeat=0}
                asset.MaxZoiGroupMemberNum:Add(inzoi.EB1ZoiGroupType.Default,Config.picker_cap)
                tell(pending,"open");publish(pending.token,"opening")
            elseif fields[2]=="cancel" and pending and pending.token==fields[1] then M.stop() end
        end
    end
    local p=pending;if not p then return end
    p.age,p.heartbeat=p.age+dt,p.heartbeat+dt
    if p.opened and not p.closed then
        p.menu_check=(p.menu_check or 0)-dt
        if p.menu_check<=0 then
            p.menu_check=0.2
            if game_menu_open() then hide_for_menu(p) else show_after_menu(p) end
        end
    end
    if p.heartbeat>=1 then p.heartbeat=0;tell(p,"heartbeat") end
    if p.widget:IsVisible() then
        if not p.opened then
            p.opened=true
            restore_cap(p);tell(p,"shown");publish(p.token,"selecting")
        end
        p.widget.BW_WBP_GroupOption:SetVisibility(1)
        p.widget.BW_Text_MainTitle:SetText(require("SceneZOI.Localization").text("Start SceneZOI"))
        local count=tonumber(tostring(p.widget.BW_Text_TitleNum:GetText()):match("%d+")) or 0
        local alone=p.solo and count==1
        local can_start=p.armed and (alone or count>=2 and count<=Config.picker_cap) or false
        local button=p.widget.BW_WBP_ButtonOK.BW_Button
        button:SetIsEnabled(can_start)
        p.widget.BW_WBP_ButtonOK.bIsDimmed=not can_start
        caption(p,alone)
        -- With nobody else picked the game just closes the picker and reports nothing. Start Solo needs an explicit
        -- click: the button held down (IsPressed), not a pointer resting on it. Closing the picker (X, Esc, its close
        -- handler) never presses it, however close the pointer was. If the press cannot be read, nothing starts.
        if alone and can_start then
            local read,pressed=pcall(function() return button:IsPressed() end)
            if read and pressed==true then p.start_pressed=p.age end
        end
    elseif p.opened and not p.closed and p.menu_hidden==nil then
        p.closed=true;release(p,false)
        if p.start_pressed and p.age-p.start_pressed<=Config.solo_click_window then tell(p,"solo") end
        tell(p,"closed")
    elseif not p.opened and p.age>4 then error("Native Zoi selection did not open") end
    if p.result and p.result[2]=="error" and not p.closed then
        p.closed=true;release(p,true);tell(p,"closed")
    end
    if p.result and not p.opened then p.closed=true;release(p,false) end
    if p.result and p.closed then
        if p.result[2]=="error" or p.result[2]=="unavailable" then
            require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
        end
        if p.result[2]=="selected"then
            local Files=require("SceneZOI.DataFiles");Files.refresh()
            local Catalog=require("SceneZOI.Catalog");Catalog.refresh()
            local roster,ids,loaded,with_self,held={},{},true,false,false
            local self_id=Protocol.id(p.actor:GetEntityId())
            for id in p.result[3]:gmatch("[^+]+")do
                ids[#ids+1]=id
                if id==self_id then with_self=true end
                if require("SceneZOI.Sessions").holder(id) then held=true end
                if actors[id] then roster[#roster+1]=require("SceneZOI.Traits").capture(actors[id]) else loaded=false end
            end
            local profile
            if p.furniture then profile=assert(require('SceneZOI.Furniture').available(p.furniture),'The bed became unavailable during selection')end
            local chosen=loaded and not held and require("SceneZOI.StartingScenes").choose(Catalog.get_snapshot().nodes,roster,nil,profile) or nil
            -- With the controlled Zoi unselected the scene runs between the others, on the background path.
            local npc_started=chosen and not with_self and pcall(require("SceneZOI.AddonAPI").start_from_picker,p.actor,ids,chosen,p.furniture)
            if npc_started then
                require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
                publish(p.token,"unavailable","npc_scene")
            elseif chosen and with_self then
                local roles={};for role,id in pairs(chosen.bindings)do roles[#roles+1]=role..":"..id end;table.sort(roles)
                publish(p.token,"selected",p.result[3],chosen.node,table.concat(roles,"+"))
            else
                pcall(require('SceneZOI.Localization').toast,held and 'A participant is already owned by another scene.' or 'SceneZOI could not find a suitable starting scene for the selected Zois.')
                require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
                publish(p.token,"unavailable",held and "participant_busy" or "no_starting_scene")
            end
        else publish(p.token,p.result[2],p.result[3])end
        pending=nil
    end
end
function M.tick(dt,actors,busy)
    local ok,err=pcall(update,math.max(tonumber(dt) or 0,0),actors,busy)
    if not ok then
        local fields=Protocol.unpack(last_request)
        local token=pending and pending.token or fields and fields[1]
        pcall(cfg,"uimod.cfg_save","selection_error",Protocol.encode(tostring(err)))
        local rejected_actor=pending and pending.actor or fields and actors[fields[3]]
        if rejected_actor and token then require('SceneZOI.Runtime').authorize_rejected_focus(rejected_actor,token)end
        M.stop()
        if token then publish(token,"error",Protocol.encode(tostring(err))) end
        print("[SceneZOI] Native selection failed: "..tostring(err))
    end
end
return M

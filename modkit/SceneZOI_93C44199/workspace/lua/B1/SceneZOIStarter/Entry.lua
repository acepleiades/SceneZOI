-- Solo entry and the debug picker adapter share the existing session start handshake.
local Config=require("SceneZOI.Config")
local Diagnostics=require("SceneZOI.Diagnostics")
local Protocol=require("SceneZOI.Protocol")
local Json=require("SceneZOI.Json")
local Settings=require("SceneZOI.Settings")
local M={}
local pending,last_request,elapsed,host_token,ui_ready
local function cfg(command,key,value)
    local line=command.." mod_id="..Config.mod_id.." section="..Config.section.." key="..key
    if value then line=line.." value="..value end
    local ok,message,data=inzoi.cli.execute(line)
    if command=="uimod.cfg_load" and not ok then return nil end
    assert(ok,message);return data or message
end
local function publish(token,kind,detail,node,bindings,context)
    local source = context or pending
    local furniture = source and source.furniture
    cfg("uimod.cfg_save","selection_state",Protocol.pack(token,kind,detail or "none",node or "none",bindings or "none",furniture or "none",source and source.furniture_pair_id or 'none',
        kind=='choosing_pair'and source and Protocol.encode(Json.encode(source.pair_choices))or 'none'))
    if kind=="selected" or kind=="unavailable" or kind=="error" then
        Diagnostics.record("picker_"..kind, {picker_id=token, scene_id=node, bindings=bindings, furniture_id=furniture,
            code=kind=="unavailable" and detail or kind=="error" and "selection_error" or "ok",
            furniture_pair_id=source and source.furniture_pair_id})
    end
end
-- Expected manual-start denials need one short explanation, without opening a
-- scene or turning an unavailable pair into a technical error/Dismiss panel.
local function reject_sofa(p,code,message)
    require('SceneZOI.Runtime').authorize_rejected_focus(p.actor,p.token)
    pcall(require('SceneZOI.Localization').toast,message)
    publish(p.token,'unavailable',code,nil,nil,p)
end
local function tell(p,kind) require("SceneZOI.SimulationRoute").send(p.actor,"SceneZOIStarter.Select",Protocol.pack(p.token,kind)) end
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
local function solo_start(actor,furniture,ratings)
    local profile=furniture and require("SceneZOI.Furniture").pickable(furniture) or nil
    return require("SceneZOI.StartingScenes").choose(require("SceneZOI.Catalog").get_snapshot().nodes,
        {require("SceneZOI.Traits").capture(actor)},nil,profile,ratings)
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
        if p.partner_callback then
            p.widget.BW_WBP_ButtonOK.BW_Text:SetText(p.ok_caption)
            p.widget.BW_Text_MainTitle:SetText(p.original_title)
            p.widget.BW_WBP_ButtonOK.bIsDimmed=p.original_dimmed
        else
            caption(p,false)
        end
        p.widget.BW_WBP_GroupOption:SetVisibility(p.option_visibility)
        p.widget.BW_WBP_ButtonOK.BW_Button:SetIsEnabled(true)
    end
end
function M.open_partner(actor,callback)
    local w=widget()
    assert(not pending and not w:IsVisible(),"picker_busy")
    local asset=assert(UE.UObject.Load("/Game/Data/DataAsset/DA_ZoiGroup.DA_ZoiGroup"),"picker_unavailable")
    local p={token="partner."..os.time().."."..math.random(1,1073741823),actor=actor,widget=w,asset=asset,
        old_cap=asset.MaxZoiGroupMemberNum:Find(inzoi.EB1ZoiGroupType.Default),
        option_visibility=w.BW_WBP_GroupOption:GetVisibility(),age=0,heartbeat=0,partner_callback=callback}
    asset.MaxZoiGroupMemberNum:Add(inzoi.EB1ZoiGroupType.Default,2)
    pending=p
    tell(p,"open_partner")
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
    -- The launcher view can outlive this Lua host. Its readiness belongs to the UI pair.
    cfg("uimod.cfg_save","selection_host_ready",Protocol.pack(host_token,"ready","none"))
end
function M.is_ready()return ui_ready==true end
function M.reply(actor,content)
    local fields=Protocol.unpack(content)
    if pending and pending.actor==actor and fields and fields[1]==pending.token then
        if fields[2]=="armed" then pending.armed=true else pending.result=fields end
    end
end
function M.stop(partner_code)
    local p=pending;if not p then return end
    pending=nil
    require("SceneZOI.SimulationRoute").discard("SceneZOIStarter.Select",Protocol.pack(p.token,p.partner_callback and "open_partner" or "open"))
    release(p,true);tell(p,"cancel")
    if p.partner_callback then p.partner_callback(partner_code or "cancelled") end
end
local function update(dt,actors,busy)
    elapsed=(elapsed or 0)+dt
    if elapsed>=.2 then
        elapsed=0
        local frontend=Protocol.unpack(cfg("uimod.cfg_load","selection_ui_ready"))
        local launcher=Protocol.unpack(cfg("uimod.cfg_load","selection_launcher_ready"))
        ui_ready=frontend and frontend[1]==host_token and frontend[2]=="ready" and
            launcher and launcher[2]=="ready" and frontend[3]~=nil and
            launcher[3]==frontend[3] and launcher[1]==frontend[4] or false
        local raw=cfg("uimod.cfg_load","selection_request")
        local fields=Protocol.unpack(raw)
        if raw~=last_request and fields then
            last_request=raw
            if fields[2]=="open" and busy then
                pcall(require('SceneZOI.Localization').toast,'A SceneZOI session is already in progress. End it before starting another.')
                publish(fields[1],'unavailable','busy')
            elseif fields[2]=="open" and not pending then
                require("SceneZOI.Localization").refresh()
                local actor=actors[fields[3]]
                if not actor then
                    pcall(require('SceneZOI.Runtime').publish_actor_registration_status,fields[3])
                    error("The controlled Zoi is not loaded")
                end
                local furniture=fields[4]~='none'and fields[4]or nil
                if not Settings.debug_start_enabled() then
                    assert(not furniture,"Furniture starts require debug mode")
                    assert(require('SceneZOI.Controller').controlled_id(actors)==fields[3],"The controlled Zoi changed before Solo Start")
                    local held=require('SceneZOI.Sessions').holder(fields[3])
                    local chosen=not held and solo_start(actor,nil,{"GENERAL"})
                    if chosen then
                        local role,id=next(chosen.bindings)
                        publish(fields[1],"selected",id,chosen.node,role..":"..id)
                    else
                        require('SceneZOI.Runtime').authorize_rejected_focus(actor,fields[1])
                        pcall(require('SceneZOI.Localization').toast,held and 'A participant is already in another session.' or 'SceneZOI could not find a suitable starting scene for the selected Zois.')
                        publish(fields[1],"unavailable",held and "participant_busy" or "no_starting_scene")
                    end
                    return
                end
                local furniture_kind
                if furniture then
                    local Furniture=require('SceneZOI.Furniture')
                    local profile=Furniture.pickable(furniture)
                    local declared=profile or Furniture.profile and Furniture.profile(furniture)
                    furniture_kind=declared and declared.kind
                    if not profile and furniture_kind=='sofa.pair'then
                        reject_sofa({token=fields[1],actor=actor,furniture=furniture},'sofa_unavailable',
                            'The requested seats on this sofa are unavailable for this scene.')
                        return
                    end
                    assert(profile,'The furniture is unavailable')
                end
                local w=widget();assert(not w:IsVisible(),"A native Zoi picker is already open")
                local checked,solo=pcall(solo_start,actor,furniture)
                if not checked then print("[SceneZOI] Solo start unavailable: "..tostring(solo)) end
                local asset=assert(UE.UObject.Load("/Game/Data/DataAsset/DA_ZoiGroup.DA_ZoiGroup"))
                pending={token=fields[1],actor=actor,widget=w,asset=asset,furniture=furniture,furniture_kind=furniture_kind,solo=checked and solo~=nil,
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
            if p.partner_callback then
                p.ok_caption=tostring(p.widget.BW_WBP_ButtonOK.BW_Text:GetText())
                p.original_title=tostring(p.widget.BW_Text_MainTitle:GetText())
                p.original_dimmed=p.widget.BW_WBP_ButtonOK.bIsDimmed
            else publish(p.token,"selecting") end
            restore_cap(p);tell(p,"shown")
        end
        p.widget.BW_WBP_GroupOption:SetVisibility(1)
        local text=require("SceneZOI.Localization").text
        p.widget.BW_Text_MainTitle:SetText(text(p.partner_callback and "Choose a partner" or "(Debug) SceneZOI manual start"))
        local count=tonumber(tostring(p.widget.BW_Text_TitleNum:GetText()):match("%d+")) or 0
        local alone=p.solo and count==1
        local count_allowed
        if p.partner_callback then count_allowed=count==1 or count==2
        else count_allowed=alone or count>=2 and count<=Config.picker_cap end
        local can_start=p.armed and count_allowed or false
        local button=p.widget.BW_WBP_ButtonOK.BW_Button
        button:SetIsEnabled(can_start)
        p.widget.BW_WBP_ButtonOK.bIsDimmed=not can_start
        if p.partner_callback then
            p.widget.BW_WBP_ButtonOK.BW_Text:SetText(text("Invite"))
        else caption(p,alone) end
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
        if p.partner_callback then
            pending=nil
            local kind=p.result[2]
            p.partner_callback(kind=="error" and "picker_unavailable" or kind,kind=="selected" and p.result[3] or nil)
            return
        end
        if p.result[2]=="error" or p.result[2]=="unavailable" then
            require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
        end
        if p.result[2]=="selected"then
            if p.awaiting_pair then
                local choice=Protocol.unpack(cfg('uimod.cfg_load','selection_pair'))
                if not choice or choice[1]~=p.token then return end
                if choice[2]=='cancel'then
                    require('SceneZOI.Runtime').authorize_rejected_focus(p.actor,p.token)
                    publish(p.token,'cancelled','cancelled');M.stop();return
                end
                if choice[2]~='choose'then return end
                local offered=false;for _,pair in ipairs(p.pair_choices)do if pair.id==choice[3]then offered=true end end
                assert(offered,'Unknown selected sitting pair')
                p.furniture_pair_id=choice[3];p.awaiting_pair=nil;p.pair_complete=true
            end
            local Catalog=require("SceneZOI.Catalog")
            local roster,ids,loaded,with_self,held={},{},true,false,false
            local self_id=Protocol.id(p.actor:GetEntityId())
            for id in p.result[3]:gmatch("[^+]+")do
                ids[#ids+1]=id
                if id==self_id then with_self=true end
                if require("SceneZOI.Sessions").holder(id) then held=true end
                if actors[id] then roster[#roster+1]=require("SceneZOI.Traits").capture(actors[id]) else loaded=false end
            end
            local profile
            if p.furniture then
                local Furniture=require('SceneZOI.Furniture');local pair
                profile,pair=Furniture.available(p.furniture,p.furniture_pair_id,ids)
                if not profile and p.furniture_kind=='sofa.pair'then
                    reject_sofa(p,'sofa_unavailable','The requested seats on this sofa are unavailable for this scene.')
                    M.stop();return
                end
                assert(profile,'The furniture became unavailable during selection')
                if profile.kind=='sofa.pair'and not p.pair_complete then
                    p.pair_choices=Furniture.choices(p.furniture,ids)
                    if #p.pair_choices>1 then
                        p.awaiting_pair=true
                        require('SceneZOI.Runtime').authorize_rejected_focus(p.actor,p.token)
                        publish(p.token,'choosing_pair');return
                    end
                end
                p.furniture_pair_id=pair and pair.id
            end
            local chosen=loaded and not held and require("SceneZOI.StartingScenes").choose(Catalog.get_snapshot().nodes,roster,nil,profile) or nil
            -- With the controlled Zoi unselected the scene runs between the others, on the background path.
            local npc_started=chosen and not with_self and pcall(require("SceneZOI.AddonAPI").start_from_picker,p.actor,ids,chosen,p.furniture,p.furniture_pair_id)
            if npc_started then
                require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
                publish(p.token,"unavailable","npc_scene")
            elseif chosen and with_self then
                local roles={};for role,id in pairs(chosen.bindings)do roles[#roles+1]=role..":"..id end;table.sort(roles)
                publish(p.token,"selected",p.result[3],chosen.node,table.concat(roles,"+"))
            else
                if not held and p.furniture_kind=='sofa.pair'then
                    reject_sofa(p,'sofa_no_starting_scene','The selected Zois do not match any starting scene on this sofa.')
                else
                    pcall(require('SceneZOI.Localization').toast,held and 'A participant is already in another session.' or 'SceneZOI could not find a suitable starting scene for the selected Zois.')
                    require("SceneZOI.Runtime").authorize_rejected_focus(p.actor,p.token)
                    publish(p.token,"unavailable",held and "participant_busy" or "no_starting_scene")
                end
            end
        else publish(p.token,p.result[2],p.result[3])end
        pending=nil
    end
end
function M.tick(dt,actors,busy)
    local ok,err=pcall(update,math.max(tonumber(dt) or 0,0),actors,busy)
    if not ok then
        if pending and pending.partner_callback then
            local callback=pending.partner_callback
            if not pcall(M.stop,"picker_unavailable") then callback("picker_unavailable") end
            print("[SceneZOI] Partner picker failed: "..tostring(err))
            return
        end
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

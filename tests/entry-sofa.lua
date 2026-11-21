-- Unavailable manual sofa starts explain the expected denial without opening
-- a scene, mutating seats or leaving the native picker lease behind.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol')
local cfg,sent,toasts,records={},{},{},{}
local visible,cap=false,4
local actor={GetEntityId=function()return {Value=1}end}
local other={GetEntityId=function()return {Value=2}end}
local actors={['1']=actor,['2']=other}
local widget={BW_WBP_GroupOption={GetVisibility=function()return 0 end,SetVisibility=function()end},
    BW_WBP_ButtonOK={BW_Button={SetIsEnabled=function()end}},BW_Text_MainTitle={SetText=function()end},
    BW_Text_TitleNum={GetText=function()return '2 / 3'end},IsVisible=function()return visible end,
    OnClickedClose=function()visible=false end}
local handler={SelectWidget=widget,IsA=function()return true end}
local authorized,held,pickable,available,eligible=nil,false,true,true,true
local profile={id='test.sofa',kind='sofa.pair'}
package.loaded['SceneZOI.Settings']={debug_start_enabled=function()return true end}
package.loaded['SceneZOI.Localization']={refresh=function()end,text=function(s)return s end,
    toast=function(message)toasts[#toasts+1]=message end}
package.loaded['SceneZOI.Diagnostics']={record=function(kind,data)records[#records+1]={kind=kind,data=data}end}
package.loaded['SceneZOI.Runtime']={authorize_rejected_focus=function(a,token)assert(a==actor);authorized=token end}
package.loaded['SceneZOI.SimulationRoute']={send=function(a,kind,text)
    assert(a==actor and kind=='SceneZOIStarter.Select');sent[#sent+1]=P.unpack(text)
end,discard=function()end}
package.loaded['SceneZOI.Traits']={capture=function(a)return {id=P.id(a:GetEntityId())}end}
package.loaded['SceneZOI.Sessions']={holder=function()return held and 'another.scene'or nil end}
package.loaded['SceneZOI.Catalog']={get_snapshot=function()return {nodes={}}end}
package.loaded['SceneZOI.Furniture']={profile=function(id)assert(id=='50');return profile end,
    pickable=function()if pickable then return profile end end,
    available=function(id,_,ids)assert(id=='50'and #ids==2);if available then return profile,{id='left'}end end,
    choices=function()return {{id='left',label='Left seats'}}end}
package.loaded['SceneZOI.StartingScenes']={choose=function(_,roster)
    if #roster==2 and eligible then return {node='test.sofa_hub',bindings={first='1',second='2'}}end
end}
UE={UObject={Load=function()return {MaxZoiGroupMemberNum={Find=function()return cap end,
    Add=function(_,_,value)cap=value end}}end}}
inzoi={EB1ManagerType={UI=1},EB1ZoiGroupType={Default=1},UB1ZoiGroupEditUIHandler={StaticClass=function()end},
    UB1System={Get=function()return {ManagerMap={Find=function()return {UIHandlerMap={ToTable=function()return {handler}end}}end}}end},
    cli={execute=function(line)
        if line=='ui.get_blocking'then return true,'','{"blocked":false,"pause_reasons":[]}'end
        local key=line:match(' key=([^ ]+)')
        if line:find('cfg_save',1,true)then cfg[key]=line:match(' value=(.*)');return true,''end
        return cfg[key]~=nil,'',cfg[key]
    end}}
local E=require('SceneZOIStarter.Entry');E.boot()
local function request(token)
    cfg.selection_request=P.pack(token,'open','1','50');E.tick(.2,actors,false)
end
local function selected(token)
    request(token);visible=true;E.tick(.2,actors,false)
    E.reply(actor,P.pack(token,'selected','1+2'));visible=false;E.tick(.2,actors,false)
end
local function check_denied(token,code,message)
    local result=P.unpack(cfg.selection_state)
    assert(result[1]==token and result[2]=='unavailable'and result[3]==code and result[6]=='50')
    assert(authorized==token and not visible and cap==4)
    assert(toasts[#toasts]==message)
    local count=#toasts;for _=1,8 do E.tick(.2,actors,false)end
    assert(#toasts==count,'A retained unavailable mailbox must not repeat its toast')
    local last=records[#records]
    assert(last.kind=='picker_unavailable'and last.data.furniture_id=='50'and last.data.code==code)
end
local unavailable='The requested seats on this sofa are unavailable for this scene.'
pickable=false;local count=#sent;request('busy.before_picker')
check_denied('busy.before_picker','sofa_unavailable',unavailable)
assert(#sent==count,'A completely unavailable sofa must not open the selector or acquire anyone')
pickable=true;available=false;selected('busy.after_selection')
check_denied('busy.after_selection','sofa_unavailable',unavailable)
assert(sent[#sent][2]=='cancel','Close the picker lease after its selected seats become unavailable')
available=true;eligible=false;selected('unsupported.roster')
check_denied('unsupported.roster','sofa_no_starting_scene','The selected Zois do not match any starting scene on this sofa.')
held=true;selected('participant.busy')
check_denied('participant.busy','participant_busy','A participant is already owned by another scene.')
held=false;eligible=true;selected('retry.valid')
local result=P.unpack(cfg.selection_state)
assert(result[2]=='selected'and result[4]=='test.sofa_hub'and result[7]=='left',
    'A later eligible request uses the normal start handshake after each denial')
assert(not visible and cap==4)
print('Sofa picker denial passed: occupied seats before/after selection, ineligible/owned rosters, one toast per request, input/cap cleanup, diagnostics and successful retry.')

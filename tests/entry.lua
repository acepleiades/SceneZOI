-- A remote timeout must close the native modal and retire its simulation-side lease.
package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local P=require("SceneZOI.Protocol")
local cfg,sent,cap={}, {}, 4
local toasts=0
local visible=false
local actor={GetEntityId=function()return {Value=1}end}
local widget={BW_WBP_GroupOption={GetVisibility=function()return 0 end,SetVisibility=function()end},
 BW_WBP_ButtonOK={BW_Button={SetIsEnabled=function()end}},BW_Text_MainTitle={SetText=function()end},
 BW_Text_TitleNum={GetText=function()return "2 / 3" end},IsVisible=function()return visible end,
 OnClickedClose=function()visible=false end}
local handler={SelectWidget=widget,IsA=function()return true end}
local authorized
package.loaded["SceneZOI.Runtime"]={authorize_rejected_focus=function(a,t)assert(a==actor);authorized=t end}
UE={UObject={Load=function()return {MaxZoiGroupMemberNum={Find=function()return cap end,Add=function(_,_,v)cap=v end}}end}}
inzoi={EB1ManagerType={UI=1},EB1ZoiGroupType={Default=1},UB1ZoiGroupEditUIHandler={StaticClass=function()end},
 UB1System={Get=function()return {ManagerMap={Find=function()return {UIHandlerMap={ToTable=function()return {handler}end}}end}}end},
 message={send_to_sim=function(_,_,v)sent[#sent+1]=v end},cli={execute=function(line)
  if line:find('toast.show',1,true)then toasts=toasts+1;return true,''end
  local k=line:match(" key=([^ ]+)");if line:find("cfg_save",1,true)then cfg[k]=line:match(" value=(.*)") else return cfg[k]~=nil,"",cfg[k] end
  return true,""
 end}}
local debug_start=true
package.loaded['SceneZOI.Settings']={debug_start_enabled=function()return debug_start end}
local E=require("SceneZOIStarter.Entry");E.boot()
assert(cfg.selection_request=="none","A fresh install must create the optional request mailbox before publishing host readiness")
cfg.selection_request=P.pack("timeout","open","1");E.tick(.2,{["1"]=actor},false);assert(cap==3)
visible=true;E.tick(.2,{["1"]=actor},false);assert(cap==4)
E.reply(actor,P.pack("timeout","error",P.encode("Heartbeat expired")))
E.tick(.2,{["1"]=actor},false)
assert(not visible and cap==4 and authorized=="timeout")
assert(sent[#sent]==P.pack("timeout","closed"),"A timed-out open selector must acknowledge native closure")
assert(cfg.selection_state:find("|error|",1,true))
cfg.selection_request=P.pack("next","open","1");E.tick(.2,{["1"]=actor},false)
assert(sent[#sent]==P.pack("next","open"),"Timeout must not wedge the next picker")
E.stop();assert(cap==4 and sent[#sent]==P.pack("next","cancel"))
print("Native entry timeout passed: modal/cap restored, simulation lease retired and repeat entry available.")

local old=P.unpack(cfg.selection_host_ready)[1]
cfg.selection_ui_ready=P.pack(old,"ready","ui.one","launcher.1.1")
cfg.selection_launcher_ready=P.pack("launcher.1.1","ready","ui.one")
E.tick(.2,{["1"]=actor},false);assert(E.is_ready())
E.boot();assert(not E.is_ready());E.tick(.2,{["1"]=actor},false);assert(not E.is_ready(),"A previous UI generation must not authorize cold entry")
local current=P.unpack(cfg.selection_host_ready)[1];assert(current~=old)
cfg.selection_ui_ready=P.pack(current,"ready","ui.one","launcher.1.1")
E.tick(.2,{["1"]=actor},false);assert(E.is_ready(),"Lua restart should keep the live launcher acknowledgement")
cfg.selection_ui_ready=P.pack(current,"ready","ui.two","launcher.1.1")
E.tick(.2,{["1"]=actor},false);assert(not E.is_ready(),"A new controls UI must not reuse old launcher readiness")
cfg.selection_ui_ready=P.pack(current,"ready","ui.two","launcher.2.1")
cfg.selection_launcher_ready=P.pack("launcher.2.1","waiting","new")
E.tick(.2,{["1"]=actor},false);assert(not E.is_ready(),"A waiting launcher has not finished its handshake")
cfg.selection_launcher_ready=P.pack("launcher.2.1","ready","ui.two")
E.tick(.2,{["1"]=actor},false);assert(E.is_ready())
print("Entry readiness passed: host generation, receiver/launcher acknowledgements and stale boot rejection.")

package.loaded['SceneZOI.Furniture']={available=function()return nil end}
cfg.selection_request=P.pack('unavailable_bed','open','1','50');E.tick(.2,{['1']=actor},false)
assert(authorized=='unavailable_bed'and not visible,'Rejected furniture entry must restore authorized input before the picker exists')
print('Unavailable furniture entry restores input without opening a picker or acquiring participants.')

cfg.selection_request=P.pack('busy_scene','open','1');local before=#sent
E.tick(.2,{['1']=actor},true);E.tick(.2,{['1']=actor},true)
assert(toasts==1 and #sent==before and cfg.selection_state:find('|unavailable|busy|',1,true),'Busy entry toasts once without opening/cancelling a picker')

debug_start=false
local possessed='1'
package.loaded['SceneZOI.Controller']={controlled_id=function()return possessed end}
package.loaded['SceneZOI.Localization']={refresh=function()end,toast=function()end}
package.loaded['SceneZOI.DataFiles']={refresh=function()end}
package.loaded['SceneZOI.Catalog']={refresh=function()end,get_snapshot=function()return {nodes={}}end}
package.loaded['SceneZOI.Traits']={capture=function()return {id='1'}end}
local owner,eligible=nil,true
package.loaded['SceneZOI.Sessions']={holder=function()return owner end}
package.loaded['SceneZOI.StartingScenes']={choose=function(_,roster,_,profile,ratings)
 assert(#roster==1 and roster[1].id=='1' and not profile and ratings[1]=='GENERAL')
 if eligible then return {node='scenezoi.solo_idle_female',bindings={female='1'}}end
end}
local function direct(token,id,furniture)
 cfg.selection_request=P.pack(token,'open',id,furniture or 'none');E.tick(.2,{['1']=actor},false)
 assert(#sent==before and not visible and cap==4,'Solo entry must never open the native picker')
 return P.unpack(cfg.selection_state)
end
local solo=direct('solo','1')
assert(solo[2]=='selected' and solo[3]=='1' and solo[4]=='scenezoi.solo_idle_female' and solo[5]=='female:1' and solo[6]=='none')
assert(direct('furniture','1','50')[2]=='error','Default mode refuses furniture even if invoked directly')
possessed='2';assert(direct('stale','1')[2]=='error','A click for a previous Zoi must not start')
possessed='1';owner='other';assert(direct('held','1')[3]=='participant_busy')
owner=nil;eligible=false;assert(direct('incompatible','1')[3]=='no_starting_scene')
print('Direct solo entry passed: one eligible role, no picker, supported ratings, control and ownership checks, and no default furniture start.')

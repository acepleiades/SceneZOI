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
local E=require("SceneZOIStarter.Entry");E.boot()
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
cfg.selection_ui_ready=P.pack(old,"ready","none")
cfg.selection_launcher_ready=P.pack("launcher","ready","20261031-groups-2")
E.tick(.2,{["1"]=actor},false);assert(E.is_ready())
E.boot();assert(not E.is_ready());E.tick(.2,{["1"]=actor},false);assert(not E.is_ready(),"A previous UI generation must not authorize cold entry")
local current=P.unpack(cfg.selection_host_ready)[1];assert(current~=old)
cfg.selection_ui_ready=P.pack(current,"ready","none")
cfg.selection_launcher_ready=P.pack("launcher","ready","20261031-groups-2")
E.tick(.2,{["1"]=actor},false);assert(E.is_ready())
print("Entry readiness passed: host generation, receiver/launcher acknowledgements and stale boot rejection.")

package.loaded['SceneZOI.Furniture']={available=function()return nil end}
cfg.selection_request=P.pack('unavailable_bed','open','1','50');E.tick(.2,{['1']=actor},false)
assert(authorized=='unavailable_bed'and not visible,'Rejected furniture entry must restore authorized input before the picker exists')
print('Unavailable furniture entry restores input without opening a picker or acquiring participants.')

cfg.selection_request=P.pack('busy_scene','open','1');local before=#sent
E.tick(.2,{['1']=actor},true);E.tick(.2,{['1']=actor},true)
assert(toasts==1 and #sent==before and cfg.selection_state:find('|unavailable|busy|',1,true),'Busy entry toasts once without opening/cancelling a picker')

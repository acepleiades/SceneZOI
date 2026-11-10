-- Start Solo: the native button opens for a lone Zoi only where a one-role starting scene fits.
package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local P=require("SceneZOI.Protocol")
local cfg,sent,cap,count,hovered,enabled,dimmed,caption={}, {}, 4,"1 / 3",false,nil,nil,"OK"
local visible,solo_exists,authorized=false,true,nil
local actor={GetEntityId=function()return {Value=1}end}
local actors={["1"]=actor}
local button={SetIsEnabled=function(_,v)enabled=v end,IsHovered=function()return hovered end}
local ok={BW_Button=button,BW_Text={GetText=function()return caption end,SetText=function(_,v)caption=v end}}
setmetatable(ok,{__newindex=function(t,k,v)if k=="bIsDimmed"then dimmed=v else rawset(t,k,v)end end})
local widget={BW_WBP_GroupOption={GetVisibility=function()return 0 end,SetVisibility=function()end},BW_WBP_ButtonOK=ok,
 BW_Text_MainTitle={SetText=function()end},BW_Text_TitleNum={GetText=function()return count end},
 IsVisible=function()return visible end,OnClickedClose=function()visible=false end}
local handler={SelectWidget=widget,IsA=function()return true end}
local noop=function()end
package.loaded["SceneZOI.Runtime"]={authorize_rejected_focus=function(_,t)authorized=t end}
package.loaded["SceneZOI.DataFiles"]={refresh=noop}
package.loaded["SceneZOI.Catalog"]={refresh=noop,get_snapshot=function()return {nodes={}}end}
package.loaded["SceneZOI.Traits"]={capture=function(a)return {id=tostring(a:GetEntityId().Value)}end}
package.loaded["SceneZOI.Localization"]={text=function(t)return t end,toast=noop,refresh=noop}
package.loaded["SceneZOI.StartingScenes"]={choose=function(_,roster)
 if #roster==1 and solo_exists then return {node="pack.solo",bindings={female=roster[1].id}} end
 if #roster>=2 then return {node="pack.pair",bindings={a=roster[1].id,b=roster[2].id}} end
end}
UE={UObject={Load=function()return {MaxZoiGroupMemberNum={Find=function()return cap end,Add=function(_,_,v)cap=v end}}end}}
inzoi={EB1ManagerType={UI=1},EB1ZoiGroupType={Default=1},UB1ZoiGroupEditUIHandler={StaticClass=noop},
 UB1System={Get=function()return {ManagerMap={Find=function()return {UIHandlerMap={ToTable=function()return {handler}end}}end}}end},
 message={send_to_sim=function(_,_,v)sent[#sent+1]=v end},cli={execute=function(line)
  local k=line:match(" key=([^ ]+)");if line:find("cfg_save",1,true)then cfg[k]=line:match(" value=(.*)") else return cfg[k]~=nil,"",cfg[k] end
  return true,""
 end}}
local E=require("SceneZOIStarter.Entry");E.boot()
local function tick(dt)E.tick(dt or .05,actors,false)end
local function open(token)
 cfg.selection_request=P.pack(token,"open","1");E.tick(.2,actors,false)
 visible=true;tick();E.reply(actor,P.pack(token,"armed"));tick()
end
local function has(token,kind)for _,v in ipairs(sent)do if v==P.pack(token,kind)then return true end end end

open("one");assert(enabled==true and dimmed==false and caption=="Start Solo","Alone with a solo scene: the button is live and says so")
count="2 / 3";tick();assert(enabled==true and caption=="OK","With a partner it is the normal start")
count="4 / 3";tick();assert(enabled==false and dimmed==true,"Over the cap stays refused")
count="1 / 3";tick();assert(enabled==true and caption=="Start Solo")
hovered=true;tick();visible=false;tick();hovered=false
assert(has("one","solo")and caption=="OK","A close with the pointer on Start Solo chooses it and restores the caption")
E.reply(actor,P.pack("one","selected","1"));tick()
assert(cfg.selection_state:find("|selected|1|pack.solo|female:1|",1,true),"The lone Zoi is bound to the solo scene")

open("x");assert(enabled==true);visible=false;tick()
assert(not has("x","solo")and has("x","closed"),"Closing with the pointer elsewhere is a cancel")
E.reply(actor,P.pack("x","cancelled","none"));tick()

open("late");hovered=true;tick();hovered=false;for _=1,4 do tick(.1)end;visible=false;tick()
assert(not has("late","solo"),"Passing over the button earlier is not a click")
E.reply(actor,P.pack("late","cancelled","none"));tick()

local started
package.loaded["SceneZOI.AddonAPI"]={start_from_picker=function(_,ids,chosen)started=table.concat(ids,"+")..":"..chosen.node;return {accepted=true}end}
actors["2"],actors["3"]=actor,actor
open("npc");count="2 / 3";tick();visible=false;tick()
E.reply(actor,P.pack("npc","selected","2+3"));tick()
assert(started=="2+3:pack.pair"and authorized=="npc"and cfg.selection_state:find("|unavailable|npc_scene|",1,true),"Unselected: the scene runs between the others")
open("gone");count="2 / 3";tick();visible=false;tick()
E.reply(actor,P.pack("gone","selected","2+9"));tick()
assert(authorized=="gone"and cfg.selection_state:find("|unavailable|no_starting_scene|",1,true),"Someone out of range: a message, no scene")
solo_exists=false;count="1 / 3"
open("none");assert(enabled==false and dimmed==true and caption=="OK","No solo scene for this Zoi: the old rule stands")
hovered=true;tick();visible=false;tick();hovered=false
assert(not has("none","solo"),"A greyed button can never start one")
E.reply(actor,P.pack("none","cancelled","none"));tick()
solo_exists=true

cfg.selection_request=P.pack("early","open","1");E.tick(.2,actors,false);visible=true;tick()
assert(enabled==false,"Before the simulation is ready the button stays off")
E.stop()
print("Start Solo passed: live only with a matching solo scene, caption follows the selection, click versus cancel, and the bound roster.")

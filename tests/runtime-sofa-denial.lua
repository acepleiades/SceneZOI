-- A normal manual sofa availability refusal is a toast/quiet close. An
-- add-on failure, unexpected native error, or interruption after playback keeps
-- its structured error and ordinary diagnostics instead of being hidden.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation')
local Sessions=require('SceneZOI.Sessions');local Furniture=require('SceneZOI.Furniture')
local Localization=require('SceneZOI.Localization')
local notices={};Localization.toast=function(text)notices[#notices+1]=text end
local slots={{component_name='Seat1',slot_name='Sit1'},{component_name='Seat2',slot_name='Sit2'}}
local profile={id='test.sofa',kind='sofa.pair'}
local furniture={id='50',selected_pair_id='left',spot_ids={'s1','s2'},slots=slots,profile=profile,anchor={}}
F.node.furniture={kind='sofa.pair',surface_height_cm=44}
Furniture.prepare=function(id,_,pair)assert(id=='50'and pair=='left');return V.copy(furniture)end
Furniture.profile=function()return profile end
Furniture.actor=function()return F.actors[1]end
cfg.scene_history=''
F.add_actor(1);F.add_actor(2);R.boot()
local sequence=0
local function manual()
    sequence=sequence+1
    cfg.request=P.pack('manual',sequence,'start','1','test.node','first:1+second:2','50','none','left')
    R.tick(.25)
    local current=assert(Sessions.focused(),'Expected the manual session to begin normally')
    assert(current.manual_sofa_start and not current.addon_id)
    return current
end
local function persist(c)
    for id=1,2 do R.save_reply(F.actors[id],P.pack(c.token,'snapshot',P.encode(J.encode({token=c.token,collision=true}))))end
    local journal=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(journal.host,journal.revision,'ready');R.tick(.05)
end
local function furniture_reply(c,code,reason,rows)
    R.furniture_reply(F.actors[1],{c.token,'50',code,reason,'none','none','left',rows and P.encode(J.encode(rows))or nil})
end
local function finish(c)
    furniture_reply(c,'released','ok')
    for id=1,2 do F.reply(c.token,id,'released')end
    R.flush_notifications();assert(not Sessions.holder('1'))
end
local c=manual();persist(c)
furniture_reply(c,'busy','native_occupied')
assert(c.stopping and c.stop_code=='sofa_unavailable'and #notices==1)
furniture_reply(c,'busy','native_occupied');assert(#notices==1,'Repeated denial replies cannot repeat the toast')
finish(c)
assert(P.unpack(cfg.state)[3]=='idle'and P.unpack(cfg.state)[4]=='sofa_unavailable',
    'Expected manual refusal closes quietly after normal cleanup')
assert(notices[1]=='The requested seats on this sofa are unavailable for this scene.')
-- A lost local reservation before a session is created has the same manual UX.
assert(Sessions.reserve('other.scene',{},'50',{'s1','s2'}))
local before=#notices;sequence=sequence+1
cfg.request=P.pack('manual',sequence,'start','1','test.node','first:1+second:2','50','none','left');R.tick(.25)
assert(not Sessions.focused()and #notices==before+1)
assert(P.unpack(cfg.state)[3]=='idle'and P.unpack(cfg.state)[4]=='sofa_unavailable')
Sessions.release('other.scene')
local restored_input=0
require('SceneZOI.Native').release_input=function(actor)assert(actor==F.actors[1]);restored_input=restored_input+1 end
cfg.focus=P.pack('manual',sequence,'closed');R.tick(.25);R.tick(.25)
assert(restored_input==1,'Quiet preflight close keeps the actor identity for the native input-restoration handshake')
-- A well-formed pair removed from the active profile is an expected stale
-- choice. Invalid protocol syntax is still a malformed request, not a toast.
local prepare=Furniture.prepare
Furniture.prepare=function(_,_,pair)
    assert(pair~='left','This fixture is exercising an explicit stale pair')
    error('Furniture sitting pair is unavailable')
end
for _,case in ipairs({{pair='removed_pair',phase='idle',code='sofa_unavailable',toast=true},
                       {pair='INVALID_PAIR',phase='error',code='entry_error',toast=false}})do
    before=#notices;sequence=sequence+1
    cfg.request=P.pack('manual',sequence,'start','1','test.node','first:1+second:2','50','none',case.pair);R.tick(.25)
    assert(not Sessions.focused())
    local state=P.unpack(cfg.state);assert(state[3]==case.phase and state[4]==case.code)
    assert(#notices==before+(case.toast and 1 or 0),'Only a well-formed stale sofa pair receives the availability toast')
end
Furniture.prepare=prepare
-- Unexpected teardown/tracking failures and malformed native mappings remain errors.
for _,failure in ipairs({'native_getup_motion_unsettled','native_pair_reservation_failed','guards_unavailable'})do
    c=manual();persist(c);before=#notices
    furniture_reply(c,'busy',failure)
    assert(c.stop_code=='furniture_unavailable'and #notices==before,failure)
    finish(c);assert(P.unpack(cfg.state)[3]=='error')
end
c=manual();persist(c);before=#notices
furniture_reply(c,'held','native_pair_reserved',{{component_name='Wrong',slot_name='Wrong'}})
assert(c.stop_code=='furniture_unavailable'and #notices==before,'Invalid slot proof is not an availability toast')
finish(c)
-- A playing scene losing its seats is an interruption, not a denied start.
c=manual();persist(c);furniture_reply(c,'held','native_pair_reserved',slots)
for id=1,2 do F.reply(c.token,id,'ready','female:npc',1)end
R.tick(.05);assert(c.started and not c.preparing)
before=#notices;furniture_reply(c,'busy','native_occupied')
assert(c.stop_code=='furniture_unavailable'and #notices==before);finish(c)
-- The same native availability result on a background add-on session retains
-- its failure code. No player-visible notification is added to the API path.
local row={token='addon.sofa',has_household=true,lifetime={deadline_seconds=600},restrictions={},
    placement={max_start_distance_cm=1500,exit='restore'},
    req={addon_id='test.addon',client_id='client',request_id='background'},
    entry={initiator='1',node='test.node',bindings={first='1',second='2'},furniture='50',furniture_pair_id='left'}}
assert(Sessions.reserve(row.token,{'1','2'},'50',{'s1','s2'}))
local token=R.start_background(row);c=R.api_session(token);persist(c);before=#notices
assert(not c.manual_sofa_start and c.addon_id=='test.addon')
furniture_reply(c,'busy','native_occupied')
assert(c.stop_code=='furniture_unavailable'and #notices==before);finish(c)
require('SceneZOI.Diagnostics').flush()
assert(cfg.scene_history:find('reason=native_occupied',1,true)and cfg.scene_history:find('reason=native_getup_motion_unsettled',1,true),
    'The native cause remains available in rolling diagnostics for both expected and unexpected failures')
print('Manual sofa denial passed: late busy/local reservation toast once, normal cleanup/quiet close, native diagnostics retained, and add-on/playing/unexpected failures unchanged.')

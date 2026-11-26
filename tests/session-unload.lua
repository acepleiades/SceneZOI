-- A participant unloading is reported for what it is, and cleanup does not wait for a Zoi that cannot answer.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local ended={}
F.Events.subscribe('session_ended',function(e)ended[e.id]=e end)
for id=1,4 do F.add_actor(id)end
R.boot()
local J=require('SceneZOI.Json')
local function start(sequence,a,b,furniture)
 F.controlled=a -- A manual start's initiator is the Zoi the player controls.
 cfg.request=P.pack('ui',sequence,'start',tostring(a),'test.node','first:'..a..'+second:'..b,furniture or 'none')
 cfg.heartbeat=P.pack('ui',sequence,'heartbeat','beat'..sequence)
 R.tick(.25)
 local token=assert(R.snapshot()).id
 local record=P.encode(J.encode({token=token,collision=true}))
 for _,id in ipairs({a,b})do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
 local journal=J.decode(P.decode(cfg.save_snapshot))
 cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
 R.tick(.05)
 return token
end
local function journal_record(token)
 for _,record in ipairs(J.decode(P.decode(cfg.save_snapshot)).records)do if record.token==token then return record end end
end
local function journal_people(token)
 local record=journal_record(token)
 return record and record.participants
end
local function row(event,id)for _,person in ipairs(event.participants)do if person.id==id then return person end end end
-- Both answer: ordinary cleanup.
local first=start(1,1,2)
R.stop('ok');F.reply(first,1,'released');F.reply(first,2,'released');R.flush_notifications()
assert(ended[first].code=='ok'and ended[first].result_facts~=nil and row(ended[first],'1').restoration=='restored')
assert(journal_people(first)==nil,'A clean finish leaves nothing to recover')
assert(ended[first].focused==true,'The end of the scene on screen reaches whoever saw it start')
-- One unloads: the rest clean up at once, and it is not called a timeout.
local second=start(2,3,4)
R.unregister(F.actors[3])
assert(R.snapshot(second).phase=='exiting')
F.reply(second,4,'released');R.flush_notifications()
assert(ended[second].code=='participant_unloaded','A missing actor must end the scene as unloaded, not as a cleanup timeout')
assert(row(ended[second],'3').restoration=='deferred_recovery'and row(ended[second],'4').restoration=='restored')
assert(journal_people(second)['3']and not journal_people(second)['4'],'Only the unconfirmed Zoi is kept for later')
-- The simulation side confirms it through another Zoi: nothing left to recover.
R.reply(F.actors[1],P.pack(second,'released_unloaded','3'));assert(journal_people(second)==nil)
-- Reservations last until cleanup finishes.
local Sessions=require('SceneZOI.Sessions')
F.add_actor(3)
local third=start(3,3,4)
R.stop('ok');assert(Sessions.holder('3')==third,'A Zoi stays reserved during cleanup')
F.reply(third,3,'released');F.reply(third,4,'released');assert(Sessions.holder('3')==nil)
-- A genuine timeout is still reported as one, and keeps what it could not confirm.
local fourth=start(4,3,4)
R.stop('ok');F.reply(fourth,3,'released')
for _=1,200 do R.tick(.05)end
R.flush_notifications()
assert(ended[fourth].code=='restore_timeout'and journal_people(fourth)['4']and not journal_people(fourth)['3'])
print('Unload outcomes passed: missing actors end as unloaded, cleanup does not wait for them, per-participant results, deferred recovery and real timeouts.')

local function addon_stop(sequence, code, display_reason, release_detail)
    local token=start(sequence,1,2)
    local session=R.api_session(token)
    session.stop_origin={addon_id='test',client_id='client',reason='test_stop'}
    session.stop_display_reason=display_reason
    R.stop(code,token)
    assert(P.unpack(cfg.state)[3]=='exiting','Show the notice only after cleanup')
    F.reply(token,1,'released',release_detail)
    F.reply(token,2,'released')
    local state,focus=P.unpack(cfg.state),P.unpack(cfg.focus_session)
    assert(focus[2]=='none' and focus[3]==state[1] and focus[4]==state[2] and
        focus[5]==state[3] and focus[6]==state[4] and focus[7]==state[5],
        'Either mailbox can deliver the same terminal status to the bound panel')
    R.tick(.25)
    assert(P.unpack(cfg.state)[5]==state[5],'A replay of a completed request keeps its notice')
    return state
end
local with_reason=addon_stop(21,'addon_requested','Søren and Minah stopped.')
assert(with_reason[3]=='idle' and with_reason[4]=='addon_requested' and
    P.decode(with_reason[5])=='Søren and Minah stopped.')
local generic=addon_stop(22,'ok',nil)
assert(generic[3]=='idle' and generic[4]=='ok' and generic[5]=='00')
local error_state=addon_stop(23,'addon_requested','Do not show this.','restore_error')
assert(error_state[3]=='error' and error_state[4]=='restore_error' and error_state[5]==nil)

local function focus_as(id)
    F.controlled=id
    R.tick(.25)
    return P.unpack(cfg.focus_session)
end

local Save=require('SceneZOI.SaveBridge')
local Furniture=require('SceneZOI.Furniture')
local original_prepare=Furniture.prepare
local bed_id='50'
F.node.furniture={kind='bed'}
Furniture.prepare=function(id)
    assert(id==bed_id)
    return {id=id,profile={id='test.bed',kind='bed'},anchor={}}
end
local function start_bed(sequence)
    local token=start(sequence,1,2,bed_id)
    local scene=R.api_session(token)
    assert(scene.save_ready and Sessions.furniture_holder(bed_id)==token)
    R.furniture_reply(F.actors[1],{token,bed_id,'held','native_slot_reserved','slot','slot'})
    assert(scene.furniture_ready,'The bed restriction must be acquired before either Zoi unloads')
    return token,scene
end

local owner_unloaded, owner_scene=start_bed(31)
assert(#focus_as(3)==2,'The player switches to a bystander before streaming the scene out')
R.unregister(F.actors[1])
assert(R.snapshot(owner_unloaded).phase=='exiting','Keep waiting for the still-loaded partner')
F.add_actor(1)
assert(#focus_as(1)==2,'A new actor wrapper for the same Zoi cannot reopen the stopping panel')
F.reply(owner_unloaded,2,'released')
R.tick(.25)
R.flush_notifications()
assert(not R.snapshot(owner_unloaded) and ended[owner_unloaded].code=='participant_unloaded',
    'Once the remaining partner replies, the nonresponsive bed owner must not force a timeout')
assert(owner_scene.cleanup_complete==false,'The deferred participant and bed were not yet confirmed restored')
assert(not Sessions.holder('1') and not Sessions.furniture_holder(bed_id),'Retirement releases live claims')
local pending=assert(journal_record(owner_unloaded))
assert(pending.participants['1'] and not pending.participants['2'])
assert(#pending.furniture==1 and pending.furniture[1].id==bed_id and pending.furniture[1].owner=='1')
assert(Save.overlaps({'1'}) and Save.overlaps({},bed_id) and not Save.overlaps({'2'}),
    'The journal blocks only the unconfirmed Zoi and the recovering bed after retirement')
assert(#focus_as(1)==2,'Returning before the journal recovers does not reopen the ended panel')
R.reply(F.actors[3],P.pack(owner_unloaded,'released_unloaded','1','simulation_end'))
assert(not Save.overlaps({'1'}) and Save.overlaps({},bed_id),'Participant release cannot retire the bed record')
R.save_reply(F.actors[2],P.pack(owner_unloaded,'furniture_recovered'))
assert(Save.overlaps({},bed_id),'Only the recorded bed owner can acknowledge its release')
R.save_reply(F.actors[1],P.pack(owner_unloaded,'furniture_recovered'))
assert(not journal_record(owner_unloaded) and not Save.overlaps({},bed_id),'A confirmed bed can be reused')

local everyone_unloaded, everyone_scene=start_bed(32)
assert(#focus_as(3)==2)
R.unregister(F.actors[1])
R.unregister(F.actors[2])
R.tick(.25)
R.flush_notifications()
assert(not R.snapshot(everyone_unloaded) and ended[everyone_unloaded].code=='participant_unloaded',
    'With both Zois gone, cleanup retires without waiting for an impossible reply')
assert(everyone_scene.cleanup_complete==false and Save.overlaps({'1'}) and Save.overlaps({'2'}) and Save.overlaps({},bed_id))
for id=1,2 do
    R.reply(F.actors[3],P.pack(everyone_unloaded,'released_unloaded',id,'simulation_end'))
    F.add_actor(id)
end
assert(#focus_as(2)==2 and Save.overlaps({},bed_id),'Late participant replies leave only the deferred bed')
R.save_reply(F.actors[1],P.pack(everyone_unloaded,'furniture_recovered'))
assert(not journal_record(everyone_unloaded))

local reachable_bed, reachable_scene=start_bed(33)
R.stop('ok',reachable_bed)
F.reply(reachable_bed,1,'released')
F.reply(reachable_bed,2,'released')
R.tick(.25)
assert(R.snapshot(reachable_bed).phase=='exiting' and Sessions.furniture_holder(bed_id)==reachable_bed,
    'A bed with a reachable owner must still acknowledge its release')
for _=1,200 do R.tick(.05)end
R.flush_notifications()
assert(ended[reachable_bed].code=='restore_timeout' and reachable_scene.cleanup_complete==false)
assert(not Save.overlaps({'1','2'}) and Save.overlaps({},bed_id),'A genuine timeout retires to the same recovery barrier')
R.save_reply(F.actors[1],P.pack(reachable_bed,'furniture_recovered'))
assert(not journal_record(reachable_bed))
F.node.furniture=nil
Furniture.prepare=original_prepare
print('Furniture unload outcomes passed: prompt retirement, return during cleanup, independent recovery, and real release timeouts.')

local function request_addon_stop(token)
    local session=R.api_session(token)
    session.stop_origin={addon_id='test',client_id='client',reason='test_stop'}
    session.stop_display_reason='The session stopped after someone walked in.'
    R.stop('addon_requested',token)
end
local function stop_without_focus(token, a, b)
    request_addon_stop(token)
    F.reply(token,a,'released')
    F.reply(token,b,'released')
end
local background_stop=start(24,1,2)
assert(focus_as(3)[2]=='none')
stop_without_focus(background_stop,1,2)
assert(focus_as(3)[2]=='none','The bystander must never receive the participants’ notice')
assert(P.unpack(cfg.state)[5]==nil,'An old Start cannot replay the notice at the bystander')
assert(#focus_as(1)==2 and #focus_as(2)==2,'Switching to either participant cannot open the panel afterward')

local stale_focus=start(25,1,2)
F.controlled=3 -- The game updates possession before the runtime polls panel focus.
stop_without_focus(stale_focus,1,2)
assert(#P.unpack(cfg.focus_session)==2 and P.unpack(cfg.state)[5]==nil,
    'Stale panel focus cannot publish a reason while controlling a bystander')
assert(#focus_as(1)==2,'Possession after the stop cannot expose its reason')

local return_during_cleanup=start(26,1,2)
assert(#focus_as(3)==2)
request_addon_stop(return_during_cleanup)
assert(#focus_as(2)==2,'Returning during a background stop cannot reopen the panel')
F.reply(return_during_cleanup,1,'released')
F.reply(return_during_cleanup,2,'released')
assert(#focus_as(2)==2 and P.unpack(cfg.state)[5]==nil,'Returning before cleanup finishes cannot expose its reason')

local leave_during_cleanup=start(27,1,2)
request_addon_stop(leave_during_cleanup)
F.controlled=3
F.reply(leave_during_cleanup,1,'released')
F.reply(leave_during_cleanup,2,'released')
assert(#P.unpack(cfg.focus_session)==2 and P.unpack(cfg.state)[5]==nil,
    'Leaving before cleanup finishes drops the notice')

addon_stop(28,'addon_requested','This notice was shown to a participant.')
assert(#focus_as(2)>2,'Switching between participants can keep the visible notice')
assert(#focus_as(3)==2,'Leaving the participants hides an already-shown notice')
assert(#focus_as(1)==2,'Returning cannot reopen a notice that was hidden on departure')

assert(focus_as(3)[2]=='none')
local background={token='qa.unseen',has_household=true,lifetime={deadline_seconds=600},
    placement={max_start_distance_cm=1500,exit='restore'},req={addon_id='test',client_id='client',request_id='start'},
    restrictions={},entry={initiator='1',node='test.node',bindings={first='1',second='2'}}}
assert(Sessions.reserve(background.token,{'1','2'}))
local unseen=R.start_background(background)
local unseen_session=R.api_session(unseen)
local saved=P.encode(J.encode({token=unseen,collision=true}))
for id=1,2 do R.save_reply(F.actors[id],P.pack(unseen,'snapshot',saved))end
local snapshot=J.decode(P.decode(cfg.save_snapshot))
cfg.save_ready=P.pack(snapshot.host,snapshot.revision,'ready')
R.tick(.05)
stop_without_focus(unseen,1,2)
R.flush_notifications()
assert(ended[unseen].code=='addon_requested' and unseen_session.cleanup_complete==true)
assert(focus_as(1)[2]=='none','A background session that never held the panel cannot open it after cleanup')

local diagnostics = require("SceneZOI.Diagnostics")
local record = diagnostics.record
local releases = {}
function diagnostics.record(name, fields)
    if name == "participant_release" then releases[#releases + 1] = fields end
    record(name, fields)
end
for id = 5, 10 do F.add_actor(id) end

local normal = start(5, 5, 6)
F.reply(normal, 7, "released")
assert(R.snapshot(normal).phase == "preparing" and #releases == 0,
    "A reply from outside the roster cannot interrupt a scene")
R.stop("ok")
F.reply(normal, 7, "released", "restore_error")
R.reply(F.actors[5], P.pack(normal, "released", "ok", 0, "host_request"))
F.reply(normal, 6, "released")
R.flush_notifications()
assert(ended[normal].code == "ok" and #releases == 0,
    "Only roster members may acknowledge cleanup or report restoration failure")

local interrupted = start(6, 5, 6)
R.reply(F.actors[6], P.pack(interrupted, "released", "ok", 0, "participant_update_error", "Queue_clear_failed"))
assert(R.snapshot(interrupted).phase == "exiting")
local release = assert(releases[1])
assert(release.session_id == interrupted and release.scene_id == F.node.id)
assert(release.participant_id == "6" and release.role == "second" and release.revision == 1)
assert(release.phase == "preparing" and release.transport == "direct" and
    release.cause == "participant_update_error" and release.simulation_diagnostic == "Queue_clear_failed")
local function lease_person(observation, id)
    for _, person in ipairs(observation.participants) do if person.participant_id == id then return person end end
end
local host = assert(release.host_lease_diagnostic)
assert(#host.participants == 2 and host.last_dt == .05 and host.max_dt == .25)
for _, id in ipairs({"5", "6"}) do
    local observed = assert(lease_person(host, id))
    assert(observed.actor_registered and observed.prepare_attempts == 1 and observed.heartbeat_attempts == 0)
    assert(observed.last_kind == "SceneZOI.Prepare" and observed.seconds_since_last_attempt == .05)
    assert(observed.route.state == "direct")
end
R.reply(F.actors[5], P.pack(interrupted, "released_unloaded", "6", "participant_update_error"))
assert(#releases == 1, "The controlled Zoi's relay does not duplicate the direct diagnostic")
F.reply(interrupted, 6, "released")
F.reply(interrupted, 5, "released")
R.flush_notifications()
assert(ended[interrupted].code == "interrupted")

local unknown = start(7, 5, 6)
F.reply(unknown, 6, "released")
assert(releases[2].cause == "unreported" and releases[2].simulation_diagnostic == nil)
F.reply(unknown, 6, "released")
F.reply(unknown, 5, "released")
R.flush_notifications()
assert(ended[unknown].code == "interrupted")

local relay = start(8, 8, 9)
R.unregister(F.actors[9])
R.reply(F.actors[8], P.pack(relay, "released_unloaded", "10", "simulation_end"))
assert(#releases == 2, "A relayed release for an unrelated Zoi has no diagnostic authority")
R.reply(F.actors[8], P.pack(relay, "released_unloaded", "9", "simulation_end"))
assert(releases[3].transport == "relay" and releases[3].cause == "simulation_end" and
    releases[3].phase == "exiting" and releases[3].participant_id == "9")
host = assert(releases[3].host_lease_diagnostic)
assert(#host.participants == 2 and lease_person(host, "8").actor_registered and
    not lease_person(host, "9").actor_registered,
    "A relayed release must retain host observations for the unloaded roster member")
assert(lease_person(host, "9").prepare_attempts == 1)
F.reply(relay, 8, "released")
R.flush_notifications()
assert(ended[relay].code == "participant_unloaded")
print("Participant release causes passed: sender ownership, missing cause, direct report, relay, and public stop codes.")

-- Host attempts are not proof of receipt. Drop one native send while keeping
-- both participants' host counts and unscaled ages independently observable.
local timing = start(9, 5, 6)
F.reply(timing, 5, "ready", "female:controlled", 1)
F.reply(timing, 6, "ready", "female:npc", 1)
R.tick(.05)
assert(R.snapshot(timing).phase == "playing")
local send, dropped = inzoi.message.send_to_sim, 0
function inzoi.message.send_to_sim(id, kind, content)
    if id.Value == 6 and kind == "SceneZOI.Heartbeat" then dropped = dropped + 1; return end
    return send(id, kind, content)
end
F.clear_sent()
R.tick(.7)
R.tick(.25)
assert(dropped == 1 and #releases == 3,
    "Heartbeat observations must not create log records during ordinary ticks")
local sent_first, sent_second = 0, 0
for _, message in ipairs(F.sent) do if message.kind == "SceneZOI.Heartbeat" then
    if message.id == 5 then sent_first = sent_first + 1 end
    if message.id == 6 then sent_second = sent_second + 1 end
end end
assert(sent_first == 1 and sent_second == 0)
local simulation = "prepare_received:1+heartbeat_received:0+last_dt:6.1+wall_since_renew_seconds:0"
R.reply(F.actors[6], P.pack(timing, "released", "ok", 0, "lease_expired", simulation))
local timed_release = assert(releases[4])
assert(timed_release.cause == "lease_expired" and timed_release.phase == "playing" and
    timed_release.simulation_diagnostic == simulation)
host = timed_release.host_lease_diagnostic
assert(host.last_dt == .25 and host.max_dt == .7 and #host.participants == 2)
for _, id in ipairs({"5", "6"}) do
    local observed = assert(lease_person(host, id))
    assert(observed.prepare_attempts == 1 and observed.heartbeat_attempts == 1)
    assert(observed.last_kind == "SceneZOI.Heartbeat" and observed.seconds_since_last_attempt == .25)
end
R.reply(F.actors[5], P.pack(timing, "released_unloaded", "6", "lease_expired", simulation))
assert(#releases == 4, "Direct and relay timing diagnostics must be recorded once per participant")
inzoi.message.send_to_sim = send
F.reply(timing, 6, "released")
F.reply(timing, 5, "released")
R.flush_notifications()
assert(ended[timing].code == "interrupted")
print("Host lease observations passed: per-participant attempts, missing native delivery, unscaled ages, tick deltas and direct/relay deduplication.")

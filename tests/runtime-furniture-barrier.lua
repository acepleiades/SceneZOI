-- A settled native get-up changes the durable return coordinates after the
-- first commit. Latest journal acknowledgement gates entry ACK/anchor/playback,
-- while already acquired furniture continues receiving its ordinary heartbeat.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation')
local Sessions=require('SceneZOI.Sessions');local Furniture=require('SceneZOI.Furniture')
local Playback=require('SceneZOI.Playback')
local slots={{component_name='Seat1',slot_name='Sit1'},{component_name='Seat2',slot_name='Sit2'}}
local furniture={id='50',selected_pair_id='left',spot_ids={'s1','s2'},slots=slots,
    profile={id='test.sofa',kind='sofa.pair'},anchor={}}
F.node.furniture={kind='sofa.pair',surface_height_cm=44}
Furniture.prepare=function(id,_,pair)
    assert(id=='50'and pair=='left');return V.copy(furniture)
end
Furniture.actor=function()return F.actors[1]end
local playback_entries=0
Playback.enter=function()playback_entries=playback_entries+1 end
F.add_actor(1);F.add_actor(2);R.boot()
local function sent(kind)
    local rows={};for _,row in ipairs(F.sent)do if row.kind==kind then rows[#rows+1]=row end end;return rows
end
local function journal()return J.decode(P.decode(cfg.save_snapshot))end
local function ack(value)
    value=value or journal();cfg.save_ready=P.pack(value.host,value.revision,'ready');return value
end
local function settle(token,id,checkpoint)
    R.save_reply(F.actors[id],P.pack(token,'settled_snapshot',P.encode(J.encode({token=token,
        checkpoint=checkpoint,location={100*checkpoint+id,20,30},rotation={0,90,0}}))))
end
local serial=0
local function start()
    serial=serial+1;local request='journal.barrier.'..serial
    local row={token=request,has_household=true,lifetime={deadline_seconds=600},restrictions={},
        placement={max_start_distance_cm=1500,exit='restore'},
        req={addon_id='test.addon',client_id='client',request_id=request},
        entry={initiator='1',node='test.node',bindings={first='1',second='2'},furniture='50',furniture_pair_id='left'}}
    assert(Sessions.reserve(request,{'1','2'},'50',{'s1','s2'}))
    local token=R.start_background(row)
    for id=1,2 do
        local original={token=token,collision=true,location={id,2,3},rotation={0,0,0}}
        R.save_reply(F.actors[id],P.pack(token,'snapshot',P.encode(J.encode(original))))
    end
    ack();R.tick(.05)
    local current=R.api_session(token)
    assert(current.save_committed and current.save_ready and not current.started)
    R.furniture_reply(F.actors[1],{token,'50','held','native_pair_reserved','none','none','left',P.encode(J.encode(slots))})
    assert(current.furniture_ready and #sent('SceneZOI.Commit')>=2)
    F.clear_sent()
    return token,current
end
local function ready(token)
    for id=1,2 do F.reply(token,id,'ready','female:npc',1)end
end
local function finish(token)
    R.stop('ok',token)
    R.furniture_reply(F.actors[1],{token,'50','released','ok','none','none','left'})
    for id=1,2 do F.reply(token,id,'released')end
    R.flush_notifications();assert(not Sessions.holder('1'))
    F.clear_sent()
end

-- An acknowledgement of the original snapshot cannot release a later settled
-- update. Even an early participant Ready cannot bypass the durable barrier.
local token,current=start();local initial=journal();local entries_before=playback_entries
settle(token,1,1);settle(token,2,1)
local latest=journal()
assert(latest.revision>initial.revision and not current.save_ready)
ready(token)
for _=1,5 do R.tick(.25)end
assert(current.preparing and not current.started and not current.stopping)
assert(#sent('SceneZOI.EntrySaved')==0 and #sent('SceneZOI.Anchor')==0 and playback_entries==entries_before,
    'Unacknowledged settled coordinates must not authorize entry, anchor or playback')
local heartbeats=sent('SceneZOI.Furniture')
assert(#heartbeats>=1,'An acquired sofa lease must not expire while a newer journal is awaiting persistence')
for _,message in ipairs(heartbeats)do
    assert(message.fields[1]==token and message.fields[2]=='50'and message.fields[3]=='heartbeat'and message.fields[5]=='left',
        'The existing exact-pair reservation is maintained, not reacquired')
end
ack(latest);F.clear_sent();R.tick(.05)
local entry=sent('SceneZOI.EntrySaved')
assert(#entry==2 and entry[1].fields[1]==token and entry[2].fields[1]==token)
for _,message in ipairs(entry)do assert(tonumber(message.fields[2])==1,'Publish the exact persisted checkpoint')end
assert(#sent('SceneZOI.Anchor')==2 and playback_entries==entries_before+1 and current.started and not current.preparing,
    'Only the latest acknowledged journal allows entry and playback')
finish(token)

-- Another participant can publish a newer settled revision while the host is
-- delivering the first entry ACK. Re-check readiness for every participant and
-- before playback, rather than relying on one cached ready result for the frame.
token,current=start();entries_before=playback_entries
settle(token,1,1);settle(token,2,1);local first_update=ack()
ready(token);F.clear_sent()
local send=inzoi.message.send_to_sim;local revised=false
inzoi.message.send_to_sim=function(id,kind,content)
    send(id,kind,content)
    if not revised and id.Value==1 and kind=='SceneZOI.EntrySaved'then
        revised=true;settle(token,2,2)
    end
end
R.tick(.05);inzoi.message.send_to_sim=send
entry=sent('SceneZOI.EntrySaved')
assert(revised and journal().revision>first_update.revision and not current.save_ready)
assert(#entry==1 and entry[1].id==1 and tonumber(entry[1].fields[2])==1,
    'An earlier participant ACK cannot authorize another participant newer entry checkpoint')
assert(current.participants[2].entry_checkpoint_sent==nil and #sent('SceneZOI.Anchor')==0 and playback_entries==entries_before,
    'A journal changed during delivery keeps the second entry and all playback blocked')
R.tick(.05)
assert(#sent('SceneZOI.EntrySaved')==1 and not current.started,'The old ACK must remain stale on subsequent frames')
ack();F.clear_sent();R.tick(.05)
entry=sent('SceneZOI.EntrySaved')
assert(#entry==1 and entry[1].id==2 and entry[1].fields[1]==token and tonumber(entry[1].fields[2])==2,
    'The second participant receives its newer exact checkpoint after the combined journal is cached')
assert(#sent('SceneZOI.Anchor')==2 and playback_entries==entries_before+1 and current.started and not current.preparing)
finish(token)
print('Runtime journal barrier passed: latest durable entry ACK before anchors/playback, sofa heartbeats during pending updates, and independent participant revisions in one frame.')

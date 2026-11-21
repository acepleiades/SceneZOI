-- Native sofa preparation starts after save persistence and ends only with an
-- acknowledgement for the exact selected pair and all its physical aliases.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;tests/?.lua;'..package.path
local F=require('support.runtime-fixture').new()
local R,P,cfg=F.Runtime,F.Protocol,F.cfg
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation')
local Sessions=require('SceneZOI.Sessions');local Furniture=require('SceneZOI.Furniture')
local Diagnostics=require('SceneZOI.Diagnostics')
local slots={{component_name='Seat1',slot_name='Sit'},{component_name='Seat1Alias',slot_name='Sit'},
    {component_name='Seat2',slot_name='Sit'}}
local furniture={id='50',selected_pair_id='left',spot_ids={'s1','s2'},slots=slots,
    profile={id='test.sofa',kind='sofa.pair'},anchor={}}
F.node.furniture={kind='sofa.pair',surface_height_cm=44}
Furniture.prepare=function(id,_,pair)
    assert(id=='50'and pair=='left');return V.copy(furniture)
end
Furniture.actor=function()return F.actors[1]end
cfg.scene_history=''
F.add_actor(1);F.add_actor(2);R.boot()
local serial=0
local function start()
    serial=serial+1;local token='furniture.'..serial
    local row={token=token,has_household=true,lifetime={deadline_seconds=600},
        placement={max_start_distance_cm=1500,exit='restore'},restrictions={},
        req={addon_id='test.addon',client_id='client',request_id=token},
        entry={initiator='1',node='test.node',bindings={first='1',second='2'},furniture='50',furniture_pair_id='left'}}
    assert(Sessions.reserve(token,{'1','2'},'50',{'s1','s2'}))
    return R.start_background(row)
end
local function sent(kind)
    local rows={};for _,row in ipairs(F.sent)do if row.kind==kind then rows[#rows+1]=row end end;return rows
end
local function persist(token,ack)
    local record=P.encode(J.encode({token=token,collision=true}))
    for id=1,2 do R.save_reply(F.actors[id],P.pack(token,'snapshot',record))end
    if ack then
        local journal=J.decode(P.decode(cfg.save_snapshot));cfg.save_ready=P.pack(journal.host,journal.revision,'ready')
    end
end
local function reply(token,code,pair,rows)
    local fields={token,'50',code,code=='preparing'and'native_interaction_finishing'or'native_pair_reserved','none','none',pair or'left'}
    if rows then fields[8]=P.encode(J.encode(rows))end
    R.furniture_reply(F.actors[1],fields)
end
local function finish(token)
    if not R.api_session(token).stopping then R.stop('ok',token)end
    reply(token,'released')
    for id=1,2 do F.reply(token,id,'released')end
    R.flush_notifications();assert(not Sessions.holder('1'))
    F.clear_sent()
end
local token=start();F.clear_sent()
R.tick(.05);assert(#sent('SceneZOI.Furniture')==0 and #sent('SceneZOI.Commit')==0)
persist(token,false);R.tick(.05)
assert(#sent('SceneZOI.Furniture')==0,'An offered snapshot is not proof it reached the save journal')
local journal=J.decode(P.decode(cfg.save_snapshot))
assert(journal.records[1].furniture[1].pair_id=='left'and #journal.records[1].furniture[1].slots==3)
cfg.save_ready=P.pack(journal.host,journal.revision,'ready');R.tick(.05)
local acquires=sent('SceneZOI.Furniture');assert(#acquires==1)
assert(acquires[1].fields[3]=='acquire'and acquires[1].fields[5]=='left')
local roster=J.decode(P.decode(acquires[1].fields[6]));table.sort(roster)
assert(V.equal(roster,{'1','2'}),'Only the selected roster may be cleared from these seats')
assert(#sent('SceneZOI.Commit')==0,'Participants wait while native sofa occupants finish leaving')
reply(token,'held','right',slots)
assert(not R.api_session(token).furniture_ready and #sent('SceneZOI.Commit')==0,'Another pair cannot satisfy this barrier')
reply(token,'preparing')
local current=R.api_session(token);local wait=Diagnostics.wait_status(current,current.participants[1])
assert(wait.phase=='awaiting_furniture'and wait.reason=='native_interaction_finishing'and wait.furniture_pair_id=='left')
assert(not current.stopping and #sent('SceneZOI.Commit')==0)
reply(token,'held','left',{slots[3],slots[1],slots[2]})
assert(current.furniture_ready and current.furniture_wait==nil and #sent('SceneZOI.Commit')==2,
    'All aliases can arrive in native order, and only then may preparation commit')
finish(token)

for _,ack in ipairs({'missing','partial','wrong'})do
    token=start();persist(token,true);R.tick(.05);F.clear_sent()
    local provided=ack=='partial'and {slots[1]}or ack=='wrong'and {{component_name='Seat9',slot_name='Sit'}}or nil
    reply(token,'held','left',provided)
    assert(R.api_session(token).stopping and #sent('SceneZOI.Commit')==0,
        'A '..ack..' slot acknowledgement must fail closed without starting the scene')
    finish(token)
end
Diagnostics.flush()
assert(cfg.scene_history:find('furniture_pair_id=left',1,true)and cfg.scene_history:find('reason=native_slots_mismatch',1,true))
print('Runtime furniture passed: persisted recovery before native mutation, roster-only preparation, exact-pair/full-alias readiness and pair-specific failure diagnostics.')

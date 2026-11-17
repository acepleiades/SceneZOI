package.path = 'modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;' .. package.path
local J = require('SceneZOI.Json')
local P = require('SceneZOI.Protocol')
local cfg, writes, fail_load, fail_save = {}, 0, false, false
inzoi = {cli = {execute = function(command)
    local key = assert(command:match(' key=([%w_]+)'))
    local value = command:match(' value=(.+)$')
    if not value then
        if fail_load then return false, 'Read failed' end
        if cfg[key] == nil then return false, 'Key not found' end
        return true, nil, J.encode({value=cfg[key]})
    end
    if fail_save and key == 'attachment_pose_reference' then return false, 'Write failed' end
    writes = writes+1
    cfg[key] = value:sub(1,1)=='"' and value:sub(2,-2) or value
    return true
end}}
package.loaded['SceneZOI.Attachment'] = {
    preview = function(context, include_hidden_edits)
        if context.hidden and (not include_hidden_edits or not next(context.rotations)) then return end
        return {mesh='/Test/Attachment.Attachment', bones={'base', 'tip'}, rotations=context.rotations, hidden=context.hidden}
    end,
    preview_rotation = function(context, bone, rotation)
        if bone ~= 'base' and bone ~= 'tip' then return false end
        context.rotations[bone] = rotation
        return true
    end,
}
local Preview = require('SceneZOI.AttachmentPreview')
local function item(role, id)
    return {id=id, engine={id='attachment'}, context={node={attachment={participant=role}},rotations={}}}
end
local a,b = item('first', 'pack.rule.first'), item('second', 'pack.rule.second')
local s = {client='test', sequence='1', token='test.1.1', revision=1, started=true,
    node={id='pack.first',label='Same name'}, bindings={first={id='10',task_name='One'},second={id='20',task_name='Two'}},
    subsystems={items={a,b}}}
local function request(count, command, revision, token)
    Preview.request(s, P.pack('test', '1', 'attachment_preview', count, revision or s.revision, token or s.token, P.encode(J.encode(command))))
    return s.attachment_preview_code
end
local function pose(participant, attachment, bone, x)
    return {action='rotate', participant=participant, attachment=attachment, bone=bone, rotation={x,-15.5,0}}
end
Preview.publish(s,0)
local packet=P.unpack(cfg.attachment_preview_state)
local rows=J.decode(P.decode(packet[7]))
assert(packet[6]==s.token and #rows==2 and rows[1].name=='One' and rows[2].role=='second')
local previous_writes=writes
Preview.publish(s,1)
assert(writes==previous_writes,'An unchanged preview should not rewrite cfg')
assert(request(1,pose('20',a.id,'tip',13))=='preview_invalid')
assert(request(2,pose('10',a.id,'pelvis',13))=='preview_invalid')
assert(request(3,pose('10',a.id,'tip',181))=='preview_invalid')
assert(request(4,pose('10',a.id,'tip',13),1,'previous.1.1')=='preview_invalid' and s.attachment_preview_ack==3)
assert(request(4,pose('10',a.id,'tip',13))=='ok' and a.context.rotations.tip[1]==13)
assert(request(4,pose('10',a.id,'tip',88))=='ok' and a.context.rotations.tip[1]==13,'A replay cannot change an accepted edit')
assert(request(5,{action='export'})=='preview_exported')
local reference=cfg.attachment_pose_reference
assert(reference:find("scene=pack.first attachment=pack.rule.first bone=tip label='Same name' role=first x=13 y=-15.5 z=0",1,true))
assert(not reference:find('name=One',1,true),'Exports identify roles without player data')
s.node={id='pack.second',label='Same name'};s.revision=2
s.subsystems.items={item('first',a.id),b}
assert(request(6,pose('20',b.id,'base',3),1)=='preview_stale')
assert(request(7,pose('20',b.id,'base',3))=='ok')
assert(request(8,{action='export'})=='preview_exported')
assert(cfg.attachment_pose_reference:find('scene=pack.first ',1,true) and cfg.attachment_pose_reference:find('scene=pack.second ',1,true))
s.node={id='pack.first',label='Renamed'};s.revision=3
s.subsystems.items={item('first',a.id)}
assert(request(9,pose('10',a.id,'base',7))=='ok')
assert(request(10,{action='export'})=='preview_exported')
reference=cfg.attachment_pose_reference
assert(reference:find('scene=pack.first attachment=pack.rule.first bone=base label=Renamed ',1,true))
assert(not reference:find('scene=pack.first attachment=pack.rule.first bone=tip ',1,true))
assert(reference:find('scene=pack.second ',1,true),'Re-export only replaces the targeted scene ID')
fail_load=true
assert(request(11,{action='export'})=='preview_export_read' and cfg.attachment_pose_reference==reference)
s.preparing=true
assert(request(12,pose('10',a.id,'base',8))=='preview_stale')
Preview.publish(s,1)
packet=P.unpack(cfg.attachment_preview_state)
assert(packet[5]=='busy' and #J.decode(P.decode(packet[7]))==0)
s.preparing=false
fail_load=false
local covered=s.subsystems.items[1]
covered.context.hidden=true
Preview.publish(s,1)
packet=P.unpack(cfg.attachment_preview_state)
rows=J.decode(P.decode(packet[7]))
assert(#rows==1 and rows[1].hidden and rows[1].rotations.base[1]==7, 'Covered attachments keep their current-revision edits')
assert(request(13,pose('10',a.id,'base',8))=='preview_invalid' and covered.context.rotations.base[1]==7)
assert(request(14,{action='export'})=='preview_exported' and cfg.attachment_pose_reference==reference)

local visible=item('second',b.id)
s.subsystems.items={covered,visible}
assert(request(15,pose('20',b.id,'tip',12))=='ok')
assert(request(16,{action='export'})=='preview_exported')
reference=cfg.attachment_pose_reference
assert(reference:find('scene=pack.first attachment=pack.rule.first bone=base ',1,true))
assert(reference:find('scene=pack.first attachment=pack.rule.second bone=tip ',1,true))

-- A fresh entry starts with no in-memory edits, including for hidden meshes.
s.revision=4
local newly_covered=item('first',a.id)
newly_covered.context.hidden=true
s.subsystems.items={newly_covered}
Preview.publish(s,1)
packet=P.unpack(cfg.attachment_preview_state)
assert(#J.decode(P.decode(packet[7]))==0)
assert(request(17,{action='export'})=='preview_export_empty' and cfg.attachment_pose_reference==reference)
s.subsystems.items={item('first',a.id)}
assert(request(18,pose('10',a.id,'base',7))=='ok')
fail_save=true
assert(request(19,{action='export'})=='preview_export_write' and cfg.attachment_pose_reference==reference)
fail_save=false
local oversized='scene=pack.older attachment=pack.rule.first '..string.rep('a',65536)..'\n'
cfg.attachment_pose_reference=oversized
assert(request(20,{action='export'})=='preview_export_full' and cfg.attachment_pose_reference==oversized)
cfg.attachment_pose_reference=reference
assert(request(21,{action='export'})=='preview_exported')
local Diagnostics = require('SceneZOI.Diagnostics')
Diagnostics.flush()
local history = assert(cfg.scene_history)
for _, reason in ipairs({'empty','read','full','write'}) do
    local found = false
    for line in history:gmatch('[^\n]+') do
        if line:find('event=attachment_pose_export_failed',1,true) and
            line:find('reason='..reason..' ',1,true) and line:find('scene_id=pack.first',1,true) then
            found = true
        end
    end
    assert(found, 'Missing export failure diagnostic: '..reason)
end
assert(history:find("detail='Read failed'",1,true) and history:find("detail='Write failed'",1,true))
print('Attachment preview passed: identity, range, anchor rejection, hidden edits, independent participants, stale edits, and per-scene reference export.')

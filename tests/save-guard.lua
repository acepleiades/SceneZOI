package.path='modkit/SceneZOI_93C44199/workspace/lua/B2/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local sent={};local appearance_reads=0
local setting={Body={bUseMeshMerge=true},FinalBody={bUseMeshMerge=false}}
inzoi={EB2ComponentType={Appearance=1},message={send_to_client=function(id,kind,value)
 assert(id=='1'and kind=='SceneZOI.Save');sent[#sent+1]=P.unpack(value)
end}}
local owner={GetEntityId=function()return '1'end,GetComponent=function(_,kind)
 assert(kind==1);appearance_reads=appearance_reads+1
 return {GetAppearanceSetting=function()return setting end}
end}
local Save=require('SceneZOI.SaveGuard')
local original_time=os.time;local now=100;os.time=function()return now end
local lease={token='settled',collision=true,local_value=true,follow_parent=true,
 entry_location={X=1,Y=2,Z=3},entry_rotation={Pitch=4,Yaw=5,Roll=6},
 grab_snapshot={{hand=0,id='7',pose='Hold'}}}
Save.offer(owner,lease)
assert(#sent==1 and sent[1][2]=='snapshot'and appearance_reads==1)
local original=J.decode(P.decode(sent[1][3]))
assert(original.location[1]==1 and original.collision and original.local_value and original.follow_parent)
assert(original.body_merge.base and not original.body_merge.final and original.outfit)
assert(not pcall(Save.settled,owner,lease),'Settlement cannot update a lease before task settlement')
lease.tasks_settled=true
assert(Save.settled(owner,lease))
assert(#sent==1,'No changed coordinates require no new journal revision')
-- Current prepare flags and appearance may have changed. Only native exit's
-- final return coordinates replace the original recovery values.
lease.collision=false;lease.local_value=false;lease.follow_parent=false
lease.grab_snapshot={{hand=1,id='8',pose='Other'}}
setting.Body.bUseMeshMerge=false;setting.FinalBody.bUseMeshMerge=true
lease.entry_location={X=101,Y=202,Z=303};lease.entry_rotation={Pitch=0,Yaw=90,Roll=0}
assert(not Save.settled(owner,lease),'Changed coordinates require the exact entry checkpoint ACK')
assert(#sent==2 and sent[2][2]=='settled_snapshot'and appearance_reads==1)
local update=J.decode(P.decode(sent[2][3]))
assert(update.token=='settled'and update.checkpoint==1 and update.location[1]==101 and update.rotation[2]==90)
for key in pairs(update)do assert(key=='token'or key=='checkpoint'or key=='location'or key=='rotation','Private settled message contains only entry coordinates')end
local cached=lease.save_snapshot
assert(cached.collision and cached.local_value and cached.follow_parent and cached.outfit)
assert(cached.body_merge.base and not cached.body_merge.final and cached.grab_poses[1].id=='7')
assert(cached.location[1]==101 and cached.rotation[2]==90)
Save.offer(owner,lease);assert(not Save.settled(owner,lease))
assert(#sent==3,'Repeated native ticks do not spam the pending checkpoint')
lease.entry_checkpoint_acked=0;assert(not Save.settled(owner,lease),'An older checkpoint cannot acknowledge the new entry transform')
now=101;assert(not Save.settled(owner,lease))
assert(#sent==4 and sent[3][2]=='settled_snapshot'and sent[4][2]=='settled_snapshot',
 'A paced resend lets a failed journal write recover idempotently')
lease.entry_checkpoint_acked=1;assert(Save.settled(owner,lease)and #sent==4)
lease.entry_location={X=401,Y=402,Z=403}
assert(not Save.settled(owner,lease)and lease.entry_checkpoint==2 and #sent==5,
 'A later native entry transform cannot reuse an old checkpoint acknowledgement')
lease.entry_checkpoint_acked=2;assert(Save.settled(owner,lease))
lease.entry_location.X=0/0
assert(not pcall(Save.settled,owner,lease),'Invalid native coordinates cannot enter the save journal')
assert(cached.location[1]==401,'Rejected coordinates preserve the last valid snapshot')
os.time=original_time
print('Save guard passed: settled native coordinates only, unchanged original flags/body/grabs, no-op capture, bounded private payload and idempotent resend.')

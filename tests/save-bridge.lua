package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local cfg={save_restore=P.pack('stale',1,'restore',P.encode('{}'))};local sent={};local B
local fail_snapshot_write=false
inzoi={cli={execute=function(command)
 local key=command:match(' key=([%w_]+)')
 if command:find('cfg_save',1,true)then
  if fail_snapshot_write and key=='save_snapshot'then return false,'test write failure' end
  cfg[key]=command:match(' value=(.*)');return true
 end
 return true,nil,cfg[key]
end},message={send_to_sim=function(id,kind,content)sent[#sent+1]={id=id,kind=kind,fields=P.unpack(content)}end}}
local function actor(id)return {GetEntityId=function()return id end}end
local function journal()return J.decode(P.decode(cfg.save_snapshot))end
local function record(token)for _,r in ipairs(journal().records)do if r.token==token then return r end end end
B=require('SceneZOI.SaveBridge');B.boot();B.tick({});assert(journal().version==2 and #journal().records==0,'Old cfg request must not replay after boot')
local a,b,c,d=actor('1'),actor('2'),actor('3'),actor('4')
local one={token='scene.1',client='client',sequence='1',participants={{actor=a,id='1'},{actor=b,id='2'}},furniture={id='9'},furniture_owner={id='1'}}
local two={token='scene.2',client='host',sequence='0',participants={{actor=c,id='3'},{actor=d,id='4'}}}
local data={token=one.token,collision=true}
B.offer(one,a,{one.token,'snapshot',P.encode(J.encode(data))});assert(not record('scene.1'))
B.offer(one,actor('5'),{one.token,'snapshot','00'});assert(not record('scene.1'),'Only the roster may offer')
B.offer(one,b,{one.token,'snapshot',P.encode(J.encode(data))});assert(record('scene.1')and not B.ready(one))
local host,revision=journal().host,journal().revision
cfg.save_ready=P.pack('other',revision,'ready');assert(not B.ready(one),'Another host must not acknowledge')
cfg.save_ready=P.pack(host,revision-1,'ready');assert(not B.ready(one),'An older revision must not acknowledge')
cfg.save_ready=P.pack(host,revision,'ready');assert(B.ready(one))
assert(record('scene.1').furniture[1].owner=='1'and record('scene.1').participants['2'].collision)
-- A second scene joins the same journal and needs its own acknowledgement.
local data2={token=two.token,collision=false}
B.offer(two,c,{two.token,'snapshot',P.encode(J.encode(data2))});B.offer(two,d,{two.token,'snapshot',P.encode(J.encode(data2))})
assert(#journal().records==2 and not B.ready(two))
cfg.save_ready=P.pack(host,journal().revision,'ready');assert(B.ready(two))
-- A live scene is not a recovery: nothing is sent and its roster is not blocked here.
sent={};B.tick({['1']=a,['2']=b});assert(#sent==0 and not B.overlaps({'1'}))
-- A clean finish leaves nothing. An unconfirmed participant stays, alone, for later.
B.finish('scene.1',{},false);assert(not record('scene.1')and record('scene.2'))
B.finish('scene.2',{'4'},false);assert(record('scene.2').participants['4']and not record('scene.2').participants['3'])
assert(B.overlaps({'4'})and not B.overlaps({'3'}),'Only the unconfirmed Zoi is refused')
B.tick({['3']=c});assert(#sent==0,'An absent Zoi is simply waited for')
B.tick({['4']=d});assert(#sent==1 and sent[1].kind=='SceneZOI.Recover'and sent[1].fields[1]=='scene.2')
sent={};B.tick({['4']=d});assert(#sent==0,'Recovery retries are paced')
B.offer(nil,c,{'scene.2','recovered'});assert(record('scene.2'),'Another Zoi cannot acknowledge')
B.offer(nil,d,{'scene.2','recovered'});assert(not record('scene.2')and not B.overlaps({'4'}))
assert(not B.resolve('scene.2','4'))
-- Loading: the whole journal is indexed at once, and only what it names is blocked.
local function load_rows(rows,client,n)cfg.save_restore=P.pack(client,n,'restore',P.encode(J.encode({version=2,records=rows})));B.tick({})end
-- A journal delivered but not yet read holds every start back.
assert(not B.restore_waiting());cfg.save_restore=P.pack('early',1,'restore',P.encode(J.encode({version=2,records={}})));assert(B.restore_waiting(),'Not read yet')
B.tick({});assert(not B.restore_waiting())
load_rows({{token='saved.1',participants={['5']={token='saved.1'},['6']={token='saved.1'}},furniture={{id='8',owner='5'}}}},'new',2)
assert(cfg.save_restore_state==P.pack('new',2,'ready','ok'),'Indexing must not wait for absent Zois')
assert(B.overlaps({'5'})and B.overlaps({},'8')and not B.overlaps({'7'})and not B.overlaps({},'9'),'An unrelated start stays possible')
assert(record('saved.1').participants['5'],'Unresolved records stay in later saves')
sent={};local five=actor('5');B.tick({['5']=five});assert(#sent==2)
B.offer(nil,five,{'saved.1','recovered'});assert(B.overlaps({},'8')and not B.overlaps({'5'}),'Participant and furniture recover independently')
B.offer(nil,five,{'saved.1','furniture_recovered'});assert(not B.overlaps({},'8'))
-- Repeated saves keep what is still unresolved.
local before_saves=journal();B.tick({});B.tick({});assert(#journal().records==#before_saves.records and record('saved.1'),'Still there after more saves')
-- A released Zoi can be confirmed through another route.
assert(B.resolve('saved.1','6')and not record('saved.1'))
-- Records from the single-session journal format still recover.
cfg.save_restore=P.pack('old',3,'restore',P.encode(J.encode({version=1,token='v1',participants={['5']={token='v1',lent_costume='Uniform01'}},furniture={}})));B.tick({})
assert(cfg.save_restore_state==P.pack('old',3,'ready','ok')and B.overlaps({'5'}))
assert(record('v1').participants['5'].lent_costume=='Uniform01','Recovery must retain old saved outfit data')
-- Loading another save replaces what the last one left behind.
load_rows({},'empty',4);assert(not B.overlaps({'5'}))
-- A bad journal is refused; one bad record is not allowed to lose the others.
cfg.save_restore=P.pack('new',5,'restore',P.encode('{}'));B.tick({});assert(cfg.save_restore_state==P.pack('new',5,'error','invalid_recovery'))
load_rows({{token='bad',participants='nope',furniture={}},{token='good',participants={['5']={token='good'}},furniture={}}},'mixed',6)
assert(B.overlaps({'5'})and record('good')and not record('bad'))
-- Loading a large journal and adding a new scene retain older unresolved participants and furniture.
local many={};for i=1,40 do many[i]={token='r'..i,participants={[tostring(100+i)]={token='r'..i}},furniture={}}end
many[1].furniture={{id='81',owner='101'}}
load_rows(many,'many',7);assert(#journal().records==40 and B.overlaps({'101'}) and B.overlaps({},'81'))
local extra={token='extra',participants={{actor=a,id='1'}}}
local extra_offer={'extra','snapshot',P.encode(J.encode({token='extra'}))}
fail_snapshot_write=true
B.offer(extra,a,extra_offer);assert(not B.ready(extra) and #journal().records==40)
fail_snapshot_write=false
B.offer(extra,a,extra_offer);assert(record('extra') and #journal().records==41 and record('r1'))
load_rows(journal().records,'reload',8);assert(#journal().records==41 and B.overlaps({'101'}) and B.overlaps({},'81'))
B.offer(nil,actor('101'),{'r1','recovered'});assert(record('r1') and not B.overlaps({'101'}))
B.offer(nil,actor('101'),{'r1','furniture_recovered'});assert(not record('r1') and #journal().records==40)
print('Save bridge passed: one journal for every scene, host and revision acknowledgements, per-resource recovery, unrelated starts during recovery, overflow retention and old-format migration.')


-- A restore sent by the current UI but interrupted by a Lua restart is still pending.
cfg.ui_boot='live'
cfg.save_restore=P.pack('live',12,'restore',P.encode(J.encode({version=2,records={{token='reload',participants={['6']={token='reload'}},furniture={}}}})))
B.boot()
assert(B.restore_waiting())
B.tick({})
assert(B.overlaps({'6'})and not B.restore_waiting())

-- A deferred sofa pair must not block unrelated seats on the same object.
local sofa={id='50',owner='5',pair_id='ab',spots={'a','b'},slots={{component_name='SeatA',slot_name='SitA'},{component_name='SeatB',slot_name='SitB'}}}
load_rows({{token='sofa.saved',participants={},furniture={sofa}}},'sofa',20)
assert(B.overlaps({},'50',{'a','b'})and B.overlaps({},'50',{'b','c'})and not B.overlaps({},'50',{'c','d'}))
assert(B.overlaps({},'50'),'A whole-object request still overlaps a pending pair')
sent={};B.tick({['5']=five});assert(#sent==1 and sent[1].kind=='SceneZOI.FurnitureRecover')
local recovery=J.decode(P.decode(sent[1].fields[2]))
assert(recovery[1].pair_id=='ab'and recovery[1].spots[2]=='b'and recovery[1].slots[2].slot_name=='SitB','Exact physical/native pair identity survives the save bridge')
print('Sofa save bridge passed: exact pair/slot recovery and disjoint-seat availability during deferred cleanup.')


-- Native GetUp can finish after the first save acknowledgement. A new journal
-- revision replaces only the return coordinates before the host may anchor.
B.boot()
local moving={token='scene.settled',preparing=true,participants={{actor=a,id='1'},{actor=b,id='2'}}}
local first={version=1,token=moving.token,collision=true,local_value=true,follow_parent=false,
 location={1,2,3},rotation={4,5,6},outfit=true,body_merge={base=true,final=false},grab_poses={{hand=0,id='7',pose='Hold'}},furniture={}}
local second={version=1,token=moving.token,collision=false,local_value=false,follow_parent=true,
 location={10,20,30},rotation={40,50,60},outfit=false}
local function offer_snapshot(person,value)B.offer(moving,person,{moving.token,'snapshot',P.encode(J.encode(value))})end
local checkpoints={['1']=1,['2']=1}
local function settled(person,location,rotation,extra)
 local value={token=moving.token,checkpoint=checkpoints[P.id(person:GetEntityId())]or 1,location=location,rotation=rotation}
 for key,v in pairs(extra or {})do value[key]=v end
 B.offer(moving,person,{moving.token,'settled_snapshot',P.encode(J.encode(value))})
end
offer_snapshot(a,first);offer_snapshot(b,second)
local settled_host=journal().host
cfg.save_ready=P.pack(settled_host,journal().revision,'ready');assert(B.ready(moving))
local original_revision=journal().revision
settled(a,{101,102,103},{0,90,0})
local revision_a=journal().revision
assert(revision_a==original_revision+1 and B.checkpoint(moving,'1')==1 and not B.checkpoint(moving,'2')and not moving.save_ready and not B.ready(moving),
 'The original ACK cannot authorize anchoring after a settled coordinate update')
local saved=record(moving.token).participants['1']
assert(saved.location[1]==101 and saved.rotation[2]==90 and saved.collision and saved.local_value and not saved.follow_parent)
assert(saved.outfit and saved.body_merge.base and not saved.body_merge.final and saved.grab_poses[1].id=='7',
 'Body, outfit, policy, collision and held-object originals remain from the first snapshot')
settled(a,{101,102,103},{0,90,0});assert(journal().revision==revision_a,'Repeated identical updates do not republish')
offer_snapshot(a,first)
assert(record(moving.token).participants['1'].location[1]==101 and journal().revision==revision_a,
 'A delayed original offer cannot revert settled return coordinates')
-- Each participant can finish in a different tick. An ACK for the first update
-- must not authorize a later update to another participant in the same journal.
cfg.save_ready=P.pack(settled_host,revision_a,'ready');assert(B.ready(moving))
settled(b,{201,202,203},{0,180,0})
local revision_b=journal().revision
assert(revision_b==revision_a+1 and B.checkpoint(moving,'2')==1 and not B.ready(moving))
assert(record(moving.token).participants['1'].location[1]==101 and record(moving.token).participants['2'].location[1]==201)
local before_rejected=cfg.save_snapshot
settled(actor('1'),{999,0,0},{0,0,0}) -- Same entity ID does not establish actor identity.
settled(c,{999,0,0},{0,0,0})
settled(a,{999,0,0},{0,0,0},{collision=false})
settled(a,{999,0},{0,0,0})
B.offer(moving,a,{'wrong.token','settled_snapshot',P.encode(J.encode({token='wrong.token',checkpoint=1,location={999,0,0},rotation={0,0,0}}))})
moving.preparing=false;settled(a,{999,0,0},{0,0,0});moving.preparing=true
moving.stopping=true;settled(a,{999,0,0},{0,0,0});moving.stopping=nil
assert(cfg.save_snapshot==before_rejected and journal().revision==revision_b,
 'Unowned, late, stopping, wrong-token or non-coordinate updates are inert')
cfg.save_ready=P.pack(settled_host,revision_b,'ready');assert(B.ready(moving))
-- A failed CFG write must hold even if an old/high acknowledgement is present.
-- The next identical resend retries that intended journal without losing flags.
fail_snapshot_write=true;checkpoints['1']=2
settled(a,{301,302,303},{0,270,0})
assert(journal().revision==revision_b and B.checkpoint(moving,'1')==1 and moving.journal_update_pending and not B.ready(moving),
 'A failed write must not publish the new entry checkpoint')
cfg.save_ready=P.pack(settled_host,revision_b+100,'ready')
assert(not B.ready(moving),'Write failure is not bypassed by any previous ready token')
checkpoints['2']=2;settled(b,{401,402,403},{0,180,0})
assert(B.checkpoint(moving,'1')==1 and B.checkpoint(moving,'2')==1 and journal().revision==revision_b,
 'Two independent pending participant updates cannot expose unpublished checkpoints')
fail_snapshot_write=false
settled(a,{301,302,303},{0,270,0})
local revision_retry=journal().revision
assert(revision_retry==revision_b+1 and B.checkpoint(moving,'1')==2 and B.checkpoint(moving,'2')==2 and not moving.journal_update_pending)
assert(record(moving.token).participants['2'].location[1]==401 and record(moving.token).participants['2'].follow_parent,
 'One successful retry publishes both participants while preserving each original policy')
assert(record(moving.token).participants['1'].location[1]==301 and record(moving.token).participants['1'].body_merge.base)
cfg.save_ready=P.pack(settled_host,revision_b,'ready');assert(not B.ready(moving))
cfg.save_ready=P.pack(settled_host,revision_retry,'ready');assert(B.ready(moving))
settled(a,{301,302,303},{0,270,0});assert(journal().revision==revision_retry)
settled(a,{101,102,103},{0,90,0},{checkpoint=1})
settled(a,{999,0,0},{0,0,0})
assert(journal().revision==revision_retry and record(moving.token).participants['1'].location[1]==301,
 'Stale checkpoints and different coordinates under the same checkpoint cannot revert the journal')
B.finish(moving.token,{'1'},false)
local deferred_revision=journal().revision
settled(a,{999,0,0},{0,0,0})
assert(journal().revision==deferred_revision and record(moving.token).participants['1'].location[1]==301,
 'A deferred recovery record cannot be rewritten by a late settlement message')
print('Settled save bridge passed: transform-only updates, original state retained, independent participant revisions, latest-ACK gate, identity/phase rejection and write-failure retry.')

-- Released simulation state does not confirm the new client's rendered position.
B.boot()
local native_time, previous_time = 1000, os.time
os.time = function() return native_time end
local function transform(x, y, z)
 return {Translation={X=x,Y=y,Z=z}, Rotation={X=0,Y=0,Z=0,W=1}, Scale3D={X=1,Y=1,Z=1}}
end
local anchor, entry = transform(500,600,750), transform(380,600,700)
local function visual_actor(id, position)
 local client=actor(id)
 client.transform,client.writes=position,0
 function client:GetTransform() return self.transform end
 function client:K2_GetActorLocation() return self.transform.Translation end
 function client:K2_SetActorTransform(target,sweep,hit,teleport)
  assert(target==entry and sweep==false and hit==nil and teleport==true,
   'Return to the original client transform in one non-swept native teleport')
  self.writes=self.writes+1
  if self.fail then return false end
  self.transform=target
  return true
 end
 return client
end
local function queue_position(token,id)
 local owner=actor(id)
 local current={token=token,participants={{actor=owner,id=id}}}
 -- Recovery uses a normal persisted record created before anchoring.
 B.offer(current,owner,{token,'snapshot',P.encode(J.encode({token=token,collision=true}))})
 local original=J.encode(record(token))
 B.defer_position(token,id,anchor,entry)
 assert(J.encode(record(token))==original,'The native client transform is kept out of the durable save format')
 return owner
end

local client_id, client_token = '21','client.near'
local original_actor=queue_position(client_token,client_id)
B.finish(client_token,{client_id},false)
local returned=visual_actor(client_id,transform(501,602,700)) -- The actor settled from the furniture to the floor.
B.tick({[client_id]=returned})
assert(returned.writes==0 and B.overlaps({client_id}),'Do not reconcile the client before simulation acknowledges')
B.offer(nil,original_actor,{client_token,'recovered'})
assert(B.overlaps({client_id}),'A simulation acknowledgement cannot release the overlap guard by itself')
B.tick({})
assert(B.overlaps({client_id}) and returned.writes==0,'A missing client waits even after simulation confirms its release')
native_time=native_time+2
B.tick({[client_id]=returned})
assert(returned.writes==1 and returned:GetTransform()==entry)
assert(not B.overlaps({client_id}) and not record(client_token),'Restoring the rendered position retires the journal entry')
B.tick({[client_id]=returned})
assert(returned.writes==1,'A later client tick does not apply the transform again')

local moved_id, moved_token = '22','client.moved'
queue_position(moved_token,moved_id)
assert(B.resolve(moved_token,moved_id),'The simulation relay can confirm before cleanup hands off to the journal')
B.finish(moved_token,{},false)
assert(B.overlaps({moved_id}),'A live relay does not discard the pending client check')
local new_position=transform(504,600,700)
local moved=visual_actor(moved_id,new_position)
B.tick({[moved_id]=moved})
assert(moved.writes==0 and moved:GetTransform()==new_position,'Do not pull back a Zoi that already moved away')
assert(not B.overlaps({moved_id}) and not record(moved_token))

local upstairs_id,upstairs_token='24','client.upstairs'
queue_position(upstairs_token,upstairs_id)
B.finish(upstairs_token,{upstairs_id},false)
B.resolve(upstairs_token,upstairs_id)
local upstairs=visual_actor(upstairs_id,transform(500,600,1000))
B.tick({[upstairs_id]=upstairs})
assert(upstairs.writes==0 and not B.overlaps({upstairs_id}),'Do not move a Zoi who is now on a different floor')

local retry_id,retry_token='23','client.retry'
local retry_source=queue_position(retry_token,retry_id)
B.finish(retry_token,{retry_id},false)
B.offer(nil,retry_source,{retry_token,'recovered'})
local retry=visual_actor(retry_id,anchor)
retry.fail=true
B.tick({[retry_id]=retry})
assert(retry.writes==1 and B.overlaps({retry_id}),'A failed native transform leaves the participant guarded')
retry.fail=false
native_time=native_time+2
B.tick({[retry_id]=retry})
assert(retry.writes==2 and retry:GetTransform()==entry and not B.overlaps({retry_id}) and not record(retry_token),
 'A transient client write failure is retried before retiring the recovery')
os.time=previous_time
print('Client position recovery passed: no durable format change, separate simulation and client confirmation, released-on-unload relay, no movement overwrite, and retry.')

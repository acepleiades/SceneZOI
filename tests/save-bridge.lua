package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local cfg={save_restore=P.pack('stale',1,'restore',P.encode('{}'))};local sent={};local B
inzoi={cli={execute=function(command)
 local key=command:match(' key=([%w_]+)')
 if command:find('cfg_save',1,true)then cfg[key]=command:match(' value=(.*)');return true end
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
cfg.save_restore=P.pack('old',3,'restore',P.encode(J.encode({version=1,token='v1',participants={['5']={token='v1'}},furniture={}})));B.tick({})
assert(cfg.save_restore_state==P.pack('old',3,'ready','ok')and B.overlaps({'5'}))
-- Loading another save replaces what the last one left behind.
load_rows({},'empty',4);assert(not B.overlaps({'5'}))
-- A bad journal is refused; one bad record is not allowed to lose the others.
cfg.save_restore=P.pack('new',5,'restore',P.encode('{}'));B.tick({});assert(cfg.save_restore_state==P.pack('new',5,'error','invalid_recovery'))
load_rows({{token='bad',participants='nope',furniture={}},{token='good',participants={['5']={token='good'}},furniture={}}},'mixed',6)
assert(B.overlaps({'5'})and record('good')and not record('bad'))
-- The journal is bounded: the oldest record goes, the newest stay.
local many={};for i=1,40 do many[i]={token='r'..i,participants={[tostring(100+i)]={token='r'..i}},furniture={}}end
load_rows(many,'many',7);assert(#journal().records==32 and not record('r1')and record('r40'))
-- The record learns which uniform was really taken off.
load_rows({{token='worn',participants={['61']={token='worn'}},furniture={}}},'worn',8)
B.offer(nil,actor('61'),{'worn','lent','Uniform01'});assert(record('worn').participants['61'].lent_costume=='Uniform01')
print('Save bridge passed: one journal for every scene, host and revision acknowledgements, per-resource recovery, unrelated starts during recovery, bounded size and old-format migration.')

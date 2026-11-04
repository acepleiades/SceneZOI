package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local J=require('SceneZOI.Json')
local cfg={save_restore=P.pack('stale',1,'restore',P.encode('{}'))};local sent={};local B
inzoi={cli={execute=function(command)
 local key=command:match(' key=([%w_]+)')
 if command:find('cfg_save',1,true)then cfg[key]=command:match(' value=(.*)');return true end
 return true,nil,cfg[key]
end},message={send_to_sim=function(id,kind,content)sent[#sent+1]={id=id,kind=kind,content=content}end}}
B=require('SceneZOI.SaveBridge');B.boot();B.tick({},false);assert(not B.busy(),'Old cfg request must not replay after boot')
local a={GetEntityId=function()return '1'end};local b={GetEntityId=function()return '2'end}
local c={token='scene.1',client='client',sequence='1',participants={{actor=a,id='1'},{actor=b,id='2'}},furniture={id='3'},furniture_owner={id='1'}}
local record={token=c.token,collision=true}
B.offer(c,a,{c.token,'snapshot',P.encode(J.encode(record))});assert(not cfg.save_snapshot)
B.offer(c,{GetEntityId=function()return '4'end}, {c.token,'snapshot','00'});assert(not cfg.save_snapshot)
B.offer(c,b,{c.token,'snapshot',P.encode(J.encode(record))});assert(cfg.save_snapshot and not B.ready(c))
cfg.save_ready=P.pack('other',1,'ready',c.token);assert(not B.ready(c))
cfg.save_ready=P.pack('client',1,'ready',c.token);assert(B.ready(c))
local saved=J.decode(P.decode(cfg.save_snapshot));assert(saved.furniture[1].owner=='1'and saved.participants['2'].collision)
cfg.save_restore=P.pack('new',2,'restore',cfg.save_snapshot);B.tick({},true);assert(B.busy()and #sent==0)
B.tick({['1']=a,['2']=b},false);assert(#sent==3 and cfg.save_restore_state==P.pack('new',2,'pending','ok'))
B.offer(nil,a,{'wrong','recovered'});B.tick({},false);assert(B.busy())
B.offer(nil,a,{'new.2','recovered'});B.offer(nil,b,{'new.2','recovered'});sent={}
B.tick({['1']=a,['2']=b},false);assert(#sent==1 and sent[1].kind=='SceneZOI.FurnitureRecover','Completed participants must not be replayed while furniture retries')
B.offer(nil,a,{'new.2','furniture_recovered'});B.tick({},false);assert(not B.busy()and cfg.save_restore_state==P.pack('new',2,'ready','ok'))
sent={};B.tick({['1']=a},false);assert(#sent==0,'Completed request must remain retired')
cfg.save_restore=P.pack('new',3,'restore',P.encode('{}'));B.tick({},false);assert(not B.busy()and cfg.save_restore_state==P.pack('new',3,'error','invalid_recovery'))
print('Save bridge passed: complete snapshot barrier, stale acknowledgements, old cfg retirement, independent participant/furniture retries and invalid journals.')

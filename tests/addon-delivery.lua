-- One released subscriber must not stop event delivery to the others.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json')
local function actor(id)return {GetEntityId=function()return {Value=id}end}end
local live,gone,later=actor(1),actor(2),actor(3)
package.loaded['SceneZOI.Runtime']={actors={},snapshot=function()end}
package.loaded['SceneZOI.Catalog']={refresh=function()end,get_snapshot=function()return {}end}
package.loaded['SceneZOI.SceneSearch']={}
local received,encodes={},0
inzoi={cli={execute=function()return true,''end},message={send_to_sim=function(id,kind,content)
 if kind=='SceneZOI.API.Event'then received[id.Value]=(received[id.Value]or 0)+1 end
end}}
local API=require('SceneZOI.AddonAPI');API.boot()
local serial=0
local function subscribe(from,addon)
 serial=serial+1
 API.receive(from,J.encode({api_version=1,addon_id=addon,client_id='client',request_id='r'..serial,operation='subscribe',arguments={events={'*'}}}))
end
subscribe(live,'live.addon');subscribe(gone,'gone.addon');subscribe(later,'later.addon')
local E=require('SceneZOI.Events')
E.emit('session_started',{id='scene.1',phase='playing'});E.flush()
assert(received[1]==1 and received[2]==1 and received[3]==1,'Every live subscriber receives the event')
-- The native object is released: reading its ID throws.
gone.GetEntityId=function()error('attempt to call UFunction on released object')end
E.emit('node_entered',{id='scene.1',phase='playing'});E.flush()
assert(received[1]==2 and received[3]==2,'A released subscriber must not stop delivery to the others')
assert(received[2]==1)
-- A dead endpoint is retired, so it is not retried on every later event.
local reads=0
gone.GetEntityId=function()reads=reads+1;error('released')end
E.emit('session_ended',{id='scene.1',phase='ended'});E.flush()
assert(received[1]==3 and received[3]==3 and reads==0,'A confirmed-dead subscriber is retired')
print('Add-on delivery passed: released subscribers are isolated and retired, live subscribers still receive every event.')

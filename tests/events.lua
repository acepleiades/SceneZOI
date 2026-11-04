package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local Events=require('SceneZOI.Events')
local received=0
inzoi={message={send_to_client=function()error('Retired packed event bridge must not deliver')end}}
local payload={id='session.1',event_index=1,node_id='pack.idle',participants={{id='1'}}}
local handle=Events.subscribe('node_entered',function(event)received=received+1;event.participants[1].id='changed'end)
local throwing=Events.subscribe('*',function()error('Injected observer error')end)
Events.emit('node_entered',payload,'ok');assert(received==0);Events.flush()
assert(received==1 and payload.participants[1].id=='1')
local history=Events.history();history[1].participants[1].id='changed'
assert(Events.history()[1].participants[1].id=='1'and Events.history()[1].code=='ok')
Events.unsubscribe(handle);Events.unsubscribe(throwing)
Events.emit('node_entered',payload);Events.flush();assert(received==1)
print('Events: deferred/copy isolation, history, unsubscribe and no retired packed bridge passed.')

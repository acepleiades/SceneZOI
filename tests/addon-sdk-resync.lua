package.path='sdk/lua/?.lua;'..package.path
local J=require('SceneZOIAddon.Json');local SDK=require('SceneZOIAddon.Client');local sends,events,replies,changes={},{},{},{}
inzoi={message={send_to_client=function(_,_,raw)sends[#sends+1]=J.decode(raw)end}}
local owner={GetEntityId=function()return 1 end}
local client=SDK.new('test.addon',{event=function(e)events[#events+1]=e end,response=function(r)replies[#replies+1]=r end,instance_changed=function(a,b)changes[#changes+1]={a,b}end})
local function packet(kind,extra,host)
 extra.api_version=1;extra.addon_id=client.addon_id;extra.client_id=client.client_id;extra.instance_id=host or 'host.1'
 assert(client:on_message('SceneZOI.API.'..kind,J.encode(extra)))
end
client:request(owner,'subscribe','subscribe',{})
packet('Response',{request_id='subscribe',ok=true,result={event_cursor=10,session={id='s.1',event_index=5}}})
packet('Event',{event={session_id='s.1',event_index=5,event_cursor=11,name='old'}});assert(#events==0)
packet('Event',{event={session_id='s.1',event_index=6,event_cursor=12,name='next'}})
packet('Event',{event={session_id='s.1',event_index=6,event_cursor=12,name='next'}});assert(#events==1)
client:request(owner,'register','register_integration',{capabilities={'tasks'}})
packet('Response',{request_id='register',ok=true,result={lease_seconds=12}});client:tick(2.1)
assert(sends[#sends].operation=='renew_integration')
client:request(owner,'mutation','set_task_progress',{})
packet('Event',{event={session_id='s.2',event_index=1,event_cursor=1,name='new'}},'host.2')
assert(#changes==1 and client.integration==nil and #events==2 and next(client.pending)==nil)
assert(replies[#replies].code=='host_changed')
client.callbacks.instance_changed=function()client:request(owner,'resync.callback','get_version',{})end
packet('Event',{event={session_id='s.3',event_index=1,event_cursor=1,name='new'}},'host.3')
assert(client.pending['resync.callback']and sends[#sends].expected_instance_id=='host.3','A callback may resubscribe/query the new host without losing the request')

local snapshot={participants={{id='1',role='a'},{id='2',role='b'},{id='3',role='c'}},actions={{type='hug',actor='a',target='b',performer='a'},{type='hug',actor='c',target='a',performer='c'}},task_state={{participant_id='1',task_id='energy',maximum=5,percent=20}}}
assert(SDK.roles(snapshot).b=='2'and #SDK.actions(snapshot,'1')==2 and #SDK.partners(snapshot,'1','hug')==2)
assert(SDK.task(snapshot,'1','energy').maximum==5 and #SDK.navigation({locked=true,navigation={{}}})==0)
print('SDK resynchronization: consistent subscribe snapshot, stale/duplicate events, host reset, uncertain request retirement, lease heartbeat and participant/action/task helpers passed.')

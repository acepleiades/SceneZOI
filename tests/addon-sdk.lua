package.path='sdk/lua/?.lua;'..package.path
local J=require('SceneZOIAddon.Json');local Client=require('SceneZOIAddon.Client')
local sends,responses,events={},{},{}
inzoi={message={send_to_client=function(id,kind,content)sends[#sends+1]={id,kind,content}end}}
local owner={GetEntityId=function()return 1 end}
local c=Client.new('test.addon',{response=function(r)responses[#responses+1]=r end,event=function(e)events[#events+1]=e end})
c:request(owner,'first','get_version',{});local raw=sends[1][3];assert(J.decode(raw).api_version==1)
c:tick(1.1);assert(#sends==2 and sends[2][3]==raw,'Retries preserve exact request identity and payload')
local packet={api_version=1,addon_id='test.addon',client_id='other',request_id='first',ok=true}
assert(not c:on_message('SceneZOI.API.Response',J.encode(packet))and c.pending.first)
packet.client_id=c.client_id;assert(c:on_message('SceneZOI.API.Response',J.encode(packet)));c:on_message('SceneZOI.API.Response',J.encode(packet));assert(#responses==1 and not c.pending.first)
packet.event={name='session_started'};c:on_message('SceneZOI.API.Event',J.encode(packet));assert(#events==1)
c:request(owner,'timeout','get_version',{});c:tick(12);assert(responses[#responses].code=='transport_timeout')
local invalid={GetEntityId=function()error('released actor')end}
c:request(invalid,'released','get_version',{});assert(pcall(c.tick,c,1));c:tick(12);assert(responses[#responses].code=='transport_timeout')
assert(not c:on_message('SceneZOI.API.Event','invalid json'))
print('Add-on SDK passed: exact retries, private client correlation, duplicate replies, copied event dispatch, timeout and released-owner delivery failure.')

-- Native wrappers can be replaced while the entity ID remains stable.
local old_owner={alive=true,GetEntityId=function(self)assert(self.alive,'expired native wrapper');return {Value=17}end}
local fresh_owner={GetEntityId=function()return {Value=17}end}
local outsider={GetEntityId=function()return {Value=18}end}
local renewed=Client.new('test.refresh')
renewed:request(old_owner,'register','register_integration',{capabilities={'tasks'}})
renewed:on_message('SceneZOI.API.Response',J.encode({api_version=1,addon_id=renewed.addon_id,client_id=renewed.client_id,instance_id='host.test',request_id='register',ok=true,result={lease_seconds=12}}))
renewed:request(old_owner,'waiting','get_session',{})
old_owner.alive=false;renewed:refresh_owner(outsider)
assert(renewed.pending.waiting.owner==old_owner and renewed.integration.owner==old_owner,'Another entity must not take over the caller')
renewed:tick(2.1,fresh_owner)
assert(renewed.pending.waiting.owner==fresh_owner and renewed.integration.owner==fresh_owner)
assert(renewed.pending['sdk.renew.1'].owner==fresh_owner,'Renewals must use the refreshed native wrapper')
assert(J.decode(renewed.pending.waiting.raw).operation=='get_session','Refresh must preserve request identity/payload')
print('SDK owner refresh passed: stable entity identity, replaced native wrappers, pending retries, automatic renewals and outsider refusal.')

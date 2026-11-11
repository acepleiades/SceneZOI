-- Add-ons written for one scene keep seeing one scene; others opt in to more.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json')
local function actor(id)return {GetEntityId=function()return {Value=id}end}end
local legacy,focused,owned,all,owner=actor(1),actor(2),actor(3),actor(4),actor(5)
package.loaded['SceneZOI.Runtime']={actors={},snapshot=function()end,snapshots=function()return J.array({{id='scene.1'},{id='scene.2'}})end}
package.loaded['SceneZOI.Catalog']={refresh=function()end,get_snapshot=function()return {}end}
package.loaded['SceneZOI.SceneSearch']={}
local got,responses={},{}
inzoi={cli={execute=function()return true,''end},message={send_to_sim=function(id,kind,content)
 if kind=='SceneZOI.API.Event'then got[id.Value]=(got[id.Value]or 0)+1
 elseif kind=='SceneZOI.API.Response'then responses[#responses+1]=J.decode(content)end
end}}
local API=require('SceneZOI.AddonAPI');API.boot()
local serial=0
local function request(from,addon,op,args)
 serial=serial+1
 API.receive(from,J.encode({api_version=1,addon_id=addon,client_id='client',request_id='r'..serial,operation=op,arguments=args or {}}))
 return responses[#responses]
end
local r=request(legacy,'legacy.addon','subscribe',{events={'*'}});assert(r.ok and r.result.scope=='focused','Existing unscoped subscriptions default to the focused scene')
request(focused,'focused.addon','subscribe',{scope='focused'});request(owned,'owned.addon','subscribe',{scope='owned'})
request(all,'all.addon','subscribe',{scope='all'});request(owner,'owner.addon','subscribe',{scope='owned'})
r=request(legacy,'bad.addon','subscribe',{scope='everything'});assert(not r.ok and r.code=='invalid_request')
local E=require('SceneZOI.Events')
local function emit(event)got={};E.emit('session_started',event);E.flush();return got end
local g=emit({id='a',focused=true,addon_id='other.addon',addon_client_id='client',phase='playing'})
assert(g[1]==1 and g[2]==1 and g[4]==1 and not g[3] and not g[5],'Focused events reach focused and all subscribers')
g=emit({id='b',focused=false,addon_id='other.addon',addon_client_id='client',phase='playing'})
assert(not g[1] and not g[2] and g[4]==1 and not g[3],'A scene out of focus reaches only all-scene subscribers')
g=emit({id='c',focused=false,addon_id='owner.addon',addon_client_id='client',phase='playing'})
assert(g[5]==1 and g[4]==1 and not g[1] and not g[3],'An add-on always hears its own scenes, independently of focus')
g=emit({id='d',addon_id='legacy.addon',addon_client_id='client',phase='playing'});assert(g[1]==1)
r=request(legacy,'legacy.addon','list_sessions');assert(r.ok and #r.result.sessions==2 and r.result.sessions[2].id=='scene.2')
print('Event scopes passed: focused default for existing subscribers, owned and all views, owners independent of focus and session listing.')

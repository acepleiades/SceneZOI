package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation');local Meta=require('SceneZOI.Metadata')
local function read(p)local f=assert(io.open(p,'rb'));local v=J.decode(f:read('*a'));f:close();return v end
local source={by_kind={}}
for kind,file in pairs({tag_dictionary='tags',action_dictionary='actions'})do source.by_kind[kind]={{owner='scenezoi',source=file,data=read('packs/scenezoi/metadata/'..file..'.json')}}end
local registry=Meta.compile(source)
local neutral=Meta.resolve_scene(registry,{id='test.hub',label='Hub',kind='loop',starting_hub=true,navigation={{id='next',target='test.explicit'}},participants={first={body='male'},second={body='female'}},actions={{type='hug',actor='first',target='second'}}})
local explicit=V.copy(neutral);explicit.id='test.explicit';explicit.actions={{type='vaginal_sex',actor='first',target='second',performer='second'}};explicit.content_rating='EXPLICIT'
local data={metadata=registry,nodes={[neutral.id]=neutral,[explicit.id]=explicit}}
local a={id='1',body='male',GetEntityId=function()return {Value=1}end};local b={id='2',body='female',GetEntityId=function()return {Value=2}end}
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=1}end}end}}
local current,stops,navigations=nil,0,0;local cfg,responses,events={},{},{};local API
package.loaded['SceneZOI.Traits']={capture=function(actor)return {id=actor.id,body=actor.body}end,matches=function(requirement,person)return requirement.body==person.body end}
package.loaded['SceneZOI.DataFiles']={refresh=function()end}
package.loaded['SceneZOI.Catalog']={refresh=function()return data end,get_snapshot=function()return data end,get=function(id)return assert(data.nodes[id])end,public_node=function(n)return V.copy(n)end}
package.loaded['SceneZOI.Runtime']={actors={['1']=a,['2']=b},snapshot=function()return current end,is_addon_owner=function(addon,client,id)return current and current.id==id and current.addon_id==addon and current.client_id==client end,api_session=function()return current end,api_session=function()return current end,stop=function()stops=stops+1;current=nil;require('SceneZOI.Sessions').release('session.1')end,navigate_to=function(_,id)navigations=navigations+1;return {scene_id=id}end}
inzoi={cli={execute=function(command)
 if command=='entity.get_possessed'then return true,'','{"entity_id":1}'end
 local key=command:match(' key=([%w_]+)')
 if command:find('cfg_save',1,true)then cfg[key]=command:match(' value=(.*)');return true end
 return true,'',cfg[key]
end},message={send_to_sim=function(id,kind,content)
 if kind=='SceneZOI.API.Response'then responses[#responses+1]=J.decode(content)
 elseif kind=='SceneZOI.API.Event'then events[#events+1]=J.decode(content)
 elseif kind=='SceneZOI.API.Depart'then API.departure_reply(id.Value==1 and a or b,content..'|ok')end
end}}
API=require('SceneZOI.AddonAPI');API.boot()
local function request(id,op,args,addon,client,version)
 local raw=J.encode({api_version=version or 1,addon_id=addon or 'test.addon',client_id=client or 'test.client',request_id=id,operation=op,arguments=args or {}})
 API.receive(a,raw);return responses[#responses],raw
end
local r,raw=request('version','get_version');assert(r.ok and r.result.maximum_sessions==1)
local count=#responses;API.receive(a,raw);assert(#responses==count+1 and responses[#responses].result.instance_id==r.result.instance_id)
r=request('version','get_session');assert(not r.ok and r.code=='request_id_reused')
r=request('badversion','get_version',{},nil,nil,2);assert(not r.ok and r.code=='unsupported_api_version')
r=request('badop','not_an_operation');assert(not r.ok and r.code=='unknown_operation')
r=request('query','find_scenes',{participants={'1','2'},search={allowed_content_ratings={'GENERAL'},required_actions={'embrace'}}});assert(r.ok and r.result.count==1 and r.result.scenes[1].bindings.first=='1')
r=request('unknown','find_scenes',{search={required_tags={'not_registered'}}});assert(not r.ok)
r=request('start','start_at_hub',{initiator='1',participants={'1','2'},session_restrictions={allowed_content_ratings={'GENERAL'}},context={purpose='affection'}});assert(r.ok and r.result.accepted and API.has_pending())
request('busy','start_at_hub',{initiator='1',participants={'1','2'}});assert(not responses[#responses].ok and responses[#responses].code=='session_already_running')
API.tick(.5);API.tick(.5)
local pending=J.decode(assert(require('SceneZOI.Protocol').decode(cfg.api_start)))
local fields={'ui','1','start','1','test.hub','first:1+second:2','none',pending.token}
local row=API.context(pending.token,fields);assert(row.context.purpose=='affection'and row.restrictions.allowed_content_ratings[1]=='GENERAL')
local changed=V.copy(fields);changed[6]='first:2+second:1';assert(not pcall(API.context,pending.token,changed))
current={id='session.1',token='session.1',addon_id='test.addon',client_id='test.client'};API.created(row,current);assert(not API.has_pending())
request('foreign','stop_session',{session_id='session.1'},'other.addon');assert(not responses[#responses].ok and stops==0)
request('nav','navigate_to_scene',{session_id='session.1',scene_id='test.hub'});assert(responses[#responses].ok and navigations==1)
request('start','get_version',{},nil,'other.client') -- Same request ID in another client is independent.
local E=require('SceneZOI.Events');E.emit('session_started',{id='session.1',node_id='test.hub',request_id='start',addon_id='test.addon',phase='playing',context={empty=J.array({}),nullable=J.null}},nil);E.flush()
assert(#events==1 and events[1].event.session_id=='session.1'and events[1].client_id=='test.client')
assert(events[1].event.context.nullable==J.null and J.encode(events[1].event.context.empty)=='[]','Copied events must preserve JSON nulls and empty arrays')
request('status','get_request_status',{request_id='start'});assert(responses[#responses].result.phase=='playing')
request('status','get_request_status',{request_id='start'},nil,'other.client');assert(responses[#responses].result.phase=='completed','A foreign client must not inherit session progress')
request('stop','stop_session',{session_id='session.1'});assert(responses[#responses].ok and stops==1)
r=request('none','start_scene',{initiator='1',participants={'1','2'},scene_id='test.explicit',session_restrictions={allowed_content_ratings={'GENERAL'}}});assert(not r.ok and r.code=='no_matching_scenes'and not API.has_pending())
request('cancelled','start_at_hub',{initiator='1',participants={'1','2'}});assert(API.has_pending())
request('cancel','cancel_start',{start_request_id='cancelled'});assert(not API.has_pending()and events[#events].event.name=='session_start_failed')
request('timeout','start_at_hub',{initiator='1',participants={'1','2'}});API.tick(16);assert(not API.has_pending())
print('Public API passed: versioning, replay/conflict handling, shared matching, real startup context, independent group acknowledgements, ownership, copied events, status, no-match, cancellation and timeout.')

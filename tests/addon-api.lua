package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation');local Meta=require('SceneZOI.Metadata')
local task_registry=dofile('tests/support/task-registry.lua')
local function read(p)local f=assert(io.open(p,'rb'));local v=J.decode(f:read('*a'));f:close();return v end
local source={by_kind={}}
for kind,file in pairs({tag_dictionary='tags',action_dictionary='actions'})do source.by_kind[kind]={{owner='scenezoi',source=file,data=read('packs/scenezoi/metadata/'..file..'.json')}}end
local registry=Meta.compile(source)
local neutral=Meta.resolve_scene(registry,{id='test.hub',label='Hub',kind='loop',starting_hub=true,navigation={{id='next',target='test.explicit'}},participants={first={body='male'},second={body='female'}},actions={{type='hug',actor='first',target='second'}}})
local explicit=V.copy(neutral);explicit.id='test.explicit';explicit.actions={{type='vaginal_sex',actor='first',target='second',performer='second'}};explicit.content_rating='EXPLICIT'
local data={metadata=registry,nodes={[neutral.id]=neutral,[explicit.id]=explicit},tasks=task_registry({})}
local a={id='1',body='male',GetEntityId=function()return {Value=1}end};local b={id='2',body='female',GetEntityId=function()return {Value=2}end}
UE={UGameplayStatics={GetPlayerController=function()return {GetCharacterEntityId=function()return {Value=1}end}end}}
local current,stops,navigations=nil,0,0;local stopped;local cfg,responses,events={},{},{};local API
package.loaded['SceneZOI.Traits']={capture=function(actor)return {id=actor.id,body=actor.body}end,matches=function(requirement,person)return requirement.body==person.body end}
package.loaded['SceneZOI.DataFiles']={refresh=function()end}
package.loaded['SceneZOI.Catalog']={refresh=function()return data end,get_snapshot=function()return data end,get=function(id)return assert(data.nodes[id])end,public_node=function(n)return V.copy(n)end}
package.loaded['SceneZOI.Runtime']={actors={['1']=a,['2']=b},snapshot=function()return current end,is_addon_owner=function(addon,client,id)return current and current.id==id and current.addon_id==addon and current.client_id==client end,api_session=function()return current end,api_session=function()return current end,stop=function()stopped=current;stops=stops+1;current=nil;require('SceneZOI.Sessions').release('session.1')end,navigate_to=function(_,id)navigations=navigations+1;return {scene_id=id}end}
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
local r,raw=request('version','get_version');assert(r.ok and r.result.maximum_sessions==1 and r.result.features.stop_session_display_reason==1)
local count=#responses;API.receive(a,raw);assert(#responses==count+1 and responses[#responses].result.instance_id==r.result.instance_id)
r=request('version','get_session');assert(not r.ok and r.code=='request_id_reused')
r=request('badversion','get_version',{},nil,nil,2);assert(not r.ok and r.code=='unsupported_api_version')
r=request('badop','not_an_operation');assert(not r.ok and r.code=='unknown_operation')
r=request('action_definitions','get_definitions')
assert(r.ok and r.result.actions.handjob.sexual_activity=='non_penetrative')
assert(r.result.actions.fellatio.sexual_activity=='penetrative_non_coital')
assert(r.result.actions.vaginal_sex.sexual_activity=='coital' and r.result.actions.vaginal_sex.content_rating=='EXPLICIT')
assert(r.result.actions.holding_penis_at_base.sexual_activity==nil)
r=request('query','find_scenes',{participants={'1','2'},search={allowed_content_ratings={'GENERAL'},required_actions={'embrace'}}});assert(r.ok and r.result.count==1 and r.result.scenes[1].bindings.first=='1')
r=request('unknown','find_scenes',{search={required_tags={'not_registered'}}});assert(not r.ok)

local finished
package.loaded['SceneZOIStarter.Entry']={open_partner=function(_,callback) finished=callback end}
require('SceneZOI.Runtime').is_active=function() return false end
local picker_events=#events
r=request('picker_default','open_partner_picker',{});assert(r.ok and r.result.opened)
finished('selected','2')
assert(events[#events].event.code=='selected' and events[#events].event.partner_id=='2')
r=request('picker_allowed','open_partner_picker',{candidate_ids={'2'}});assert(r.ok and r.result.opened)
finished('selected','2')
assert(events[#events].event.code=='selected' and events[#events].event.partner_id=='2')
r=request('picker_excluded','open_partner_picker',{candidate_ids={'3'}});assert(r.ok and r.result.opened)
finished('selected','2')
assert(events[#events].event.code=='partner_ineligible' and not events[#events].event.partner_id)
r=request('picker_malformed','open_partner_picker',{candidate_ids={'broken'}});assert(not r.ok and #events==picker_events+3)
events={}
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
request('stop-invalid','stop_session',{session_id='session.1',display_reason=''})
assert(not responses[#responses].ok and stops==0 and current.stop_origin==nil)
request('stop','stop_session',{session_id='session.1',display_reason='The visitors left.'})
assert(responses[#responses].ok and stops==1)
assert(stopped.stop_origin.reason=='creator_stop' and stopped.stop_display_reason=='The visitors left.')
r=request('none','start_scene',{initiator='1',participants={'1','2'},scene_id='test.explicit',session_restrictions={allowed_content_ratings={'GENERAL'}}});assert(not r.ok and r.code=='no_matching_scenes'and not API.has_pending())
request('cancelled','start_at_hub',{initiator='1',participants={'1','2'}});assert(API.has_pending())
request('cancel','cancel_start',{start_request_id='cancelled'});assert(not API.has_pending()and events[#events].event.name=='session_start_failed')
request('timeout','start_at_hub',{initiator='1',participants={'1','2'}});API.tick(16);assert(not API.has_pending())
-- One participant: a solo scene starts through the API like the menu's Solo start.
local solo=Meta.resolve_scene(registry,{id='test.solo',label='Solo',kind='loop',starting_hub=true,participants={only={body='male'}},actions={{type='penile_masturbation',actor='only',target='only'}}})
solo.content_rating='EXPLICIT';data.nodes[solo.id]=solo
r=request('solofind','find_scenes',{participants={'1'},search={allowed_content_ratings={'EXPLICIT'},any_actions={'penile_masturbation'}}});assert(r.ok and r.result.count==1 and r.result.scenes[1].bindings.only=='1')
r=request('solo','start_random_scene',{initiator='1',participants={'1'},search={allowed_content_ratings={'EXPLICIT'},any_actions={'penile_masturbation'}}});assert(r.ok and r.result.accepted and r.result.scene_id=='test.solo'and API.has_pending())
request('solocancel','cancel_start',{start_request_id='solo'});assert(not API.has_pending())
r=request('nobody','start_random_scene',{initiator='1',participants={}});assert(not r.ok)
print('Public API passed: versioning, replay/conflict handling, shared matching, real startup context, independent group acknowledgements, ownership, copied events, status, no-match, cancellation and timeout.')

local sofa=V.copy(neutral);sofa.id='test.sofa';sofa.furniture={kind='sofa.pair',surface_height_cm=44};data.nodes[sofa.id]=sofa
local available_pair={id='right_pair',spots={'c','d'}}
local furniture_profile={kind='sofa.pair'};local prepared_pair
package.loaded['SceneZOI.Furniture']={available=function(id,pair)
 if id=='50'and(not pair or pair==available_pair.id)then return furniture_profile,available_pair end
end,prepare=function(id,node,pair)assert(id=='50'and node==sofa);prepared_pair=pair;return {}end}
r=request('sofa_version','get_version');assert(r.result.features.furniture_pairs==1)
r=request('sofa_preflight','validate_start',{initiator='1',participants={'1','2'},furniture_id='50',furniture_pair_id='right_pair',scene_id=sofa.id,start_mode='start_scene'})
assert(r.ok and r.result.valid and r.result.furniture_pair_id=='right_pair'and prepared_pair=='right_pair'and not API.has_pending())
r=request('sofa_start','start_scene',{initiator='1',participants={'1','2'},furniture_id='50',furniture_pair_id='right_pair',scene_id=sofa.id})
assert(r.ok and r.result.accepted and r.result.furniture_pair_id=='right_pair')
API.tick(.5);API.tick(.5);local start=J.decode(require('SceneZOI.Protocol').decode(cfg.api_start))
local sofa_fields={'ui','2','start','1',sofa.id,'first:1+second:2','50',start.token,'right_pair'}
assert(API.context(start.token,sofa_fields).entry.furniture_pair_id=='right_pair')
sofa_fields[9]='left_pair';assert(not pcall(API.context,start.token,sofa_fields),'UI cannot substitute another sofa pair')
request('sofa_cancel','cancel_start',{start_request_id='sofa_start'})
r=request('sofa_badpair','start_scene',{initiator='1',participants={'1','2'},furniture_id='50',furniture_pair_id='missing_pair',scene_id=sofa.id});assert(not r.ok and r.code=='furniture_unavailable')
print('Sofa start API passed: capability discovery, pair preflight, immutable UI handoff, cancellation and unavailable-pair rejection.')

package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation');local Control=require('SceneZOI.AddonControl');local Tasks=require('SceneZOI.Tasks')
local p={id='1',body='male',role='giver',outfit_items={shirt={enabled=true}}}
local s={token='s.1',participants={p,{id='2',body='male',role='receiver'}},node={id='n.1',kind='loop',participants={giver={},receiver={}}},clock={session_elapsed=0},revision=1}
Control.init(s);s.tasks=Tasks.new({energy={maximum=10,initial=0,label='Energy'}},s.participants)
local ended,speed,events=false,nil,{}
local Runtime={api_session=function(id)assert(id==s.token,'session_not_found');return s end,
 is_addon_owner=function(addon,client)return addon=='owner'and client=='a'end,
 release_integration=function(key)Control.release(s,key)end,
 stop=function(code)ended=code;s.stopping=true end,
 api_speed=function(_,index)assert(index>=1 and index<=4 and index%1==0,'Invalid playback speed');speed=index end,
 api_navigation=function()return {navigation=J.array({}),locked=false}end}
package.loaded['SceneZOI.Runtime']=Runtime
package.loaded['SceneZOI.Catalog']={}
package.loaded['SceneZOI.ExpressionLibrary']={get=function()return {sets={['test male']={body='male',contexts={idle={}}}}}end}
local Services=require('SceneZOI.AddonServices');local actor={GetEntityId=function()return {Value=1}end}
local function call(op,args,addon)
 local handled,result=Services.execute(actor,{operation=op,arguments=args or {},addon_id=addon or 'observer',client_id='a'})
 assert(handled);return result
end
assert(not pcall(call,'set_task_progress',{session_id=s.token,participant_id='1',task_id='energy',value=5}))
call('register_integration',{capabilities={'tasks','speed','presentation','outfits','attachments','interrupt'}})
call('set_task_progress',{session_id=s.token,participant_id='1',task_id='energy',value=7});assert(s.tasks.participants['1'].energy.value==7)
call('modify_task_progress',{session_id=s.token,participant_id='1',task_id='energy',amount=8});assert(s.tasks.participants['1'].energy.value==10)
local state=call('get_task_state',{session_id=s.token});assert(state.participants[1].percent==100 and state.definitions.energy.maximum==10)
assert(not pcall(call,'set_task_progress',{session_id=s.token,participant_id='1',task_id='energy',value=11}));assert(s.tasks.participants['1'].energy.value==10)
assert(not pcall(call,'set_task_controls',{session_id=s.token,participant_id='1',task_id='energy',completion_hold=true,rate_multiplier=-1}))
call('set_task_controls',{session_id=s.token,participant_id='1',task_id='energy',completion_hold=true,rate_multiplier=0})
call('set_speed',{session_id=s.token,speed_index=4});assert(speed==4)
call('set_speed_multiplier',{session_id=s.token,multiplier=.5});assert(Control.speed(s)==.5)
call('set_voice_mute',{session_id=s.token,participant_id='1',muted=true});assert(Control.muted(s,'1'))
call('set_expression_override',{session_id=s.token,participant_id='1',expression_set='Test Male',context='Idle'});assert(Control.expression(s,'1').expression_set=='test male')
assert(not pcall(call,'set_expression_override',{session_id=s.token,participant_id='2',expression_set='Test Male',context='missing'}))
package.loaded['SceneZOI.FacialPoseLibrary']={get=function()return {poses={['example.brow']={poses={male={}}}}}end}
assert(call('get_facial_poses').poses['example.brow'])
call('set_expression_override',{session_id=s.token,participant_id='1',facial_pose='example.brow'})
assert(Control.expression(s,'1').facial_pose=='example.brow'and not Control.expression(s,'1').context)
s.participants[2].body='female'
assert(not pcall(call,'set_expression_override',{session_id=s.token,participant_id='2',facial_pose='example.brow'}))
s.participants[2].body='male'
assert(not pcall(call,'set_expression_override',{session_id=s.token,participant_id='1',facial_pose='example.missing'}))
assert(Control.expression(s,'1').facial_pose=='example.brow','Invalid pose mutation erased existing override')
call('clear_expression_override',{session_id=s.token,participant_id='1'});assert(Control.expression(s,'1')==nil)
call('set_outfit_item',{session_id=s.token,participant_id='1',item_id='shirt',enabled=false})
assert(call('get_outfit_state',{session_id=s.token}).participants[1].items.shirt.enabled==true,'Outfit queued through readiness, not mutated synchronously')
assert(not pcall(call,'register_integration',{capabilities={'unknown'}}));assert(Control.muted(s,'1'),'Invalid registration must not clear existing leases')
call('release_overrides',{session_id=s.token});assert(Control.speed(s)==1 and not Control.muted(s,'1'))
call('request_stop',{session_id=s.token,reason='crime_witness'});assert(ended=='addon_requested'and s.stop_origin.addon_id=='observer'and s.stop_origin.reason=='crime_witness')
assert(not pcall(call,'set_voice_mute',{session_id=s.token,participant_id='1',muted=true}),'Writes fail during cleanup')
assert(call('get_session_result',{session_id='unknown'}).result==J.null)
print('Public services: noncreator capabilities, invalid-write isolation, normalized tasks, actual set/modify, held completion, speed, voice/expression/outfit leases, observer stop and cleanup write refusal passed.')

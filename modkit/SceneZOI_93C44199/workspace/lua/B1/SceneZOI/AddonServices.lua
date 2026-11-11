-- Additional public operations; all access to live state stays behind Runtime.
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local Control=require('SceneZOI.AddonControl')
local Effects=require('SceneZOI.AddonEffects')
local M={}
local function runtime()return require('SceneZOI.Runtime')end
local operations={register_integration=true,renew_integration=true,release_integration=true,request_stop=true,
 get_session_result=true,get_navigation=true,get_task_state=true,set_speed=true,set_speed_multiplier=true,
 modify_task_progress=true,set_task_progress=true,set_task_controls=true,set_voice_mute=true,
 set_expression_override=true,clear_expression_override=true,set_outfit_item=true,get_outfit_state=true,
 add_attachment=true,remove_attachment=true,get_overrides=true,release_overrides=true,get_expression_sets=true,get_facial_poses=true}
function M.execute(actor,req)
 local op,args=req.operation,req.arguments
 if not operations[op]then return false end
 local key=Control.key(req.addon_id,req.client_id,tostring(actor:GetEntityId().Value))
 if op=='register_integration'then V.fields(args,{'capabilities'},{'capabilities'});Control.validate_capabilities(args.capabilities);runtime().release_integration(key);return true,Control.register(key,args.capabilities)end
 if op=='renew_integration'then V.fields(args,{});return true,Control.renew(key)end
 if op=='release_integration'then
  V.fields(args,{});runtime().release_integration(key);return true,{released=true}
 end
 if op=='get_session_result'then V.fields(args,{'session_id'},{'session_id'});V.name(args.session_id);return true,{result=Control.result(args.session_id)or J.null}end
 if op=='get_expression_sets'then V.fields(args,{});return true,{sets=V.copy(require('SceneZOI.ExpressionLibrary').get().sets)}end
 if op=='get_facial_poses'then V.fields(args,{});return true,{poses=V.copy(require('SceneZOI.FacialPoseLibrary').get().poses)}end
 local s=runtime().api_session(args.session_id)
 local function authorize(cap)assert(not s.stopping,'session_not_ready');Control.authorize(s,key,cap,runtime().is_addon_owner(req.addon_id,req.client_id,s.token))end
 local function fields(names,required)
  local all={'session_id'};for _,n in ipairs(names)do all[#all+1]=n end
  local need={'session_id'};for _,n in ipairs(required or {})do need[#need+1]=n end;V.fields(args,all,need)
 end
 local function participant()
  assert(type(args.participant_id)=='string','participant_not_found')
  for _,p in ipairs(s.participants)do if p.id==args.participant_id then return p end end;error('participant_not_found')
 end
 local function ready()assert(not s.preparing and not s.stopping,'session_not_ready')end
 if op=='request_stop'then
  fields({'reason'},{'reason'});authorize('interrupt');V.id(args.reason)
  s.stop_origin={addon_id=req.addon_id,client_id=req.client_id,reason=args.reason};runtime().stop('addon_requested',s.token);return true,{accepted=true}
 end
 if op=='get_navigation'then fields({});return true,runtime().api_navigation(s)end
 if op=='get_task_state'then fields({});return true,{definitions=V.copy(s.tasks.definitions),participants=require('SceneZOI.Tasks').inspect(s.tasks,s)}end
 if op=='get_overrides'then fields({});return true,Effects.snapshot(s,key)end
 if op=='get_outfit_state'then
  fields({});local people=J.array({})
  for _,p in ipairs(s.participants)do people[#people+1]={participant_id=p.id,items=V.copy(p.outfit_items or {})}end
  return true,{participants=people,phase=s.preparing and 'preparing'or 'ready'}
 end
 if op=='release_overrides'then
  fields({});Effects.release(s,key);s.addon_controls[key]=nil;return true,{released=true}
 end
 if op=='set_speed'then fields({'speed_index'},{'speed_index'});authorize('speed');ready();runtime().api_speed(s,args.speed_index);return true,{speed_index=s.clock.index}end
 if op=='set_speed_multiplier'then fields({'multiplier'},{'multiplier'});authorize('speed');ready();V.number(args.multiplier,.1,2);Control.layer(s,key).speed_multiplier=args.multiplier;return true,{multiplier=args.multiplier}end
 if op=='modify_task_progress'or op=='set_task_progress'or op=='set_task_controls'then
  fields({'participant_id','task_id','amount','value','rate_multiplier','completion_hold'},{'participant_id','task_id'});authorize('tasks');ready()
  local p=participant();V.id(args.task_id);local d=assert(s.tasks.definitions[args.task_id],'task_not_found')
  local entry=s.tasks.participants[p.id][args.task_id]
  if op=='set_task_controls'then
   assert(args.amount==nil and args.value==nil and(args.rate_multiplier~=nil or args.completion_hold~=nil),'Invalid task controls')
   if args.rate_multiplier~=nil then V.number(args.rate_multiplier,0,10)end
   if args.completion_hold~=nil then V.boolean(args.completion_hold)end
   local layer=Control.layer(s,key);local k=p.id..'|'..args.task_id;layer.tasks[k]=layer.tasks[k]or {}
   for _,n in ipairs({'rate_multiplier','completion_hold'})do if args[n]~=nil then layer.tasks[k][n]=args[n]end end
  else
   assert(args.rate_multiplier==nil and args.completion_hold==nil,'Invalid task progress fields')
   if op=='modify_task_progress'then assert(args.value==nil,'Use amount for modify');V.number(args.amount,-d.maximum,d.maximum);entry.value=math.max(0,math.min(d.maximum,entry.value+args.amount))
   else assert(args.amount==nil,'Use value for set');V.number(args.value,0,d.maximum);entry.value=args.value end
  end
  return true,{participant_id=p.id,task_id=args.task_id,value=entry.value,maximum=d.maximum,percent=100*entry.value/d.maximum,completions=entry.completions,completion_deferred_until_playing_tick=true}
 end
 if op=='set_voice_mute'then fields({'participant_id','muted'},{'participant_id','muted'});authorize('presentation');participant();V.boolean(args.muted);Control.layer(s,key).voice_mutes[args.participant_id]=args.muted or nil;return true,{muted=Control.muted(s,args.participant_id)}end
 if op=='set_expression_override'or op=='clear_expression_override'then
  fields({'participant_id','expression_set','context','facial_pose'},{'participant_id'});authorize('presentation');local p=participant()
  if op=='clear_expression_override'then
   assert(args.expression_set==nil and args.context==nil and args.facial_pose==nil,'Invalid clear fields')
   Control.layer(s,key).expressions[p.id]=nil
  else
   assert(args.context~=nil or args.facial_pose~=nil,'Empty expression override')
   assert((args.expression_set~=nil)==(args.context~=nil),'Expression set and context must be supplied together')
   local expression_set,context
   if args.context~=nil then
    expression_set=require('SceneZOI.ExpressionKeys').required(args.expression_set);context=require('SceneZOI.ExpressionKeys').required(args.context)
    local set=assert(require('SceneZOI.ExpressionLibrary').get().sets[expression_set],'expression_set_not_found')
    assert(set.body==(p.expression_body or p.body),'incompatible_expression_set');assert(set.contexts[context],'expression_context_not_found')
   end
   if args.facial_pose~=nil then
    V.id(args.facial_pose);local pose=assert(require('SceneZOI.FacialPoseLibrary').get().poses[args.facial_pose],'facial_pose_not_found')
    assert(pose.poses[p.expression_body or p.body],'incompatible_facial_pose')
   end
   local layer=Control.layer(s,key)
   layer.expressions[p.id]={expression_set=expression_set,context=context,facial_pose=args.facial_pose,serial=Control.touch(layer)}
  end
  local layer=Control.layer(s,key)
  Control.touch(layer);return true,{accepted=true,temporary=true}
 end
 if op=='set_outfit_item'then fields({'participant_id','item_id','enabled'},{'participant_id','item_id','enabled'});authorize('outfits');ready();V.name(args.item_id);return true,Effects.outfit(s,key,args.participant_id,args.item_id,args.enabled)end
 if op=='add_attachment'then fields({'participant_id','effect_id','attachment'},{'participant_id','effect_id','attachment'});authorize('attachments');ready();Control.layer(s,key);return true,Effects.attach(s,key,args)end
 if op=='remove_attachment'then fields({'effect_id'},{'effect_id'});authorize('attachments');Effects.release(s,key,args.effect_id);return true,{accepted=true}end
 error('unknown_operation')
end
return M

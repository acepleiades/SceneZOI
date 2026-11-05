local Library=require('SceneZOI.ExpressionLibrary')
local Personality=require('SceneZOI.Personality')
local Keys=require('SceneZOI.ExpressionKeys')
local Native=require('SceneZOI.ExpressionNative')
local Pose=require('SceneZOI.FacialPose')
local Control=require('SceneZOI.AddonControl')
local Config=require('SceneZOI.Config')
local M={}
local function load(spec)
 local options,errors={},{}
 for _,item in ipairs(spec.options)do
  local ok,option=pcall(function()
   local asset=UE.UObject.Load(item.animation)
   assert(asset and asset:IsA(UE.UAnimSequence:StaticClass()),'Expected a facial animation sequence')
   local duration=asset:GetPlayLength();assert(type(duration)=='number'and duration==duration and duration>0 and duration<math.huge,'Invalid expression duration')
   return {asset=asset,label=item.label,weight=item.weight,sample=math.min(item.sample or 0,math.max(0,duration-.0001)),duration=duration,animated=item.animated}
  end)
  if ok then options[#options+1]=option else errors[#errors+1]=item.label..':'..tostring(option)end
 end
 return {options=options,errors=errors,hold=spec.hold,transition=spec.transition}
end
local function warn(owner,message)
 owner.person.expression_error=message;owner.load_error=message
 if owner.warning~=message then owner.warning=message;print('[SceneZOI] Expression warning for '..owner.id..': '..message)end
end
local function suspend(owner,message,now)
 owner.face_active=false
 local ok,err=pcall(Native.stop,owner)
 warn(owner,message..(not ok and(' Cleanup will retry: '..tostring(err))or ''))
 owner.next=now+5
end
function M.prepare(context,session)
 context.session,context.owners=session,context.owners or {};session.expressions=context;local ready=true
 local data=Library.get()
 for _,person in ipairs(session.participants)do
  local owner=context.owners[person.id]
  if not owner then owner={id=person.id,actor=person.actor,person=person,loaded={}};context.owners[person.id]=owner end
  local body=Native.body(person)
  if not person.expression_profile_loaded or person.expression_body~=body then Personality.load(person,body)end
  local spec=context.node.expressions and context.node.expressions[person.role]
  local name=spec and Keys.normalize(spec.context)
  local set=person.expression_set and data.sets[person.expression_set]
  local group=set and name and set.contexts[name]
  if group then
   if not Native.bind(owner)then return false end
   local key=person.expression_set..'\0'..name
   if not owner.loaded[key]then owner.loaded[key]=load(group)end
  end
  if spec and spec.facial_pose and Pose.prepare(owner,spec.facial_pose)==false then ready=false end
 end
 return ready
end
function M.ready(context)return context.session~=nil end
local function choose(owner,spec,now,speed)
 local id=spec.expression_set or owner.person.expression_set;local context=Keys.normalize(spec.context)
 owner.selected_set=id;owner.selected_context=context
 local set=id and Library.get().sets[id]
 if not set then suspend(owner,'No expression sets installed for the '..tostring(owner.person.expression_body)..' body.',now);return end
 local source=context and set.contexts[context]
 if not source then suspend(owner,'Expression set "'..set.label..'" has no context "'..tostring(spec.context)..'".',now);return end
 local key=id..'\0'..context;local group=owner.loaded[key]
 if not group or #group.options==0 then group=load(source);owner.loaded[key]=group end
 if #group.options==0 then suspend(owner,'Native expression assets could not be loaded.',now);return end
 local options,total={},0
 for _,option in ipairs(group.options)do if #group.options==1 or option~=owner.last_option then options[#options+1]=option;total=total+option.weight end end
 local value=math.random()*total;local selected=options[#options]
 for _,option in ipairs(options)do value=value-option.weight;if value<=0 then selected=option;break end end
 if Native.play(owner,selected,group.transition/speed,now)==false then owner.next=now;return end
 owner.face_active=true;owner.load_error=nil;owner.warning=nil;owner.person.expression_error=nil;owner.last_option=selected
 owner.next=now+group.hold[1]+(group.hold[2]-group.hold[1])*math.random()
end
function M.enter(context)
 local session=context.session
 if context.active and context.entered_revision==session.revision then M.sample(context);return end
 context.active=true;context.entered_revision=session.revision
 for _,person in ipairs(session.participants)do
  local owner=context.owners[person.id];owner.spec=context.node.expressions and context.node.expressions[person.role]
  owner.last_option=nil;owner.next=0;owner.warning=nil
  if not owner.spec then Native.stop(owner);owner.face_active=false;Pose.restore(owner)end
 end
 M.sample(context)
end
function M.sample(context)
 if not context.active then return end
 local now=context.session.clock.session_elapsed
 for _,owner in pairs(context.owners)do
  local spec=Control.expression(context.session,owner.id)or owner.spec
  if spec then
   if spec.context then
    if now>=(owner.next or 0)or owner.selected_set~=(spec.expression_set or owner.person.expression_set) or owner.selected_context~=Keys.normalize(spec.context)then choose(owner,spec,now,Config.playback_speeds[context.session.clock.index or 2])end
    if owner.face_active then Native.hold(owner,now)end
   elseif owner.face_active then Native.stop(owner);owner.face_active=false;owner.selected_context=nil end
   Pose.sample(owner,spec.facial_pose,now)
  else
   if owner.face_active then Native.stop(owner);owner.face_active=false;owner.selected_context=nil end
   Pose.restore(owner)
  end
 end
end
function M.guard(context)
 for _,owner in pairs(context.owners or {})do if owner.face_active then Native.hold(owner)end;Pose.guard(owner)end
end
function M.leave_node(context)context.active=false end
function M.restore(context)
 context.active=false;local errors={}
 for _,owner in pairs(context.owners or {})do for _,fn in ipairs({Native.stop,Pose.restore})do local ok,err=pcall(fn,owner);if not ok then errors[#errors+1]=tostring(err)end end end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.status(context)
 local rows={}
 for id,owner in pairs(context.owners or {})do
  rows[#rows+1]=id..'='..(owner.person.expression_set or 'none')..':'..(owner.clip and owner.clip.label or 'none')
  rows[#rows+1]=id..'_face_replays='..tostring(owner.replays or 0)
  if owner.load_error then rows[#rows+1]=id..'_warning='..owner.load_error end
  if Pose.status then rows[#rows+1]=id..'_facial_pose='..Pose.status(owner)end
 end
 table.sort(rows);return 'expressions='..table.concat(rows,'+')
end
return M

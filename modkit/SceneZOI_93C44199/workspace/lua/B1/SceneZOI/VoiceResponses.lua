-- Data-defined interruption of participant voice channels; no task/content semantics.
local Native=require('SceneZOI.SoundNative')
local Voices=require('SceneZOI.Voices')
local Keys=require('SceneZOI.ExpressionKeys')
local M={}
local function warning(ctx,err)
 local message=tostring(err);if message~=ctx.error then print('[SceneZOI] Voice response: '..message);ctx.error=message end
end
function M.prepare(ctx,session)
 ctx.session=session;ctx.channels=ctx.channels or {};ctx.seen=ctx.seen or {};ctx.plays=ctx.plays or 0
 session.voice_responses=ctx;ctx.last_time=session.clock and session.clock.game_elapsed or 0;return true
end
function M.ready(ctx)return ctx.session~=nil end
local function selected(ctx,person,context)
 return Voices.selected(ctx.session.voices,person,context)
end
local function start(ctx,channel,item)
 local set=selected(ctx,channel.person,item.context)
 if not set or set.id~=item.set.id then return false end
 channel.item=item;channel.stage='fading';channel.fade=0;channel.fade_base=1;channel.fade_alpha=1;channel.voice={}
 return true
end
function M.trigger(ctx,payloads)
 if not ctx then return end
 local s=ctx.session;if s.stopping or s.ended or s.preparing then return end
 local requests={}
 for _,p in ipairs(payloads)do
  local person=(s.bindings or {})[p.participant_role]
  if person and person.id==p.participant_id and p.task.completed then
   local rules=(((s.node.task_completion_voices or {})[p.participant_role]or {})[p.task.id])or {}
   for i,rule in ipairs(rules)do
    local id=p.participant_id..'|'..p.task.id..'|'..s.revision..'|'..i
    if (ctx.seen[id]or 0)<p.task.completion_index then
     ctx.seen[id]=p.task.completion_index
     local speaker=s.bindings[rule.participant];local context=Keys.required(rule.context)
     local set=selected(ctx,speaker,context)
     local group=set and(set.responses or {})[Keys.required(rule.response)]
     if group and #group.clips>0 and not require('SceneZOI.AddonControl').muted(s,speaker.id)then
      local ok,clip=pcall(Native.load,group.clips[math.random(#group.clips)])
      if ok then requests[#requests+1]={person=speaker,set=set,context=context,clip=clip,
       volume=group.volume or set.volume,fade_out=rule.fade_out==nil and .25 or rule.fade_out,
       priority=rule.priority or 0,key=id,response=rule.response}
      else warning(ctx,clip)end
     elseif set and not require('SceneZOI.AddonControl').muted(s,speaker.id)then warning(ctx,'Unavailable voice response '..tostring(rule.response)..' in '..set.id)
     end
    end
   end
  end
 end
 table.sort(requests,function(a,b)if a.priority~=b.priority then return a.priority>b.priority end;return a.key<b.key end)
 for _,item in ipairs(requests)do
  local id=item.person.id;local channel=ctx.channels[id]
  if not channel then channel={person=item.person,queue={}};ctx.channels[id]=channel end
  if not channel.item then start(ctx,channel,item)
  elseif item.priority>((channel.preempt or channel.item).priority)then
   channel.fade_base=(channel.stage=='fading'or channel.stage=='replacing')and(channel.fade_base or 1)*(channel.fade_alpha or 1)or 1
   channel.fade_alpha=1;channel.preempt=item;channel.fade=0;channel.queue={}
   if channel.stage=='playing'or channel.stage=='replacing'then channel.stage='replacing'
   else channel.item=item;channel.preempt=nil end
  elseif item.priority==((channel.preempt or channel.item).priority)then
   if #channel.queue<8 then channel.queue[#channel.queue+1]=item else warning(ctx,'Response queue full for '..id)end
  end
 end
end
local function point(person)
 return assert(Native.position({speaker=person},{{participant='speaker',component='head',bones={'FACIAL_C_Jaw'}}}),'Voice response source unavailable')
end
local function dispose(channel)
 if channel.voice then Native.destroy(channel.voice)end
 channel.voice=nil;channel.item=nil;channel.stage=nil;channel.preempt=nil
end
local function play(ctx,c,item,scale)
 Native.create(c.voice,c.person.actor,{volume=item.volume})
 Native.play(c.voice,item.clip,point(c.person),scale)
 c.voice.remaining=item.clip.duration;c.stage='playing';ctx.plays=ctx.plays+1
 print('[SceneZOI] Voice response played: participant='..c.person.id..' set='..item.set.id..' response='..item.response)
end
local function sample(ctx,id,c,delta,scale)
 if require('SceneZOI.AddonControl').muted(ctx.session,id)then dispose(c);c.queue={};ctx.channels[id]=nil;return end
 if c.failed then dispose(c);c.queue={} end
 local item=c.item
 if item then
  local set=selected(ctx,c.person,item.context)
  if not set or set.id~=item.set.id then dispose(c);c.queue={};item=nil end
 end
 if not item then
  while #c.queue>0 and not c.item do start(ctx,c,table.remove(c.queue,1))end
  if not c.item then ctx.channels[id]=nil;return end
  item=c.item
 end
 local audio_delta=scale>0 and delta*Native.rate(scale)/scale or 0
 if c.stage=='replacing'then
  local replacement=c.preempt;c.fade=c.fade+audio_delta
  local alpha=(replacement.fade_out>0 and c.fade<replacement.fade_out-1e-9)and math.max(0,1-c.fade/replacement.fade_out)or 0
  c.fade_alpha=alpha
  Native.volume(c.voice,item.volume*alpha*(c.fade_base or 1));Native.move(c.voice,point(c.person))
  Native.tune(c.voice,scale>0 and scale or c.voice.requested or 1,scale<=0)
  if scale>0 and alpha==0 then
   dispose(c);if start(ctx,c,replacement)then play(ctx,c,replacement,scale)end
  end
 elseif c.stage=='fading'then
  c.fade=c.fade+audio_delta
  local alpha=(item.fade_out>0 and c.fade<item.fade_out-1e-9)and math.max(0,1-c.fade/item.fade_out)or 0
  c.fade_alpha=alpha
  local playing=Voices.fade(ctx.session.voices,id,alpha*(c.fade_base or 1),scale)
  if scale>0 and (alpha==0 or not playing)then
   Voices.suspend(ctx.session.voices,id)
   play(ctx,c,item,scale)
  end
 elseif c.stage=='playing'then
  Native.move(c.voice,point(c.person));Native.tune(c.voice,scale>0 and scale or c.voice.requested or 1,scale<=0)
  c.voice.remaining=c.voice.remaining-audio_delta
  if Native.finished(c.voice)then
   dispose(c)
   if #c.queue==0 then ctx.channels[id]=nil end
  end
 end
end
function M.sample(ctx)
 local clock=ctx.session.clock;if not clock then return end;local now=clock.game_elapsed
 local delta=math.max(0,now-(ctx.last_time or now));ctx.last_time=now
 for id,c in pairs(ctx.channels)do
  local ok,err=pcall(sample,ctx,id,c,delta,clock.scale)
  if not ok then c.failed=true;warning(ctx,err)end
 end
end
function M.enter(ctx)ctx.last_time=ctx.session.clock and ctx.session.clock.game_elapsed or 0;M.sample(ctx)end
function M.guard(ctx)
 if ctx.session and ctx.session.preparing then
  ctx.last_time=ctx.session.clock.game_elapsed
  for _,c in pairs(ctx.channels)do if c.voice and c.voice.component then
   local ok,err=pcall(Native.pause,c.voice,true);if not ok then c.failed=true;warning(ctx,err)end
  end end
 end
end
function M.leave_node(ctx)
 -- A started response survives a prepared handoff. Unstarted requests never leak into a later scene.
 for _,c in pairs(ctx.channels or {})do c.queue={}end
end
function M.restore(ctx)
 local errors={}
 for id,c in pairs(ctx.channels or {})do
  local ok,err=pcall(dispose,c);if ok then ctx.channels[id]=nil else errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.status(ctx)
 local count=0;for _ in pairs(ctx.channels or {})do count=count+1 end
 return 'voice_responses:plays='..(ctx.plays or 0)..':channels='..count..(ctx.error and ':error='..ctx.error or '')
end
return M

-- Session-owned, data-defined completion actions. This tier supports spatial one-shot audio.
local Native=require('SceneZOI.SoundNative')
local M={}
function M.prepare(ctx,session)
 ctx.session=session;ctx.pools=ctx.pools or {};ctx.completed=ctx.completed or {};ctx.plays=ctx.plays or 0
 session.task_actions=ctx
 return true
end
function M.ready(ctx)return ctx.session~=nil end
local function warning(ctx,err)
 ctx.error=tostring(err);print('[SceneZOI] Task action: '..ctx.error)
end
local function position(voice)
 return assert(Native.position({completed=voice.participant},{{participant='completed',
  component=voice.spec.source.component,bones=voice.spec.source.bones}}),'Completion sound source bones are unavailable')
end
local function acquire(ctx,key,participant,spec)
 local pool=ctx.pools[key];if not pool then pool={};ctx.pools[key]=pool end
 local selected
 for _,voice in ipairs(pool)do if not voice.remaining and not voice.failed then selected=voice;break end end
 if not selected and #pool<(spec.max_voices or 4)then selected={};pool[#pool+1]=selected end
 if not selected then
  for _,voice in ipairs(pool)do
   if not voice.failed and(not selected or voice.started<selected.started)then selected=voice end
  end
  assert(selected,'Completion sound pool is waiting for cleanup')
  Native.stop(selected)
 end
 selected.participant,selected.spec=participant,spec
 return selected
end
local function play(ctx,key,participant,spec)
 local clip=Native.load(spec.clip)
 local voice=acquire(ctx,key,participant,spec)
 -- Ownership precedes all native mutations, including partially successful creation/play.
 local ok,err=pcall(function()
  local point=position(voice)
  Native.create(voice,participant.actor,spec)
  voice.remaining=clip.duration;voice.started=ctx.session.clock.game_elapsed
  Native.play(voice,clip,point,ctx.session.clock.scale)
 end)
 if not ok then voice.failed=true;error(err)end
 ctx.plays=ctx.plays+1
end
function M.trigger(ctx,payload)
 if not ctx or not ctx.session or ctx.session.stopping or ctx.session.ended then return end
 local session=ctx.session
 local definition=session.tasks and session.tasks.definitions[payload.task.id]
 if not definition then return end
 local person
 for _,p in ipairs(session.participants)do if p.id==payload.participant_id then person=p;break end end
 if not person then return end
 local key=payload.task.id..':'..person.id
 local index=payload.task.completion_index
 if type(index)~='number'or index<=(ctx.completed[key]or 0)then return end
 -- A failed optional sound is not replayed on a later frame; a new completion can try again.
 ctx.completed[key]=index
 local body=person.body or person.expression_body or(session.node.participants[person.role]or {}).body
 for i,spec in ipairs(definition.on_completion or {})do
  if not spec.when or not spec.when.body or spec.when.body==body then
   local ok,err=pcall(play,ctx,key..':'..i,person,spec)
   if not ok then warning(ctx,err)end
  end
 end
end
local function update(_,voice,delta,scale)
 if voice.failed then
  Native.destroy(voice);voice.failed=nil;voice.remaining=nil;return
 end
 if not voice.remaining then return end
 Native.move(voice,position(voice))
 Native.tune(voice,scale>0 and scale or voice.requested or 1,scale<=0)
 if scale>0 then voice.remaining=voice.remaining-delta*(voice.rate or 1)/scale end
 if Native.finished(voice)then Native.stop(voice)end
end
function M.sample(ctx)
 local clock=ctx.session.clock;local now=clock.game_elapsed
 local delta=math.max(0,now-(ctx.last_time or now));ctx.last_time=now
 for _,pool in pairs(ctx.pools)do for _,voice in ipairs(pool)do
  local ok,err=pcall(update,ctx,voice,delta,clock.scale)
  if not ok then voice.failed=true;warning(ctx,err)end
 end end
end
function M.enter(ctx)
 ctx.last_time=ctx.session.clock.game_elapsed
 M.sample(ctx)
end
function M.guard(ctx)
 if not ctx.session or not ctx.session.preparing then return end
 ctx.last_time=ctx.session.clock.game_elapsed
 for _,pool in pairs(ctx.pools)do for _,voice in ipairs(pool)do
  if voice.remaining then
   local ok,err=pcall(Native.pause,voice,true)
   if not ok then voice.failed=true;warning(ctx,err)end
  end
 end end
end
function M.restore(ctx)
 local errors={}
 for _,pool in pairs(ctx.pools or {})do for _,voice in ipairs(pool)do
  local ok,err=pcall(Native.destroy,voice)
  if not ok then errors[#errors+1]=tostring(err)end
 end end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.status(ctx)
 local active=0
 for _,pool in pairs(ctx.pools or {})do for _,v in ipairs(pool)do if v.remaining then active=active+1 end end end
 return 'task_actions:plays='..(ctx.plays or 0)..':active='..active..(ctx.error and ':error='..ctx.error or '')
end
return M

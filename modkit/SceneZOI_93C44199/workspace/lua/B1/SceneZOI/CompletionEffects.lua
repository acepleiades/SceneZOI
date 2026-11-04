-- Scene-local visual task responses. The existing task engine owns progress/events/audio.
local Motion=require('SceneZOI.MotionResponse')
local Bones=require('SceneZOI.BoneOscillation')
local Config=require('SceneZOI.Config')
local M={}
local function warning(ctx,err)
 local message=tostring(err)
 if message~=ctx.error then print('[SceneZOI] Completion effect: '..message);ctx.error=message end
end
function M.prepare(ctx,session)
 ctx.session=session;ctx.shakes=ctx.shakes or {};ctx.seen=ctx.seen or {};ctx.starts=ctx.starts or 0
 session.completion_effects=ctx;return true
end
function M.ready(ctx)return ctx.session~=nil end
function M.enter(ctx)end
local function key(p)return p.participant_role..'|'..p.task.id..'|'..p.participant_id end
function M.trigger(ctx,payloads)
 if not ctx then return end
 local s=ctx.session
 if s.stopping or s.ended or s.preparing or s.node.kind=='transition'then return end
 local candidates={};for _,p in ipairs(payloads)do candidates[#candidates+1]=p end
 table.sort(candidates,function(a,b)return key(a)<key(b)end)
 for _,p in ipairs(candidates)do
  local person=(s.bindings or {})[p.participant_role]
  local spec=((s.node.completion_responses or {})[p.participant_role]or {})[p.task.id]
  local id=p.participant_id..'|'..p.task.id
  local index=p.task.completion_index
  if person and person.id==p.participant_id and p.task.completed and spec and spec.enabled and
   type(index)=='number'and index>(ctx.seen[id]or 0)then
   ctx.seen[id]=index;ctx.starts=ctx.starts+1
   if spec.shake then
    local old=ctx.shakes[person.id]
    if old then local ok,err=pcall(Bones.restore,old);if not ok then warning(ctx,err)else ctx.shakes[person.id]=nil end end
    if not ctx.shakes[person.id]then ctx.shakes[person.id]={participant=person,spec=spec.shake,start=s.clock.game_elapsed}end
   end
   -- One scene clock: never stack multipliers or restart an in-flight response.
   if spec.slowdown and not ctx.motion then
    ctx.motion=Motion.new(spec.slowdown,s.node.movement_timing,s.duration,s.clock.elapsed)
    ctx.source=id
    print('[SceneZOI] Completion slowdown: node='..s.node.id..' owner='..person.id..' task='..p.task.id..' timing='..(s.node.movement_timing and 'synchronized'or 'fallback'))
   end
  end
 end
end
function M.multiplier(ctx,real_dt,scale)
 if not ctx or not ctx.motion then return 1 end
 local delta=real_dt*scale*Config.playback_speeds[ctx.session.clock.index]
 if delta<=0 then return ctx.session.clock.modifier or 1 end
 local ok,value=pcall(Motion.advance,ctx.motion,delta)
 if not ok then warning(ctx,value);ctx.motion=nil;return 1 end
 if ctx.motion.stage=='done'then
  print('[SceneZOI] Completion slowdown finished: node='..ctx.session.node.id..' owner_task='..tostring(ctx.source))
  ctx.motion=nil
 end
 return value/delta
end
function M.angle(spec,elapsed)
 local duration=spec.duration or 6;local delay=spec.delay or .5;local t=elapsed-delay
 if t<0 then return nil,false end
 if t>=duration then return nil,true end
 local segment=t/duration*(spec.bursts or 3);local part=segment-math.floor(segment)
 local duty=spec.duty_cycle or .7
 if part>duty then return 0,false end
 local envelope=1-math.abs(2*part/duty-1)
 -- Like Harem Room: game-time oscillation independent of slowed animation time.
 return math.sin((elapsed-delay)*2*math.pi*(spec.frequency_hz or 18))*(spec.amplitude_degrees or 1.25)*envelope,false
end
function M.sample(ctx)
 for id,o in pairs(ctx.shakes or {})do
  local angle,finished=M.angle(o.spec,ctx.session.clock.game_elapsed-o.start)
  local ok,err
  if finished or o.failed then
   ok,err=pcall(Bones.restore,o);if ok then ctx.shakes[id]=nil end
  elseif angle~=nil then ok,err=pcall(Bones.apply,o,o.spec,angle)
  else ok=true end
  if not ok then o.failed=true;warning(ctx,err)end
 end
end
function M.guard(ctx)
 -- Holds freeze game_elapsed. Reapply the same correction to a rebuilt body.
 if ctx.session and ctx.session.preparing then M.sample(ctx)end
end
local function release(ctx,strict)
 ctx.motion=nil
 if ctx.session and ctx.session.clock then ctx.session.clock.modifier=1 end
 local errors={}
 for id,o in pairs(ctx.shakes or {})do
  local ok,err=pcall(Bones.restore,o);if ok then ctx.shakes[id]=nil else o.failed=true;errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then
  if strict then error(table.concat(errors,'; '))else warning(ctx,table.concat(errors,'; '))end
 end
end
function M.leave_node(ctx)release(ctx,false)end
function M.restore(ctx)release(ctx,true)end
function M.snapshot(ctx)
 local owners={}
 for id,o in pairs(ctx and ctx.shakes or {})do if not o.failed then owners[#owners+1]=id end end
 table.sort(owners)
 return {stage=ctx and ctx.motion and ctx.motion.stage or 'none',source=ctx and ctx.source,
  starts=ctx and ctx.starts or 0,shaking_participants=owners,error=ctx and ctx.error}
end
function M.status(ctx)
 local count=0;for _ in pairs(ctx.shakes or {})do count=count+1 end
 return 'completion_effects:starts='..(ctx.starts or 0)..':motion='..(ctx.motion and ctx.motion.stage or 'none')..
  ':factor='..string.format('%.4f',ctx.session and ctx.session.clock and ctx.session.clock.modifier or 1)..':shakes='..count..(ctx.error and ':error='..ctx.error or '')
end
return M

-- Each participant owns a continuous audio context. Reuses SFX's native-time,
-- spatial playback, preparation hold, asset recovery and retryable cleanup.
local Library=require('SceneZOI.VoiceLibrary')
local Personality=require('SceneZOI.VoicePersonality')
local Keys=require('SceneZOI.ExpressionKeys')
local Sfx=require('SceneZOI.Sfx')
local Native=require('SceneZOI.SoundNative')
local M={}
function M.load()return {owners={}}end
function M.prepare(ctx,session)
 ctx.session=session;session.voices=ctx
 for _,p in ipairs(session.participants)do
  if not p.voice_loaded or p.voice_body~=p.expression_body then Personality.load(p,p.expression_body or p.body)end
 end
 for _,owner in pairs(ctx.owners)do Sfx.prepare(owner.audio,session)end
 return true
end
function M.ready(ctx)return ctx.session~=nil end
local function selected(ctx,p,requested)
 if not ctx then return nil end
 local spec=ctx.node.voices and ctx.node.voices[p.role]
 local context=Keys.normalize(requested or(spec and spec.context))
 local profile=p.voice_profile
 local id=context and profile and profile.sets[context]
 local set=id and Library.get().sets[id]
 if set and set.archetype==profile.archetype and set.body==p.voice_body and set.context==context then return set end
end
M.selected=selected
local function blocked(ctx,id)return ctx.session.voice_responses and ctx.session.voice_responses.channels[id]~=nil end
function M.fade(ctx,id,alpha,scale)
 local old=ctx and ctx.owners[id];if not old then return false end
 old.interrupted=true;local playing=false
 for _,e in ipairs(old.audio.emitters)do for _,v in ipairs(e.voices)do if v.remaining then
  playing=true;Native.volume(v,(e.spec.volume or 1)*alpha)
  Native.move(v,Native.position(ctx.session.bindings,e.spec.source))
  Native.tune(v,scale>0 and scale or v.requested or 1,scale<=0)
 end end end
 return playing
end
function M.suspend(ctx,id)
 local old=ctx and ctx.owners[id];if not old then return end
 old.interrupted=true
 for _,e in ipairs(old.audio.emitters)do for _,v in ipairs(e.voices)do Native.stop(v)end end
 old.audio.active=false
end
local function update(ctx,p)
 if require('SceneZOI.AddonControl').muted(ctx.session,p.id)then
  M.suspend(ctx,p.id);local owner=ctx.owners[p.id];if owner then owner.audio.last_time=ctx.session.clock.game_elapsed end;return
 end
 local set=selected(ctx,p);local old=ctx.owners[p.id]
 if old and(not set or old.id~=set.id)then
  -- Do not lose a failed cleanup lease when changing a live preference.
  Sfx.restore(old.audio);ctx.owners[p.id]=nil;old=nil
 end
 if not set then p.voice_error=nil;return end
 if blocked(ctx,p.id)then if old then old.audio.last_time=ctx.session.clock.game_elapsed end;return end
 if old and old.interrupted then
  for _,e in ipairs(old.audio.emitters)do
   for _,v in ipairs(e.voices)do Native.volume(v,set.volume)end
   if not old.audio.active then e.next_at=ctx.session.clock.game_elapsed+(set.gap or 0)end
  end
  old.audio.active=true;old.audio.last_time=ctx.session.clock.game_elapsed;old.interrupted=nil
 end
 if not old then
  local source={participant=p.role,component='head',bones={'FACIAL_C_Jaw'}}
  local spec={mode='continuous',owner=p.role,sound_set=set.id,source={source},volume=set.volume,gap=set.gap,max_voices=1,recent_limit=3}
  local audio=Sfx.load_emitters({[p.id]=spec},{[set.id]={default={clips=set.clips}}})
  old={id=set.id,audio=audio};ctx.owners[p.id]=old
  Sfx.prepare(audio,ctx.session);Sfx.enter(audio)
 else Sfx.sample(old.audio)end
 local errors={};for _,e in ipairs(old.audio.emitters)do if e.error then errors[#errors+1]=e.error end end
 p.voice_error=#errors>0 and table.concat(errors,'; ')or nil
end
function M.sample(ctx)
 if not ctx.active then return end
 for _,p in ipairs(ctx.session.participants)do update(ctx,p)end
end
function M.enter(ctx)
 ctx.active=true
 for id,owner in pairs(ctx.owners)do if not blocked(ctx,id)and not require('SceneZOI.AddonControl').muted(ctx.session,id)then Sfx.enter(owner.audio)end end
 M.sample(ctx)
end
function M.guard(ctx)for _,owner in pairs(ctx.owners)do Sfx.guard(owner.audio)end end
function M.leave_node(ctx)ctx.active=false;for _,owner in pairs(ctx.owners)do Sfx.leave_node(owner.audio)end end
function M.restore(ctx)
 ctx.active=false;local errors={}
 for id,owner in pairs(ctx.owners)do
  local ok,err=pcall(Sfx.restore,owner.audio)
  if ok then ctx.owners[id]=nil else errors[#errors+1]=tostring(err)end
 end
 if #errors>0 then error(table.concat(errors,'; '))end
end
function M.status(ctx)
 local rows={};for id,owner in pairs(ctx.owners)do rows[#rows+1]=id..':'..owner.id..':'..Sfx.status(owner.audio)end
 table.sort(rows);return 'voices='..(#rows>0 and table.concat(rows,'+')or 'none')
end
return M

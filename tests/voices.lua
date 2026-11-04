package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation')
local J=require('SceneZOI.Json')
local P=require('SceneZOI.Protocol')
local D=require('SceneZOI.VoiceData')
local source={by_kind={voice_archetype={},voice_context={},voice_set={}}}
local function add(kind,d)source.by_kind[kind][#source.by_kind[kind]+1]={source=d.id,data=d}end
for _,c in ipairs({'breath','new context'})do add('voice_context',{schema_version=1,id=c,label=c})end
for _,a in ipairs({'mature','cute','male'})do
 add('voice_archetype',{schema_version=1,id=a,label=a,body=a=='male'and'male'or'female',default=a=='mature'})
 for _,c in ipairs({'breath','new context'})do
  local clips={};for i=1,5 do clips[i]='/Test/'..a..i..'.'..a..i end
  add('voice_set',{schema_version=1,id=a..'.'..c,label=a..' '..c,body=a=='male'and'male'or'female',archetype=a,context=c,clips=clips,gap=.25})
 end
end
local data=D.compile(source);assert(#data.warnings==0 and data.defaults.female=='mature'and not data.defaults.male)
local other=V.copy(source);other.by_kind.voice_set[#other.by_kind.voice_set+1]={source='bad',data={schema_version=1,id='bad',label='bad',body='female',archetype='mature',context='breath',clips={'code()'}}}
assert(#D.compile(other).warnings==1 and D.compile(other).sets['mature.breath'])
other=V.copy(source);other.by_kind.voice_set[1].data.archetype='missing';assert(#D.compile(other).warnings==1)
other=V.copy(source);other.by_kind.voice_context[#other.by_kind.voice_context+1]={source='conflict',data={schema_version=1,id='BREATH',label='different'}}
assert(#D.compile(other).warnings==1 and D.compile(other).contexts.breath.label=='breath','Conflicting file must be isolated')
package.loaded['SceneZOI.VoiceLibrary']={get=function()return data end}
local saved,fail={},false
inzoi={cli={execute=function(line)
 local section=line:match('section=([^ ]+)');local id=line:match('key=([^ ]+)')
 if line:find('cfg_load',1,true)then return true,'',saved[section..'/'..id]or ''end
 if fail then return false end
 saved[section..'/'..id]=line:match('value=(.*)');return true
end}}
local Pref=require('SceneZOI.VoicePersonality')
local a,b,c={id='1',role='lead',expression_body='female'},{id='2',role='other',expression_body='female'},{id='3',role='helper',expression_body='male'}
for _,p in ipairs({a,b,c})do Pref.load(p,p.expression_body)end
assert(a.voice_profile.archetype=='mature'and a.voice_profile.sets.breath=='mature.breath')
assert(not c.voice_profile.archetype and not next(c.voice_profile.sets),'Male voices must be opt in')
local session={client='test',sequence='1',revision=1,participants={a,b,c},bindings={lead=a,other=b,helper=c},clock={game_elapsed=0,session_elapsed=0,scale=1,index=2}}
local count=0
local function request(person,action,id,revision)
 count=count+1;Pref.request(session,P.pack('test','1','voice',count,person,action,P.encode(id),revision or session.revision))
end
request('1','archetype','cute');assert(a.voice_profile.archetype=='cute'and a.voice_profile.sets.breath=='cute.breath'and a.voice_profile.sets['new context']=='cute.new context')
local before=saved['scenezoi_voice/zoi_1'];request('1',P.encode('breath'),'mature.breath');assert(session.voice_code=='voice_invalid'and saved['scenezoi_voice/zoi_1']==before,'Mixed archetype selection must never persist')
fail=true;request('1','archetype','mature');assert(session.voice_code=='voice_storage'and a.voice_profile.archetype=='cute');fail=false
request('1','archetype','mature',99);assert(session.voice_code=='voice_stale'and a.voice_profile.archetype=='cute')
session.stopping=true;request('1','archetype','mature');assert(a.voice_profile.archetype=='cute');session.stopping=false
request('1',P.encode('breath'),'');assert(not a.voice_profile.sets.breath)
local fresh={id='1'};Pref.load(fresh,'female');assert(fresh.voice_profile.archetype=='cute'and not fresh.voice_profile.sets.breath,'Explicit silence must survive another session')
request('1','archetype','');fresh={id='1'};Pref.load(fresh,'female');assert(not fresh.voice_profile.archetype,'Silent archetype must not revert to the default')
request('1','archetype','mature');request('3','archetype','male')
Pref.publish(session);local frame=P.unpack(saved['scenezoi_runtime/voice_state']or saved['scenezoi/voice_state']or '')
-- Config.section is intentionally read rather than assumed.
local Config=require('SceneZOI.Config');frame=assert(P.unpack(saved[Config.section..'/voice_state']))
assert(J.decode(P.decode(frame[6])).contexts['new context'],'Third-party contexts must reach UI metadata')
local plays,created,destroyed={},0,0;local fail_destroy=false;local unavailable=false
local N={}
function N.load(path)if unavailable then error('asset missing')end;return {path=path,duration=1}end
function N.position()return {X=1,Y=2,Z=3}end
function N.create(v,actor)if not v.component then v.component={};created=created+1;v.owner=actor.id end end
function N.move()end
function N.pause(v,p)v.paused=p end
function N.tune(v,r,p)v.rate=math.max(1,math.min(2,r));v.requested=r;v.paused=p end
function N.play(v,clip,position,r)N.tune(v,r,false);v.stopped=false;plays[#plays+1]={id=v.owner,path=clip.path,rate=r}end
function N.stop(v)v.remaining=nil;v.stopped=true end
function N.destroy(v)if fail_destroy then fail_destroy=false;error('cleanup retry')end;if v.component then destroyed=destroyed+1;v.component=nil;N.stop(v)end end
function N.finished(v)return not v.remaining or(v.remaining<=0 and not v.native_playing)end
package.loaded['SceneZOI.SoundNative']=N
package.loaded['SceneZOI.Catalog']={}
for _,p in ipairs({a,b,c})do p.actor={id=p.id}end
local Voice=require('SceneZOI.Voices')
local ctx=Voice.load();ctx.node={voices={lead={context='breath'},other={context='breath'},helper={context='breath'}}}
Voice.prepare(ctx,session);Voice.enter(ctx);assert(#plays==3 and created==3,'Repeated bodies and male content must own independent sources')
local function tick(delta)session.clock.game_elapsed=session.clock.game_elapsed+delta;Voice.sample(ctx)end
local initial=#plays;session.clock.index=4;Voice.sample(ctx);assert(#plays==initial and ctx.owners['1'].audio.emitters[1].voices[1].rate==1,'Scene speed must not retime or restart voices')
session.clock.scale=0;Voice.sample(ctx);assert(ctx.owners['1'].audio.emitters[1].voices[1].paused)
session.clock.scale=1;session.preparing=true;Voice.guard(ctx);assert(ctx.owners['2'].audio.emitters[1].voices[1].paused)
session.preparing=false;Voice.prepare(ctx,session);Voice.enter(ctx);assert(#plays==initial,'Outfit hold must not restart a voice')
tick(1);assert(#plays==initial,'Voice gap must follow clip completion');tick(.25);assert(#plays==initial+3)
for _=1,40 do tick(1);tick(.25)end
local recent={}
for _,event in ipairs(plays)do
 local history=recent[event.id]or {};for _,path in ipairs(history)do assert(path~=event.path,'Voice repeated one of the last three clips')end
 history[#history+1]=event.path;if #history>3 then table.remove(history,1)end;recent[event.id]=history
end
request('1','archetype','cute');local otherPlays=ctx.owners['2'].audio.emitters[1].plays;Voice.sample(ctx)
assert(ctx.owners['1'].id=='cute.breath'and ctx.owners['2'].audio.emitters[1].plays==otherPlays,'Changing one participant must not restart another')
request('1','archetype','');fail_destroy=true;assert(not pcall(Voice.sample,ctx));assert(ctx.owners['1'],'Failed destruction lost ownership');Voice.sample(ctx);assert(not ctx.owners['1'])
local voice=ctx.owners['2'].audio.emitters[1].voices[1]
local remaining=voice.remaining;initial=#plays;session.clock.scale=.1;Voice.sample(ctx)
assert(voice.rate==1 and #plays==initial)
tick(.025);assert(math.abs(voice.remaining-(remaining-.25))<.00001,'Slow-motion voice must consume real audio time')
session.clock.scale=0;Voice.sample(ctx);local held=voice.remaining;Voice.sample(ctx);assert(voice.paused and voice.remaining==held)
session.clock.scale=1;Voice.sample(ctx);assert(not voice.paused)
-- A live set change creates a new source; an asynchronous tail must not be cut by its timer.
local alternate=V.copy(data.sets['mature.breath']);alternate.id='mature.alternate'
alternate.clips={'/Test/Alternate1.Alternate1','/Test/Alternate2.Alternate2'};data.sets[alternate.id]=alternate
local prior=ctx.owners['2'];request('2',P.encode('breath'),alternate.id);Voice.sample(ctx)
local replaced=ctx.owners['2'];assert(replaced~=prior and replaced.id==alternate.id)
local emitter=replaced.audio.emitters[1];local tail=emitter.voices[1];local beforePlays=emitter.plays
tail.native_playing=true;tick(1.05)
assert(tail.remaining<0 and not tail.stopped and emitter.plays==beforePlays,'Live-switched voice must retain native tail past estimated duration')
tail.native_playing=false;Voice.sample(ctx);assert(tail.stopped and emitter.plays==beforePlays)
tick(.26);assert(emitter.plays==beforePlays+1,'Next clip starts only after natural finish plus configured gap')
Voice.leave_node(ctx);initial=#plays;tick(10);assert(#plays==initial)
fail_destroy=true;assert(not pcall(Voice.restore,ctx));Voice.restore(ctx);assert(created==destroyed,'Owned voice audio leaked')
local hub=Voice.load();hub.node={};Voice.prepare(hub,session);Voice.enter(hub);assert(not next(hub.owners),'A hub without voice data must be silent');Voice.restore(hub)
local silent=Voice.load();silent.node={voices={lead={context='breath'}}};Voice.prepare(silent,session);Voice.enter(silent);assert(not next(silent.owners),'An unassigned participant must be silent')
request('1','archetype','mature');unavailable=true;Voice.sample(silent);assert(a.voice_error,'Missing optional audio must report a warning');unavailable=false;tick(6)
session.clock.game_elapsed=session.clock.game_elapsed+6;Voice.sample(silent);assert(not a.voice_error,'Optional audio must recover');Voice.restore(silent)
print('Voices passed: dynamic contexts, content defaults, single-archetype persistence/silence, stale/storage/Exit guards, repeated-body and male owners, recent-three selection, pause/holds/native time, navigation, optional recovery and retryable cleanup.')

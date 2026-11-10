package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local P=require('SceneZOI.Protocol');local Config=require('SceneZOI.Config')
local saved,fail,applied,updates={},false,nil,0
inzoi={cli={execute=function(line)
 local key=line:match('section=([^ ]+)')..'/'..line:match('key=([^ ]+)')
 if line:find('cfg_load',1,true)then return true,'',saved[key]or ''end
 if fail then return false end
 saved[key]=line:match('value=(.*)');return true
end}}
package.loaded['SceneZOI.SoundNative']={set_gains=function(v)applied=v;updates=updates+1 end}
local S=require('SceneZOI.Settings');S.boot()
assert(applied.sfx==1 and applied.female_voice==1 and applied.male_voice==1)
local s={client='test',sequence='1',revision=2}
local function request(count,rev,a,b,c,client,sequence)
 S.request(s,'audio',P.pack(client or 'test',sequence or '1','settings_audio',count,rev,a,b,c))
end
request(1,2,0,150,200);assert(s.player_settings.audio.code=='ok'and applied.sfx==0 and applied.female_voice==1.5 and applied.male_voice==2)
assert(saved['scenezoi_settings/audio']==P.pack('1',0,150,200))
local before=updates
request(1,2,100,100,100);assert(updates==before,'Retries must not apply twice')
request(2,2,100,100,100,'other');request(2,2,100,100,100,nil,'2');assert(updates==before,'Old/foreign sessions must be ignored')
request(2,1,100,100,100);assert(s.player_settings.audio.code=='settings_stale'and updates==before)
for i,value in ipairs({-1,201,1.5,'nan','none'})do request(i+2,2,value,100,100);assert(s.player_settings.audio.code=='settings_invalid'and updates==before)end
fail=true;request(8,2,50,50,50);assert(s.player_settings.audio.code=='settings_storage'and applied.sfx==0);fail=false
S.publish(s);local f=P.unpack(saved[Config.section..'/settings_audio_state']);assert(f[4]=='8'and f[5]=='settings_storage'and f[6]=='0'and f[8]=='200')
s.preparing=true;request(9,2,50,50,50);assert(s.player_settings.audio.ack==8);s.preparing=false
s.stopping=true;request(9,2,50,50,50);assert(updates==before);s.stopping=false
S.boot();assert(applied.sfx==0 and applied.female_voice==1.5,'Preferences must survive host/session restart')
saved['scenezoi_settings/audio']=P.pack('1',50,999,50);S.boot();assert(applied.sfx==1 and applied.female_voice==1,'Malformed saved record must fall back atomically')
saved['scenezoi_settings/audio']=P.pack('2',50,50,50);S.boot();assert(applied.sfx==1)
request(9,2,200,0,25);assert(applied.sfx==2 and applied.female_voice==0 and applied.male_voice==.25)
S.publish(s);local previous=saved[Config.section..'/settings_audio_state'];fail=true;S.publish(s);fail=false;assert(saved[Config.section..'/settings_audio_state']==previous)
print('Settings passed: defaults, persistence/restart, transactional bounds, exact session/revision ownership, retry acknowledgements, storage failure and stopped/preparing gates.')

local before_audio=saved['scenezoi_settings/audio'];local before_updates=updates
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',1,2,50,200))
assert(S.task_multiplier('female')==.5 and S.task_multiplier('male')==2 and S.task_multiplier('other')==1)
assert(saved['scenezoi_settings/audio']==before_audio and updates==before_updates,'Task settings must preserve existing audio preferences/components')
assert(saved['scenezoi_settings/task_rates']==P.pack('1',50,200))
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',1,2,10,10));assert(S.task_multiplier('female')==.5,'Duplicate group packets must not apply twice')
fail=true;S.request(s,'task_rates',P.pack('test','1','settings_task_rates',2,2,25,25));fail=false
assert(s.player_settings.task_rates.code=='settings_storage'and S.task_multiplier('female')==.5)
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',3,1,25,25));assert(s.player_settings.task_rates.code=='settings_stale')
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',4,2,501,10));assert(s.player_settings.task_rates.code=='settings_invalid')
S.request(s,'audio',P.pack('test','1','settings_audio',10,2,75,100,125));assert(S.task_multiplier('male')==2,'Audio settings must preserve task preferences')
S.publish(s);local task_frame=P.unpack(saved[Config.section..'/settings_task_rates_state']);assert(#task_frame==7 and task_frame[6]=='50'and task_frame[7]=='200')
S.boot();assert(S.task_multiplier('female')==.5 and S.task_multiplier('male')==2 and applied.sfx==.75,'Both independent groups must survive a restart')
saved['scenezoi_settings/task_rates']=P.pack('1',100,999);S.boot();assert(S.task_multiplier('female')==1 and applied.sfx==.75,'Malformed task settings must not reset audio')
print('Task settings passed: independent counters/storage, failed/stale edits, appearance body lookup, saved audio preservation and restart.')

saved['scenezoi_settings/task_rates']=P.pack('1',0,500);S.boot()
assert(S.task_multiplier('female')==.1 and S.task_multiplier('male')==5 and applied.sfx==.75,'Saved values below the new minimum clamp without losing the other body or audio preferences')
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',5,2,9,500));assert(s.player_settings.task_rates.code=='settings_invalid')
S.request(s,'task_rates',P.pack('test','1','settings_task_rates',6,2,10,500));assert(S.task_multiplier('female')==.1 and S.task_multiplier('male')==5)
S.boot();assert(S.task_multiplier('female')==.1 and S.task_multiplier('male')==5,'New endpoints must persist and reload')

-- NPC scene length, in in-game minutes: 15 until changed, 5 to 120, kept across restarts.
assert(S.npc_scene_minutes()==15,'A new install uses 15 in-game minutes')
local function npc(count,value)S.request(s,'npc_scene',P.pack('test','1','settings_npc_scene',count,2,value))end
npc(1,30);assert(S.npc_scene_minutes()==30 and saved['scenezoi_settings/npc_scene']==P.pack('1',30))
npc(2,4);assert(S.npc_scene_minutes()==30 and s.player_settings.npc_scene.code=='settings_invalid','Below 5 is refused')
npc(3,121);assert(S.npc_scene_minutes()==30,'Above 120 is refused')
npc(4,120);assert(S.npc_scene_minutes()==120);npc(5,5);assert(S.npc_scene_minutes()==5)
S.boot();assert(S.npc_scene_minutes()==5,'It survives a restart')
saved['scenezoi_settings/npc_scene']=P.pack('1',999);S.boot();assert(S.npc_scene_minutes()==15,'A damaged record falls back to 15')
saved['scenezoi_settings/npc_scene']=P.pack('1',2);S.boot();assert(S.npc_scene_minutes()==5,'A stored value below the range loads at 5')
print('NPC scene length passed: default, bounds, persistence and damaged records.')

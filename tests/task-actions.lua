package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local V=require('SceneZOI.DataValidation');local Data=require('SceneZOI.TaskData')
local calls,created,destroyed={},0,0
local missing,fail_play,fail_destroy,fail_create=false,false,false,false
local N={}
function N.load(path)if missing then error('missing optional sound')end;return {path=path,duration=6}end
function N.position(bindings,sources)
 local point=sources[1];assert(point.component=='body'and point.bones[1]=='root')
 return bindings[point.participant].actor.point
end
function N.create(v,actor,spec)
 if not v.component then created=created+1;v.component={};v.owner=actor.id;v.destroyed=false end
 if fail_create then fail_create=false;error('partial create')end
 v.volume=spec.volume or 1
end
function N.move(v,p)v.point=p end
function N.pause(v,value)v.paused=value end
function N.tune(v,rate,pause)v.requested=rate;v.rate=math.max(1,math.min(2,rate));v.paused=pause end
function N.play(v,clip,p,rate)
 v.stopped=false;N.move(v,p);N.tune(v,rate,false)
 if fail_play then fail_play=false;error('partial play')end
 calls[#calls+1]={owner=v.owner,path=clip.path,point=p,rate=rate}
end
function N.stop(v)v.remaining=nil;v.stopped=true end
function N.destroy(v)
 if v.destroyed then return end
 if fail_destroy then fail_destroy=false;error('cleanup retry')end
 N.stop(v);v.component=nil;v.destroyed=true;destroyed=destroyed+1
end
function N.finished(v)return not v.remaining or v.remaining<=0 end
package.loaded['SceneZOI.SoundNative']=N
local A=require('SceneZOI.TaskActions')
local spec={type='play_sound',when={body='male'},clip='/Neutral/Charge.Charge',source={component='body',bones={'root'}},max_voices=2,volume=.7}
local definition=Data.validate({schema_version=1,id='charge',label='Charge',maximum=10,on_completion={spec}})
local people={}
for i,body in ipairs({'male','female','male'})do people[i]={id=tostring(i),role='role'..i,body=body,actor={id=tostring(i),point={X=i,Y=0,Z=0}}}end
local session={participants=people,node={id='neutral.scene',participants={}},tasks={definitions={charge=definition}},clock={game_elapsed=0,scale=1,index=2}}
local ctx={};A.prepare(ctx,session);assert(A.ready(ctx));A.enter(ctx)
local function complete(id,index)A.trigger(ctx,{participant_id=id,task={id='charge',completion_index=index}})end
complete('1',1);complete('2',1);complete('3',1);assert(#calls==2 and calls[1].owner=='1'and calls[2].owner=='3','Completed-participant body filter and repeated-body owners')
complete('1',1);assert(#calls==2,'No duplicate playback for repeated completion delivery')
local pool=ctx.pools['charge:1:1'];assert(pool[1].volume==.7)
people[1].actor.point={X=100,Y=200,Z=300};session.clock.index=4;session.clock.game_elapsed=1;A.sample(ctx)
assert(pool[1].point.X==100 and pool[1].requested==1 and pool[1].remaining==5,'Follow bone translation without scene-speed pitch changes')
session.clock.scale=0;A.sample(ctx);assert(pool[1].paused and pool[1].remaining==5)
session.preparing=true;A.guard(ctx);assert(pool[1].paused)
-- Navigation retains the same context and independent participant ownership.
session.node={id='neutral.idle',participants={}};A.prepare(ctx,session);session.preparing=false;session.clock.scale=3;A.enter(ctx)
session.clock.game_elapsed=4;A.sample(ctx);assert(pool[1].remaining==3 and pool[1].rate==2,'Use native audio pitch limits in duration accounting')
session.clock.game_elapsed=9;A.sample(ctx);assert(not pool[1].remaining)
local count=#calls;session.clock.game_elapsed=20;A.sample(ctx);assert(#calls==count,'One shot never becomes a continuous loop')
session.clock.scale=1;complete('1',2);complete('1',3);complete('1',4);assert(#pool==2 and #calls==count+3,'Bounded pool steals only the oldest voice for this owner/action')
assert(#ctx.pools['charge:3:1']==1,'Another participant pool is independent')
missing=true;complete('1',5);local after=#calls;missing=false;A.sample(ctx);complete('1',5);assert(#calls==after,'Missing sound is not replayed on another frame')
complete('1',6);assert(#calls==after+1,'New completion can recover an optional asset')
fail_play=true;complete('3',2);local failed=ctx.pools['charge:3:1'][1]
-- The first voice may have expired and been reused; any failed voice stays owned for cleanup.
local found=false;for _,v in ipairs(ctx.pools['charge:3:1'])do if v.failed then found=true end end;assert(found)
fail_destroy=true;A.sample(ctx);A.sample(ctx)
fail_create=true;complete('3',3);A.sample(ctx)
fail_destroy=true;assert(not pcall(A.restore,ctx));A.restore(ctx);A.restore(ctx)
assert(created==destroyed,'No leaked components after partial failures and retryable Exit')
session.clock.scale=.1;complete('1',8);local current
for _,v in ipairs(pool)do if v.remaining and v.started==session.clock.game_elapsed then current=v end end
assert(current and current.rate==1)
session.clock.game_elapsed=session.clock.game_elapsed+.5;A.sample(ctx)
assert(math.abs(current.remaining-1)<.00001,'Six-second one-shot consumes five real seconds at 0.1x')
session.clock.scale=0;A.sample(ctx);assert(current.paused and math.abs(current.remaining-1)<.00001)
session.clock.scale=.1;session.clock.game_elapsed=session.clock.game_elapsed+.11;A.sample(ctx)
assert(not current.remaining,'One-shot must expire during slow motion')
A.restore(ctx)
local before=#calls;session.stopping=true;complete('1',7);assert(#calls==before,'Stopping sessions cannot start sounds')
for _,change in ipairs({{type='callback'},{clip='run()'},{source={component='body',bones={}}},{when={body='unknown'}},{volume=-1},{max_voices=0},{attenuation={callback='run()'}}})do
 local action=V.copy(spec);for k,v in pairs(change)do action[k]=v end
 assert(not pcall(Data.validate,{schema_version=1,id='bad',label='Bad',maximum=10,on_completion={action}}),'Invalid action accepted')
end
print('Task actions passed: data-only body filter, independent owners, one-shot/dedup, moving bone source, scene-speed independence, native pitch/pause, navigation, bounded overlap, missing assets and partial-play/create/cleanup retries.')

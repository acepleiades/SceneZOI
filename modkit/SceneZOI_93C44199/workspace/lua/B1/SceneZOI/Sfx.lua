-- Independent emitters. Clip rate/timers use native-game time, variants use scene speed.
local Native=require('SceneZOI.SoundNative')
local Library=require('SceneZOI.Catalog')
local Config=require('SceneZOI.Config')
local M={}
local function group(spec)
    local result={clips={},scene_speed=spec.scene_speed,errors={}}
    for _,path in ipairs(spec.clips)do
        local ok,clip=pcall(Native.load,path)
        if ok then result.clips[#result.clips+1]=clip else result.errors[#result.errors+1]=tostring(clip)end
    end
    return result
end
local function load(e)
    local spec=e.library;e.groups={}
    if spec.default then e.groups.default=group(spec.default)end
    for _,variant in ipairs(spec.variants or {})do e.groups[variant.scene_speed]=group(variant)end
end
function M.load_emitters(specs,sounds,category)
    local emitters={};local ids={}
    for id in pairs(specs or {})do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids)do
        local spec=specs[id]
        local e={id=id,spec=spec,audio_category=category,library=assert(sounds[spec.sound_set]),voices={},plays=0}
        load(e);emitters[#emitters+1]=e
    end
    return {emitters=emitters}
end
function M.load(node)return M.load_emitters(node.sfx,Library.get_snapshot().sound_sets)end
function M.prepare(ctx,session)
    ctx.session,ctx.bindings=session,session.bindings
    return true
end
function M.ready(ctx)return ctx.session~=nil end
local function choose(e,g)
    local options,excluded={},{}
    local recent=e.recent or (e.last_path and {e.last_path}or {})
    local limit=math.min(e.spec.recent_limit or 1,math.max(0,#g.clips-1))
    if e.spec.avoid_repeat~=false then
        for i=math.max(1,#recent-limit+1),#recent do excluded[recent[i]]=true end
    end
    for _,clip in ipairs(g.clips)do if not excluded[clip.path]then options[#options+1]=clip end end
    return options[math.random(#options)]
end
local function acquire(e,actor)
    for _,v in ipairs(e.voices)do if not v.remaining then Native.create(v,actor,e.spec,e.audio_category);return v end end
    local v
    if #e.voices<(e.spec.max_voices or 4)then
        v={};e.voices[#e.voices+1]=v
    else
        v=e.voices[1]
        for _,candidate in ipairs(e.voices)do if candidate.started<v.started then v=candidate end end
        Native.stop(v)
    end
    Native.create(v,actor,e.spec,e.audio_category);return v
end
local function play(ctx,e,g,position,now,game_scale)
    local clip=choose(e,g);local v=acquire(e,assert(ctx.bindings[e.spec.owner]).actor)
    v.remaining=clip.duration;v.started=now
    Native.play(v,clip,position,game_scale)
    e.last_path=clip.path;e.recent=e.recent or {};e.recent[#e.recent+1]=clip.path
    while #e.recent>(e.spec.recent_limit or 1)do table.remove(e.recent,1)end
    e.plays=e.plays+1;e.error=nil
end
local function reset_detector(e)e.distance=nil;e.trend=nil;e.extreme=nil;e.sample_at=nil end
local function stop(e)
    local errors={}
    for _,v in ipairs(e.voices)do local ok,err=pcall(Native.stop,v);if not ok then errors[#errors+1]=tostring(err)end end
    if #errors>0 then error(table.concat(errors,'; '))end
    reset_detector(e)
end
local function update(ctx,e,now,delta,game_scale,speed)
    if e.retry_at and now<e.retry_at then return end
    if e.reload then load(e);e.reload=nil end
    local g=e.groups[speed] or e.groups.default
    if not g or #g.clips==0 then
        e.error='No available clips for the selected speed';e.retry_at=now+5;e.reload=true;stop(e);return
    end
    e.retry_at=nil
    local position=Native.position(ctx.bindings,e.spec.source)
    if not position then error('Sound source bones are not ready')end
    if e.spec.mode=='continuous' and e.group and e.group~=g then
        -- Speed-specific assets switch immediately; generic sets retain their clip.
        stop(e);e.next_at=now
    end
    e.group=g
    local playing=false
    for _,v in ipairs(e.voices)do
        if v.remaining then
            Native.move(v,position)
            Native.tune(v,game_scale>0 and game_scale or v.requested or 1,game_scale<=0)
            if game_scale>0 then v.remaining=v.remaining-delta*(v.rate or 1)/game_scale end
            if Native.finished(v)then
                Native.stop(v)
                if e.spec.mode=='continuous'then e.next_at=now+(e.spec.gap or 0)end
            else playing=true end
        end
    end
    if game_scale<=0 then return end
    if e.spec.mode=='continuous'then
        if not playing and now>=(e.next_at or now)then play(ctx,e,g,position,now,game_scale)end
        return
    end
    local spec=e.spec.distance
    if now<(e.sample_at or 0)then return end
    e.sample_at=now+(spec.sample_interval or 1/60)
    local a,b=Native.point(ctx.bindings,spec.from),Native.point(ctx.bindings,spec.to)
    if not a or not b then error('Detector bones are not ready')end
    local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
    local distance=math.sqrt(x*x+y*y+z*z)
    -- Accumulate movement from the last extremum. A per-frame dead band
    -- loses slow/subtle movement and delays reversals as frame rate increases.
    local epsilon=spec.min_delta_cm or .1
    if not e.extreme then e.extreme=distance
    elseif not e.trend then
        local change=distance-e.extreme
        if math.abs(change)>=epsilon then e.trend=change<0 and -1 or 1;e.extreme=distance end
    elseif e.trend==-1 then
        if distance<e.extreme then e.extreme=distance
        elseif distance-e.extreme>=epsilon then
            local closest=e.extreme
            e.trend=1;e.extreme=distance
            if closest<(spec.max_distance_cm or 30)and now>=(e.cooldown_until or 0)then
                play(ctx,e,g,position,now,game_scale);e.cooldown_until=now+(spec.cooldown or .15)
            end
        end
    else
        if distance>e.extreme then e.extreme=distance
        elseif e.extreme-distance>=epsilon then e.trend=-1;e.extreme=distance end
    end
    e.distance=distance
end
function M.sample(ctx)
    if not ctx.active then return end
    local clock=ctx.session.clock;local now=clock.game_elapsed
    local delta=math.max(0,now-(ctx.last_time or now));ctx.last_time=now
    if ctx.was_preparing then
        for _,e in ipairs(ctx.emitters)do reset_detector(e)end
        ctx.was_preparing=false
    end
    for _,e in ipairs(ctx.emitters)do
        local ok,err=pcall(update,ctx,e,now,delta,clock.scale,Config.playback_speeds[clock.index or 2])
        if not ok then
            e.error=tostring(err);e.retry_at=now+5
            -- A failed stop remains a session cleanup error, never abandoned audio.
            stop(e)
        end
    end
end
function M.enter(ctx)
    if ctx.active and ctx.revision==ctx.session.revision then M.sample(ctx);return end
    ctx.active=true;ctx.revision=ctx.session.revision;ctx.last_time=ctx.session.clock.game_elapsed
    for _,e in ipairs(ctx.emitters)do e.next_at=ctx.last_time;reset_detector(e)end
    M.sample(ctx)
end
function M.guard(ctx)
    if ctx.active and ctx.session.preparing then
        ctx.was_preparing=true
        for _,e in ipairs(ctx.emitters)do for _,v in ipairs(e.voices)do if v.remaining then Native.pause(v,true)end end end
    end
end
function M.leave_node(ctx)ctx.active=false end
function M.restore(ctx)
    ctx.active=false;local errors={}
    for _,e in ipairs(ctx.emitters or {})do
        for _,v in ipairs(e.voices)do
            local ok,err=pcall(Native.destroy,v);if not ok then errors[#errors+1]=tostring(err)end
        end
    end
    if #errors>0 then error(table.concat(errors,'; '))end
end
function M.status(ctx)
    local rows={}
    for _,e in ipairs(ctx.emitters or {})do
        local active,limited=0,0
        for _,v in ipairs(e.voices)do
            if v.remaining then active=active+1;if v.requested and math.abs(v.requested-(v.rate or v.requested))>.001 then limited=limited+1 end end
        end
        local pitch='none'
        for _,v in ipairs(e.voices)do if v.remaining then pitch=string.format('%.2f/%.2f',v.rate or 0,v.requested or 0)..':'..tostring(v.limit_source or 'unknown');break end end
        rows[#rows+1]=e.id..':plays='..e.plays..':active='..active..':distance='..string.format('%.2f',e.distance or -1)..':pitch_limited='..limited..':pitch='..pitch..':bucket='..tostring(e.group and e.group.scene_speed or 'default')..':clip='..tostring(e.last_path or 'none')..(e.error and ':error='..e.error or '')
    end
    return 'sfx='..(#rows>0 and table.concat(rows,'+')or 'none')
end
return M

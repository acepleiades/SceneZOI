-- Scene-owned world audio only. No global mixes, game sounds or UI audio are changed.
local Head=require('SceneZOI.GazeNative')
local M={}
local gains={sfx=1,female_voice=1,male_voice=1}
local owned=setmetatable({},{__mode='k'})
local function apply_volume(v)
    local volume=(v.base_volume or 1)*(gains[v.audio_category or 'sfx']or 1)
    if v.component and not v.destroyed and v.applied_volume~=volume then
        v.component:SetVolumeMultiplier(volume);v.applied_volume=volume
    end
end
function M.set_gains(next_gains)
    for key in pairs(gains)do
        local value=next_gains[key]
        assert(type(value)=='number'and value==value and value>=0 and value<=2,'Invalid audio gain')
    end
    for key in pairs(gains)do gains[key]=next_gains[key]end
    for v in pairs(owned)do
        -- One departed actor must not prevent unrelated channels updating.
        -- Failed components retry through their ordinary tune/cleanup path.
        local ok,err=pcall(apply_volume,v)
        if not ok and v.volume_error~=tostring(err)then print('[SceneZOI] Audio volume: '..tostring(err))end
        v.volume_error=not ok and tostring(err)or nil
    end
end
local function valid(object)
    local ok,value=pcall(function()return UE.UKismetSystemLibrary.IsValid(object)end)
    return not ok or value~=false
end
function M.load(path)
    local asset=UE.UObject.Load(path)
    assert(asset and asset:IsA(UE.USoundWave:StaticClass()),'Expected a SoundWave: '..path)
    local duration=asset.Duration
    assert(type(duration)=='number' and duration==duration and duration>0 and duration<math.huge,'Invalid sound duration')
    return {path=path,asset=asset,duration=duration}
end
function M.point(bindings,spec)
    return Head.target(assert(bindings[spec.participant],'Missing SFX participant'),spec)
end
function M.position(bindings,sources)
    local x,y,z=0,0,0
    for _,point in ipairs(sources)do
        local p=M.point(bindings,point);if not p then return nil end
        x,y,z=x+p.X,y+p.Y,z+p.Z
    end
    return UE.FVector(x/#sources,y/#sources,z/#sources)
end
local limits
function M.rate(requested)
    if not limits then
        local ok,value=pcall(function()
            local settings=assert(UE.UObject.Load('/Script/Engine.Default__AudioSettings'))
            local low,high=settings.GlobalMinPitchScale,settings.GlobalMaxPitchScale
            assert(type(low)=='number'and type(high)=='number'and low>0 and high>=low)
            return {low=low,high=high,source='native'}
        end)
        limits=ok and value or {low=.4,high=2,source='fallback'}
    end
    -- Slow simulation/camera movement must not stretch or lower audio pitch.
    -- Pause remains a separate SetPaused operation; fast-forward keeps native bounds.
    return math.max(limits.low,math.min(limits.high,math.max(1,requested))),limits.source
end
local function configure(v,spec)
    local c=v.component
    -- Actor-owned AddComponentByClass components use the non-auto-destroy constructor default.
    c.bAutoActivate=false
    c:SetUISound(false);c.bAllowSpatialization=true
    local a=UE.FSoundAttenuationSettings()
    a.bAttenuate=true;a.bSpatialize=true;a.AttenuationShape=0
    a.AttenuationShapeExtents=UE.FVector((spec.attenuation or {}).radius_cm or 100,0,0)
    a.FalloffDistance=(spec.attenuation or {}).falloff_cm or 900
    a.StereoSpread=0;a.bApplyNormalizationToStereoSounds=true
    c:AdjustAttenuation(a)
    v.base_volume=spec.volume or 1;v.applied_volume=nil
    apply_volume(v)
    v.configured=true
end
function M.create(v,actor,spec,category)
    v.audio_category=category or 'sfx'
    if v.component and not valid(v.component)then v.component=nil;v.configured=false end
    if not v.component then
        -- Record ownership before configuring; even partially created components
        -- remain available to retryable session cleanup.
        v.component=assert(actor:AddComponentByClass(UE.UAudioComponent:StaticClass(),true,UE.FTransform(),false),'Could not create scene audio')
        v.owner=actor;v.destroyed=false;v.configured=false;v.rate=nil;v.paused=nil;v.stopped=true
    end
    owned[v]=true
    if not v.configured then configure(v,spec)else apply_volume(v)end
end
function M.volume(v,volume)
    v.base_volume=volume;apply_volume(v)
end
function M.move(v,position)
    if v.component and not v.destroyed then
        v.component:K2_SetWorldLocation(position,false,nil,true)
    end
end
function M.pause(v,pause)
    if v.component and not v.destroyed and v.paused~=pause then
        v.component:SetPaused(pause);v.paused=pause
    end
end
function M.tune(v,requested,pause)
    local rate,source=M.rate(requested)
    if v.component and not v.destroyed then
        apply_volume(v)
        if v.rate~=rate then v.component:SetPitchMultiplier(rate)end
        M.pause(v,pause)
    end
    v.rate,v.requested,v.limit_source=rate,requested,source
    return rate
end
function M.play(v,clip,position,requested)
    -- Lua userdata can outlive an unreferenced native wave. Resolve by path for
    -- every play; IsValid alone can report an unknown/usable stale tombstone.
    -- SetSound then gives the currently playing wave a native component owner.
    local loaded=M.load(clip.path)
    clip.asset,clip.duration=loaded.asset,loaded.duration
    M.move(v,position)
    v.component:SetSound(clip.asset)
    M.tune(v,requested,false)
    -- Set ownership/state before Play, which can throw after native mutation.
    v.stopped=false;v.clip=clip;v.remaining=clip.duration;v.tail_waiting=false;v.tail_wait_seconds=0;v.tail_remaining_last=nil
    v.component:Play(0)
end
-- The duration estimate is not a playback-finished notification. Native audio
-- can start later than the frame timer, especially after live set/asset loads.
function M.finished(v)
    if not v.remaining or v.stopped then return true end
    if v.paused or v.remaining>0 then return false end
    if v.component and valid(v.component)then
        local ok,playing=pcall(function()return v.component:IsPlaying()end)
        if ok and type(playing)=='boolean'then
            if not playing then return true end
            if not v.tail_waiting then
                v.tail_waits=(v.tail_waits or 0)+1;v.tail_waiting=true;v.tail_wait_seconds=0
            else
                v.tail_wait_seconds=v.tail_wait_seconds+math.max(0,(v.tail_remaining_last or v.remaining)-v.remaining)
            end
            v.tail_remaining_last=v.remaining
            if v.tail_wait_seconds<2 then return false end
            print('[SceneZOI] Audio completion watchdog: '..tostring(v.clip and v.clip.path))
        end
    end
    -- Bound a broken/looping component and retain compatibility if native state
    -- is unavailable. Deliberate interruption still uses stop() immediately.
    return true
end
function M.stop(v)
    if v.component and not v.destroyed and not v.stopped then
        if valid(v.component)then v.component:Stop()end
        v.stopped=true
    end
    v.remaining=nil
end
function M.destroy(v)
    if v.destroyed then return end
    M.stop(v)
    if v.component and valid(v.component)then v.component:K2_DestroyComponent(v.owner)end
    v.destroyed=true;v.component=nil;owned[v]=nil
end
return M

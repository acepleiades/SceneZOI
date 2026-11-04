-- Exact integration of a speed envelope. Input time excludes this effect's own slowdown.
-- This avoids feedback, frame-rate drift and phase loss when user/native speeds change.
local M={}
local EPS=1e-9
local function ramp(a,b,t,d)
 t=math.max(0,math.min(t,d));return a*t+(b-a)*t*t/(2*d)
end
local function half(t,length,high,low,entering)
 local average=.4*high+.6*low;local duration=length/average
 t=math.max(0,math.min(t,duration))
 if entering then
  local d=duration*.8
  return ramp(high,low,math.min(t,d),d)+math.max(0,t-d)*low
 else
  local d=duration*.2
  return math.min(t,d)*low+ramp(low,high,math.max(0,t-d),duration*.8)
 end
end
local function integral(c,t,high,low)
 local middle=(c.peak-c.start)/(.4*high+.6*low)
 return half(math.min(t,middle),c.peak-c.start,high,low,true)+
  half(math.max(0,t-middle),c.finish-c.peak,high,low,false)
end
local function cycle(timing,duration,now)
 if timing.cycles_per_second then
  local p=1/timing.cycles_per_second;local phase=(timing.peak_phase or .5)*p
  local index=math.ceil((now-phase+p*.5)/p-EPS)
  return {start=index*p+phase-p*.5,peak=index*p+phase,finish=index*p+phase+p*.5}
 end
 local points=timing.peak_times;local n=#points;local loop=math.floor(now/duration);local best
 for lap=loop-1,loop+2 do for i,point in ipairs(points)do
  local previous=i>1 and points[i-1]or points[n]-duration
  local following=i<n and points[i+1]or points[1]+duration
  local p=lap*duration+point
  local candidate={start=lap*duration+(previous+point)/2,peak=p,finish=lap*duration+(point+following)/2}
  if candidate.start>=now-EPS and(not best or candidate.start<best.start)then best=candidate end
 end end
 return assert(best,'Movement cycle is unavailable')
end
function M.new(spec,timing,duration,position)
 local s={spec=spec,timing=timing,duration=duration,position=position,high=spec.high_speed or .5,
  low=spec.low_speed or 1/12,age=0,completed=0,repeats=spec.repeats or 3,recovery=spec.recovery or .4}
 if timing then
  s.cycle=cycle(timing,duration,position);s.wait=math.max(0,s.cycle.start-position);s.stage=s.wait>EPS and 'waiting'or 'cycles'
 else s.stage='fallback';s.fallback_duration=spec.fallback_duration or 6 end
 return s
end
local function fallback_integral(s,t)
 local d=s.fallback_duration;local a=d*.4;local h=d*.2
 return ramp(s.high,s.low,math.min(t,a),a)+math.min(math.max(0,t-a),h)*s.low+
  ramp(s.low,s.high,math.max(0,t-a-h),a)
end
function M.advance(s,delta)
 local total=0;local remaining=math.max(0,delta)
 while remaining>EPS and s.stage~='done'do
  local limit,old,new
  if s.stage=='waiting'then
   local step=math.min(remaining,s.wait);s.wait=s.wait-step;remaining=remaining-step;total=total+step
   if s.wait<=EPS then s.stage='cycles'end
  else
   if s.stage=='cycles'then
    limit=(s.cycle.finish-s.cycle.start)/(.4*s.high+.6*s.low)
    old=integral(s.cycle,s.age,s.high,s.low)
   elseif s.stage=='fallback'then limit=s.fallback_duration;old=fallback_integral(s,s.age)
   else limit=s.recovery;old=ramp(s.high,1,s.age,limit)end
   local step=math.min(remaining,math.max(0,limit-s.age));s.age=s.age+step;remaining=remaining-step
   if s.stage=='cycles'then new=integral(s.cycle,s.age,s.high,s.low)
   elseif s.stage=='fallback'then new=fallback_integral(s,s.age)
   else new=ramp(s.high,1,s.age,limit)end
   total=total+new-old
   if s.age>=limit-EPS then
    s.age=0
    if s.stage=='cycles'then
     s.completed=s.completed+1
     if s.completed<s.repeats then s.cycle=cycle(s.timing,s.duration,s.cycle.finish)
     else s.stage='recovery'end
    elseif s.stage=='fallback'then s.stage='recovery'
    else s.stage='done'end
   end
  end
 end
 total=total+remaining;s.position=s.position+total
 return total
end
M.cycle=cycle
return M

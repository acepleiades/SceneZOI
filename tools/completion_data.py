"""Validation of inert movement timing and task completion response data."""
from task_data import fields,number,ident

def timing(v,duration):
    if v is None:return
    fields(v,['cycles_per_second','peak_phase','peak_times'])
    if ('cycles_per_second'in v)==('peak_times'in v):raise ValueError('Choose frequency or peak_times')
    if 'cycles_per_second'in v:
        number(v['cycles_per_second'],.001,60);number(v.get('peak_phase',.5),0,1)
        count=duration*v['cycles_per_second']
        if count<1 or abs(count-round(count))>=.0001:raise ValueError('Uniform cycles must repeat across clip seam')
    else:
        if 'peak_phase'in v:raise ValueError('peak_phase applies only to uniform timing')
        times=v['peak_times']
        if not isinstance(times,list)or not 1<=len(times)<=4096:raise ValueError('Expected movement markers')
        previous=-1
        for t in times:
            number(t,0,duration)
            if t>=duration or t<=previous:raise ValueError('Markers must increase and exclude endpoint')
            previous=t

def name(v):
    if not isinstance(v,str)or not v.strip()or len(v.encode('utf-8'))>160 or any(ord(c)<32 for c in v):raise ValueError('Invalid bone name')

def responses(v,roles,kind):
    if v is None:return
    if not isinstance(v,dict):raise ValueError('Expected completion responses')
    for role,tasks in v.items():
        if role not in roles or not isinstance(tasks,dict):raise ValueError('Invalid response role')
        for task,spec in tasks.items():
            ident(task);fields(spec,['enabled','slowdown','shake'],['enabled'])
            if type(spec['enabled'])is not bool or kind=='transition':raise ValueError('Invalid response enable/kind')
            if 'slowdown'in spec:
                s=spec['slowdown'];fields(s,['repeats','high_speed','low_speed','recovery','fallback_duration'])
                for k,lo,hi in [('repeats',1,32),('high_speed',.001,1),('low_speed',.001,1),('recovery',.001,30),('fallback_duration',.01,300)]:
                    if k in s:number(s[k],lo,hi)
                if 'repeats'in s and s['repeats']%1:raise ValueError('Expected integral repeat count')
                if s.get('low_speed',1/12)>s.get('high_speed',.5):raise ValueError('Invalid speed range')
            if 'shake'in spec:
                s=spec['shake'];fields(s,['delay','duration','bursts','duty_cycle','frequency_hz','amplitude_degrees','bones'],['bones'])
                for k,lo,hi in [('delay',0,30),('duration',.01,300),('bursts',1,64),('duty_cycle',.001,1),('frequency_hz',.001,60),('amplitude_degrees',0,45)]:
                    if k in s:number(s[k],lo,hi)
                if 'bursts'in s and s['bursts']%1:raise ValueError('Expected integral burst count')
                bones=s['bones'];seen=set()
                if not isinstance(bones,list)or not 1<=len(bones)<=64:raise ValueError('Invalid shake bones')
                for b in bones:
                    fields(b,['bone','child','weight'],['bone','child']);name(b['bone']);name(b['child']);number(b.get('weight',1),-2,2)
                    if b['bone']==b['child']or b['bone']in seen:raise ValueError('Duplicate/self-target shake bone')
                    seen.add(b['bone'])
            if spec['enabled']and not any(k in spec for k in ['slowdown','shake']):raise ValueError('Enabled response has no effects')

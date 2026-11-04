"""Source validation for generic scene_task declarations and per-role rates."""
import math,re
def number(v,lo,hi):
    if isinstance(v,bool)or not isinstance(v,(int,float))or not math.isfinite(v)or not lo<=v<=hi:raise ValueError('Invalid task numeric value')
def fields(v,allowed,required=()):
    if not isinstance(v,dict)or set(v)-set(allowed)or set(required)-set(v):raise ValueError('Invalid task fields')
def ident(v):
    if not isinstance(v,str)or not re.fullmatch(r'[a-z][a-z0-9_.-]{0,95}',v):raise ValueError('Invalid task identifier')
def validate(v):
    fields(v,['schema_version','id','label','maximum','initial','decay','completion_event','display','metadata','on_completion'],['schema_version','id','label','maximum'])
    if type(v['schema_version'])is not int or v['schema_version']!=1:raise ValueError('Unsupported task schema')
    ident(v['id'])
    if not isinstance(v['label'],str)or not v['label'].strip()or len(v['label'].encode('utf-8'))>160 or any(ord(c)<32 for c in v['label']):raise ValueError('Invalid task label')
    number(v['maximum'],.001,1e9);number(v.get('initial',0),0,v['maximum']);number(v.get('decay',0),0,1e6)
    if 'completion_event'in v:ident(v['completion_event'])
    if 'metadata'in v and not isinstance(v['metadata'],dict):raise ValueError('Expected task metadata object')
    if 'display'in v:
        d=v['display'];fields(d,['visible','color','track_color','text_color','body_colors'])
        if 'visible'in d and type(d['visible'])is not bool:raise ValueError('Invalid task visibility')
        colors=[d[k]for k in ['color','track_color','text_color']if k in d]
        if 'body_colors'in d:
            fields(d['body_colors'],['male','female']);colors+=list(d['body_colors'].values())
        if any(not isinstance(c,str)or not re.fullmatch(r'#[0-9a-fA-F]{6}',c)for c in colors):raise ValueError('Expected #RRGGBB task colors')
    if 'on_completion'in v:
        actions=v['on_completion']
        if not isinstance(actions,list)or len(actions)>32:raise ValueError('Expected up to 32 task completion actions')
        for action in actions:
            fields(action,['type','when','clip','source','volume','attenuation','max_voices'],['type','clip','source'])
            if action['type']!='play_sound':raise ValueError('Unsupported task completion action')
            if not isinstance(action['clip'],str)or len(action['clip'])>512 or not re.fullmatch(r'/[A-Za-z0-9_/]+[.][A-Za-z0-9_]+',action['clip']):raise ValueError('Invalid completion sound asset')
            if 'when'in action:
                fields(action['when'],['body'])
                if 'body'in action['when']and action['when']['body']not in ['male','female']:raise ValueError('Invalid action body filter')
            source=action['source'];fields(source,['component','bones'],['component','bones'])
            if source['component']not in ['body','head']:raise ValueError('Invalid sound source component')
            bones=source['bones']
            if not isinstance(bones,list)or not 1<=len(bones)<=8 or any(not isinstance(b,str)or not b.strip()or len(b.encode('utf-8'))>160 or any(ord(c)<32 for c in b)for b in bones)or len(set(bones))!=len(bones):raise ValueError('Invalid sound source bones')
            if 'volume'in action:number(action['volume'],0,1)
            if 'max_voices'in action:
                number(action['max_voices'],1,16)
                if action['max_voices']%1:raise ValueError('Expected integral voice count')
            if 'attenuation'in action:
                fields(action['attenuation'],['radius_cm','falloff_cm'])
                for value in action['attenuation'].values():number(value,0,100000)

def directives(v,roles):
    if not isinstance(v,dict):raise ValueError('Expected participant task map')
    for role,tasks in v.items():
        if role not in roles or not isinstance(tasks,dict):raise ValueError('Invalid task participant')
        for id,spec in tasks.items():
            ident(id);fields(spec,['rate','cap_percent'],['rate']);number(spec['rate'],-1e6,1e6);number(spec.get('cap_percent',100),0,100)

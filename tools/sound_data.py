"""Neutral, declarative sound-set and emitter validation for the demo compiler."""
import copy,math,re
ID=re.compile(r'^[a-z][a-z0-9_.-]{0,95}$')
ASSET=re.compile(r'^/[A-Za-z0-9_/]+\.[A-Za-z0-9_]+$')
SPEEDS=(.5,1.,1.5,2.)
def check(value,message):
    if not value:raise ValueError(message)
def fields(value,allowed,required=()):
    check(isinstance(value,dict),'Expected sound object')
    check(not value.keys()-set(allowed),'Unknown sound fields')
    check(not set(required)-value.keys(),'Missing sound fields')
def number(value,low,high):
    check(type(value)in(int,float)and math.isfinite(value)and low<=value<=high,'Invalid sound number')
def point(value,roles):
    fields(value,('participant','component','bones'),('participant','component','bones'))
    check(isinstance(value['participant'],str)and value['participant']in roles,'Unbound sound point')
    check(isinstance(value['component'],str)and value['component']in('head','body'),'Unsupported sound point component')
    bones=value['bones'];check(isinstance(bones,list)and 1<=len(bones)<=8,'Invalid sound bones')
    check(all(isinstance(b,str)and re.fullmatch(r'[A-Za-z0-9_ .-]{1,96}',b)and b.strip()for b in bones),'Invalid sound bone name')
    check(len(set(bones))==len(bones),'Duplicate sound bones')
def clip_group(group):
    fields(group,('clips',),('clips',))
    clips=group['clips'];check(isinstance(clips,list)and 1<=len(clips)<=512,'Invalid sound clip list')
    check(all(isinstance(p,str)and ASSET.fullmatch(p)for p in clips),'Invalid sound object path')
    check(len(set(clips))==len(clips),'Duplicate sound clips')
def sound_sets(sets,pack_id):
    check(isinstance(sets,dict),'Expected sound sets')
    for name,spec in sets.items():
        check(isinstance(name,str)and ID.fullmatch(name)and name.startswith(pack_id+'.'),'Sound set must belong to its pack')
        fields(spec,('default','variants'))
        check('default'in spec or bool(spec.get('variants')),'Empty sound set')
        if 'default'in spec:clip_group(spec['default'])
        variants=spec.get('variants',[]);check(isinstance(variants,list),'Expected sound variants')
        seen=set()
        for variant in variants:
            fields(variant,('scene_speed','clips'),('scene_speed','clips'))
            speed=variant['scene_speed'];check(type(speed)in(int,float)and speed in SPEEDS and speed not in seen,'Unsupported or duplicate sound speed')
            seen.add(speed);clip_group({k:v for k,v in variant.items()if k!='scene_speed'})
    return copy.deepcopy(sets)
def emitter(spec,roles):
    fields(spec,('mode','owner','sound_set','source','distance','volume','gap','avoid_repeat','max_voices','attenuation'),('mode','owner','sound_set','source'))
    check(isinstance(spec['mode'],str)and spec['mode']in('bone_distance','continuous'),'Unknown SFX mode')
    check(isinstance(spec['owner'],str)and spec['owner']in roles,'Unbound sound owner')
    check(isinstance(spec['sound_set'],str)and ID.fullmatch(spec['sound_set']),'Invalid sound-set ID')
    sources=spec['source'];check(isinstance(sources,list)and 1<=len(sources)<=8,'Invalid emitter source')
    for p in sources:point(p,roles)
    number(spec.get('volume',1),0,1);number(spec.get('gap',0),0,60)
    check(type(spec.get('avoid_repeat',True))is bool,'Invalid repeat flag')
    n=spec.get('max_voices',4);check(type(n)is int and 1<=n<=16,'Invalid emitter polyphony')
    if spec['mode']=='bone_distance':
        d=spec.get('distance');fields(d,('from','to','max_distance_cm','min_delta_cm','cooldown','sample_interval'),('from','to'))
        point(d['from'],roles);point(d['to'],roles)
        number(d.get('max_distance_cm',30),.001,100000);number(d.get('min_delta_cm',.1),.000001,1000)
        number(d.get('cooldown',.15),0,60);number(d.get('sample_interval',1/60),.001,1)
    else:check('distance'not in spec,'Continuous sound cannot declare a detector')
    a=spec.get('attenuation',{});fields(a,('radius_cm','falloff_cm'))
    number(a.get('radius_cm',100),0,100000);number(a.get('falloff_cm',900),.001,100000)
    return copy.deepcopy(spec)
def emitters(value,roles):
    check(isinstance(value,dict),'Expected named SFX emitters')
    for name,spec in value.items():
        check(isinstance(name,str)and ID.fullmatch(name),'Invalid emitter ID')
        emitter(spec,roles)
    return copy.deepcopy(value)

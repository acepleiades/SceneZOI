"""Validated case-insensitive expression definitions; files may contribute to one set."""
import copy,json,math
from pathlib import Path

def key(value):
    if not isinstance(value,str) or not 0<len(value.strip())<=96 or any(ord(c)<32 or ord(c)>126 for c in value):
        raise ValueError('Expression identifiers must be nonempty printable ASCII strings (up to 96 characters)')
    return value.strip().lower()

def unique_object(pairs):
    result={}
    for name,value in pairs:
        if name in result:raise ValueError('Duplicate JSON key: '+name)
        result[name]=value
    return result

def compile_expression_sets(paths):
    from build_catalog import fields,label,path,check
    sets,metadata,aliases={}, {}, {}
    for source in sorted(map(Path,paths),key=lambda p:str(p).lower()):
        data=json.loads(source.read_text(encoding='utf-8-sig'),object_pairs_hook=unique_object)
        fields(data,['schema_version','id','label','body','default','contexts','aliases'],['schema_version','id','body','contexts'])
        check(type(data['schema_version'])is int and data['schema_version']==2,'Unsupported expression schema')
        id=key(data['id']);body=data['body'];check(body in('male','female'),'Unsupported expression body')
        check(type(data.get('default',False))is bool,'Invalid expression default')
        check(isinstance(data['contexts'],dict),'Expected expression contexts')
        check(len(data['contexts'])<=256,'Too many expression contexts')
        target=sets.setdefault(id,{'id':id,'body':body,'contexts':{},'default':False})
        check(target['body']==body,'Conflicting expression body for '+id)
        meta=metadata.setdefault(id,{'contexts':{},'aliases':set()})
        if 'label'in data:
            label(data['label']);check('label'not in target or target['label']==data['label'],'Conflicting expression display label')
            target['label']=data['label']
        if data.get('default'):target['default']=True
        raw_aliases=data.get('aliases',[]);check(isinstance(raw_aliases,list)and len(raw_aliases)<=64,'Invalid expression aliases')
        for alias in raw_aliases:meta['aliases'].add(key(alias))
        seen=set()
        for name,spec in data['contexts'].items():
            context=key(name);check(context not in seen,'Duplicate case-insensitive context in one file');seen.add(context)
            fields(spec,['hold','transition','options'],['options'])
            if 'hold'in spec:
                hold=spec['hold'];check(isinstance(hold,list)and len(hold)==2 and all(type(v)in(int,float)and math.isfinite(v)for v in hold)and .1<=hold[0]<=hold[1]<=120,'Invalid expression hold range')
            if 'transition'in spec:check(type(spec['transition'])in(int,float)and math.isfinite(spec['transition'])and 0<=spec['transition']<=10,'Invalid expression transition')
            check(isinstance(spec['options'],list)and 1<=len(spec['options'])<=256,'Invalid expression options')
            dst=target['contexts'].setdefault(context,{'options':[]})
            cm=meta['contexts'].setdefault(context,{})
            for setting in ['hold','transition']:
                if setting in spec:
                    check(setting not in cm or cm[setting]==spec[setting],'Conflicting expression context '+setting)
                    cm[setting]=copy.deepcopy(spec[setting])
            known={(o['animation'],o['sample']):o for o in dst['options']}
            for option in spec['options']:
                fields(option,['animation','weight','label','sample'],['animation'])
                path(option['animation']);caption=option.get('label',option['animation'].split('.')[-1]);label(caption)
                weight,sample=option.get('weight',1),option.get('sample',0)
                check(type(weight)in(int,float)and math.isfinite(weight)and 0<weight<=100,'Invalid expression weight')
                check(type(sample)in(int,float)and math.isfinite(sample)and 0<=sample<=120,'Invalid expression sample')
                normalized={'animation':option['animation'],'label':caption,'weight':weight,'sample':sample,'animated':'sample'not in option}
                identity=(normalized['animation'],sample)
                check(identity not in known or known[identity]==normalized,'Conflicting duplicate expression clip')
                if identity not in known:dst['options'].append(normalized);known[identity]=normalized
            check(len(dst['options'])<=256,'Too many merged expression options')
    defaults={};contexts=set()
    for id,spec in sorted(sets.items()):
        spec.setdefault('label',id)
        for name,group in spec['contexts'].items():
            contexts.add(name);cm=metadata[id]['contexts'][name]
            group['hold']=cm.get('hold',[5,11]);group['transition']=cm.get('transition',.35)
            group['options'].sort(key=lambda o:(o['animation'],o['sample'],o['label'],o['weight']))
        for alias in sorted(metadata[id]['aliases']):
            check(alias not in sets or alias==id,'Expression alias conflicts with a set')
            check(alias not in aliases or aliases[alias]==id,'Conflicting expression alias')
            if alias!=id:aliases[alias]=id
        if spec['default']:
            check(spec['body']not in defaults,'Duplicate expression body default');defaults[spec['body']]=id
    for body in ['male','female']:
        candidates=sorted(id for id,s in sets.items()if s['body']==body)
        if candidates and body not in defaults:defaults[body]=candidates[0]
    return {'schema_version':2,'contexts':sorted(contexts),'sets':dict(sorted(sets.items())),'defaults':defaults,'aliases':aliases}

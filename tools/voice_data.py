"""Generic declaration checks, shared by independent content author builds."""
import math
from expression_data import key


def validate(kind, data):
    common = {'schema_version', 'id', 'label'}
    required = set(common)
    allowed = set(common)
    if kind == 'voice_archetype':
        required |= {'body'}
        allowed |= {'body', 'default'}
        if 'default' in data and type(data['default']) is not bool:
            raise ValueError('Invalid voice default')
    elif kind == 'voice_set':
        required |= {'body', 'archetype', 'context', 'clips'}
        allowed |= required | {'volume', 'gap', 'responses'}
        key(data.get('archetype')); key(data.get('context'))
        clips = data.get('clips')
        import re
        if not isinstance(clips, list) or not 1 <= len(clips) <= 512 or any(not isinstance(p, str) or not re.fullmatch(r'/[A-Za-z0-9_/]+\.[A-Za-z0-9_]+', p) for p in clips) or len(set(clips)) != len(clips):
            raise ValueError('Invalid voice clips')
        for field, high, default in [('volume', 1, 1), ('gap', 60, 0)]:
            value = data.get(field, default)
            if type(value) not in (float, int) or not math.isfinite(value) or not 0 <= value <= high:
                raise ValueError('Invalid voice ' + field)
        if 'responses' in data:
            from task_data import fields,number
            groups=data['responses']
            if not isinstance(groups,dict)or len(groups)>64:raise ValueError('Expected named voice responses')
            seen=set()
            for name,group in groups.items():
                normalized=key(name)
                if normalized in seen:raise ValueError('Duplicate response name')
                seen.add(normalized);fields(group,['clips','volume'],['clips'])
                clips=group['clips']
                if not isinstance(clips,list)or not 1<=len(clips)<=512 or any(not isinstance(p,str)or not re.fullmatch(r'/[A-Za-z0-9_/]+[.][A-Za-z0-9_]+',p)for p in clips)or len(set(clips))!=len(clips):raise ValueError('Invalid response clips')
                if 'volume'in group:number(group['volume'],0,1)
    elif kind != 'voice_context':
        raise ValueError('Unknown voice declaration kind')
    if not isinstance(data, dict) or set(data) - allowed or required - set(data) or type(data['schema_version']) is not int or data['schema_version'] != 1:
        raise ValueError('Invalid voice declaration')
    key(data['id'])
    label = data['label']
    if not isinstance(label, str) or not label.strip() or len(label.encode('utf-8')) > 160 or any(ord(c) < 32 for c in label):
        raise ValueError('Invalid voice label')
    if kind != 'voice_context' and data['body'] not in ('female', 'male'):
        raise ValueError('Invalid voice body')
    return data

def completion_rules(value,roles):
    from task_data import fields,number,ident
    if not isinstance(value,dict):raise ValueError('Expected task voice response map')
    for role,tasks in value.items():
        if role not in roles or not isinstance(tasks,dict):raise ValueError('Invalid completing voice role')
        for task,rules in tasks.items():
            ident(task)
            if not isinstance(rules,list)or len(rules)>32:raise ValueError('Invalid voice response rules')
            for rule in rules:
                fields(rule,['participant','context','response','fade_out','priority'],['participant','context','response'])
                if rule['participant']not in roles:raise ValueError('Invalid response speaker')
                key(rule['context']);key(rule['response'])
                if 'fade_out'in rule:number(rule['fade_out'],0,5)
                if 'priority'in rule:
                    number(rule['priority'],-1000,1000)
                    if rule['priority']%1:raise ValueError('Expected integral response priority')

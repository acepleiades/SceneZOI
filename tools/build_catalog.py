"""Validate inert author data and stage each owner's native declaration patches.

Runtime discovers enabled ModKit packages; no Lua/JavaScript catalog is generated.
References to absent independent packs are resolved by the runtime after discovery.
"""
import argparse
import copy
import hashlib
import json
import math
import re
from pathlib import Path
import sound_data
from pack_sources import load_pack

ID = re.compile(r'^[a-z][a-z0-9_.-]*$')
ASSET = re.compile(r'^/[A-Za-z0-9_/]+\.[A-Za-z0-9_]+$')
SLOTS = {'Top', 'Bottom', 'Full', 'Jacket', 'Shoes', 'Socks', 'InnerTop', 'InnerUnder',
         'Stockings', 'Gloves', 'Scarf'}


def check(condition, message):
    if not condition:
        raise ValueError(message)


def fields(value, allowed, required):
    check(isinstance(value, dict), 'Expected an object')
    check(not value.keys() - set(allowed), f'Unknown fields: {value.keys() - set(allowed)}')
    check(not set(required) - value.keys(), f'Missing fields: {set(required) - value.keys()}')


def identifier(value):
    check(isinstance(value, str) and bool(ID.fullmatch(value)) and len(value) <= 96, 'Invalid identifier')


def label(value):
    check(isinstance(value, str) and 0 < len(value) <= 100 and value.strip()
          and not any(ord(c) < 32 for c in value), 'Invalid label')


def path(value):
    check(isinstance(value, str) and bool(ASSET.fullmatch(value)), 'Invalid Unreal object path')


def edge(value):
    fields(value, ['id', 'label', 'target'], ['id', 'target'])
    identifier(value['id']); identifier(value['target'])
    # Missing, null, empty and whitespace-only captions use the destination name.
    if value.get('label') is not None:
        caption = value['label']
        check(isinstance(caption, str) and len(caption) <= 100
              and not any(ord(c) < 32 for c in caption), 'Invalid navigation label')


def compile_packs(packs, link=True):
    nodes, pack_ids, extensions, attachment_extensions = {}, set(), [], []
    sounds = {}
    for pack in packs:
        fields(pack, ['schema_version', 'id', 'nodes', 'extensions', 'attachment_extensions', 'sound_sets', 'expression_files', 'data_files'], ['schema_version', 'id', 'nodes', 'extensions'])
        check(isinstance(pack.get('expression_files',[]),list)and all(isinstance(x,str)for x in pack.get('expression_files',[])), 'Invalid expression_files list')
        check(type(pack['schema_version']) is int and pack['schema_version'] == 3, 'Unsupported schema version')
        identifier(pack['id'])
        check(pack['id'] not in pack_ids, 'Duplicate pack ID')
        pack_ids.add(pack['id'])
        declared_sounds = sound_data.sound_sets(pack.get('sound_sets', {}), pack['id'])
        check(not sounds.keys() & declared_sounds.keys(), 'Duplicate sound set ID')
        sounds.update(declared_sounds)
        check(isinstance(pack['nodes'], list) and isinstance(pack['extensions'], list), 'Expected pack arrays')
        for node in pack['nodes']:
            fields(node, ['id', 'label', 'kind', 'destination', 'hub', 'duration', 'fps', 'participants', 'anchor_participant',
                          'tracks', 'outfits', 'attachments', 'gaze', 'expressions', 'voices', 'tasks', 'task_completion_routes', 'movement_timing', 'completion_responses', 'task_completion_voices', 'sfx', 'navigation', 'starting_hub', 'furniture', 'tags', 'participant_tags', 'actions', 'addon_data', 'participant_addon_data'],
                   ['id', 'label', 'kind', 'duration', 'fps', 'participants', 'anchor_participant', 'tracks', 'navigation'])
            from scene_metadata import validate_scene
            validate_scene(node)
            from furniture_data import scene as furniture_scene
            furniture_scene(node.get('furniture'))
            identifier(node['id']); label(node['label'])
            check(node['id'].startswith(pack['id'] + '.'), 'Node must belong to its pack namespace')
            check(node['id'] not in nodes, 'Duplicate node ID')
            check(node['kind'] in ('loop','transition'), 'Unsupported scene kind')
            if node['kind']=='transition':
                identifier(node.get('destination'))
                check(node['destination']!=node['id'], 'Transition cannot target itself')
                check(not node.get('starting_hub') and 'hub'not in node, 'Transitions cannot be starting scenes or hubs')
                check(node['navigation']==[], 'Transition navigation must be empty')
            else:check('destination'not in node, 'Loop scene cannot declare a transition destination')
            if 'starting_hub'in node:check(type(node['starting_hub'])is bool,'Invalid starting_hub flag')
            if 'hub' in node:
                identifier(node['hub'])
            check(type(node['duration']) in (int, float) and math.isfinite(node['duration']) and node['duration'] > 0,
                  'Invalid duration')
            check(type(node['fps']) in (int, float) and math.isfinite(node['fps']) and 0 < node['fps'] <= 240, 'Invalid fps')
            participants = node['participants']
            check(isinstance(participants, dict) and len(participants) >= 1, 'Nodes require participant roles')
            for role, requirement in participants.items():
                identifier(role)
                fields(requirement, ['body','body_age','growth_steps'], ['body'])
                if 'body_age'in requirement:label(requirement['body_age'])
                if 'growth_steps'in requirement:
                    check(isinstance(requirement['growth_steps'],list)and requirement['growth_steps']and len(set(requirement['growth_steps']))==len(requirement['growth_steps']),'Invalid growth requirements')
                    for step in requirement['growth_steps']:label(step)
                check(requirement['body'] in ('male', 'female'), 'Unsupported demo body type')
            check(node['anchor_participant'] in participants, 'Anchor must name a declared participant')
            fields(node['tracks'], participants.keys(), participants.keys())
            for value in node['tracks'].values():
                path(value)
            sound_data.emitters(node.get('sfx',{}),participants)
            voices = node.get('voices', {})
            fields(voices, participants.keys(), [])
            from expression_data import key as voice_key
            for instruction in voices.values():
                fields(instruction, ['context'], ['context'])
                voice_key(instruction['context'])
            expressions = node.get('expressions', {})
            fields(expressions, participants.keys(), [])
            for instruction in expressions.values():
                fields(instruction, ['context','facial_pose'], [])
                check(bool(instruction),'Empty expression instruction')
                from expression_data import key as expression_key
                if 'context'in instruction:expression_key(instruction['context'])
                if 'facial_pose'in instruction:identifier(instruction['facial_pose'])
            gaze = node.get('gaze', {})
            fields(gaze, participants.keys(), [])
            for target in gaze.values():
                fields(target, ['participant', 'component', 'bones'], ['participant', 'component', 'bones'])
                identifier(target['participant'])
                check(target['participant'] in participants, 'Gaze target must name a declared participant')
                check(target['component'] in ('head', 'body'), 'Unsupported gaze target component')
                bones = target['bones']
                check(isinstance(bones, list) and 1 <= len(bones) <= 8, 'Gaze needs one to eight target bones')
                check(all(isinstance(b, str) and re.fullmatch(r'[A-Za-z0-9_ .-]{1,96}', b) and b.strip() for b in bones),
                      'Invalid gaze target bone')
                check(len(bones) == len(set(bones)), 'Duplicate gaze target bone')
            outfits = node.get('outfits', {})
            fields(outfits, participants.keys(), [])
            for instruction in outfits.values():
                fields(instruction, ['remove_slots'], ['remove_slots'])
                slots = instruction['remove_slots']
                check(isinstance(slots, list) and all(isinstance(x, str) for x in slots), 'Invalid outfit slot array')
                check(len(slots) == len(set(slots)) and set(slots) <= SLOTS, 'Unsupported or duplicate outfit slots')
            from voice_data import completion_rules
            completion_rules(node.get('task_completion_voices',{}),participants)
            import completion_data
            completion_data.timing(node.get('movement_timing'),node['duration'])
            completion_data.responses(node.get('completion_responses'),participants,node['kind'])
            from task_data import directives
            directives(node.get('tasks', {}), participants)
            routes=node.get('task_completion_routes', {})
            fields(routes,participants.keys(),[])
            for mapping in routes.values():
                check(isinstance(mapping,dict),'Expected task-to-scene map')
                for task,target in mapping.items():identifier(task);identifier(target)
            check(isinstance(node.get('attachments', {}), dict), 'Expected named attachments')
            profiled_owners = set()
            for attachment_id, spec in node.get('attachments', {}).items():
                identifier(attachment_id)
                fields(spec, ['participant', 'component', 'socket', 'reference_bone', 'mesh', 'animation', 'body_profile', 'material_profile',
                              'when_undressed', 'retain_for_session', 'retained_tracks'],
                       ['participant', 'socket', 'reference_bone', 'mesh'])
                check(spec['participant'] in participants, 'Unbound attachment owner')
                check(spec.get('component','body')in('body','head'),'Invalid attachment component')
                check(not(spec.get('body_profile')and spec.get('component')=='head'),'Body-region replacement requires body attachment')
                # The verified adapter aligns these bones; other attachment layouts need an adapter.
                label(spec['socket']);label(spec['reference_bone'])
                path(spec['mesh'])
                if 'animation' in spec:
                    path(spec['animation'])
                if 'body_profile' in spec:
                    check(spec['participant'] not in profiled_owners, 'Only one body-region adapter may own a participant')
                    profiled_owners.add(spec['participant'])
                    identifier(spec['body_profile'])
                if 'material_profile' in spec:
                    identifier(spec['material_profile']);check(spec.get('body_profile'),'Material profile needs a source region')
                for flag in ['when_undressed', 'retain_for_session']:
                    if flag in spec:
                        check(type(spec[flag]) is bool, 'Attachment conditions must be booleans')
                if 'retained_tracks' in spec:
                    check(spec.get('retain_for_session') and isinstance(spec['retained_tracks'], dict),
                          'Retained tracks require a session-owned attachment')
                    for target, animation in spec['retained_tracks'].items():
                        identifier(target); path(animation)
                check(not spec.get('body_profile') or spec['participant'] in outfits or spec.get('when_undressed'),
                      'Body preparation requires an outfit directive or undressed-owner condition')
            check(isinstance(node['navigation'], list), 'Expected navigation array')
            for item in node['navigation']:
                edge(item)
            nodes[node['id']] = copy.deepcopy(node)
            for instruction in nodes[node['id']].get('voices', {}).values():
                instruction['context'] = voice_key(instruction['context'])
            for instruction in nodes[node['id']].get('expressions', {}).values():
                if 'context'in instruction:instruction['context'] = expression_key(instruction['context'])
            nodes[node['id']]['navigation'] = [dict(item) for item in node['navigation']]
        for extension in pack['extensions']:
            fields(extension, ['hub', 'id', 'label', 'target'], ['hub', 'id', 'target'])
            identifier(extension['hub'])
            edge({k: v for k, v in extension.items() if k != 'hub'})
            check(extension['id'].startswith(pack['id'] + '.'), 'Extension ID must belong to its pack')
            extensions.append(extension)
        check(isinstance(pack.get('attachment_extensions', []), list), 'Expected attachment extension array')
        for extension in pack.get('attachment_extensions', []):
            fields(extension, ['hub', 'source', 'attachment', 'participant'], ['hub', 'source', 'attachment', 'participant'])
            identifier(extension['attachment']); identifier(extension['participant'])
            identifier(extension['hub']); identifier(extension['source'])
            check(extension['source'].startswith(pack['id'] + '.'), 'Attachment extension source must belong to its pack')
            attachment_extensions.append(extension)
    for extension in extensions:
        hub = nodes.get(extension['hub'])
        if not hub and not link:continue
        check(hub and hub.get('hub'), 'Navigation extension must reference a registered hub')
        hub['navigation'].append({k: v for k, v in extension.items() if k != 'hub'})
    for extension in attachment_extensions:
        hub, source = nodes.get(extension['hub']), nodes.get(extension['source'])
        check(hub and hub.get('hub'), 'Attachment extension must reference a registered hub')
        key = extension['attachment']
        check(source and key in source.get('attachments', {}), 'Attachment extension source has no named attachment')
        check(key not in hub.get('attachments', {}), 'Conflicting hub attachment providers')
        spec = copy.deepcopy(source['attachments'][key])
        check(spec.get('when_undressed') and spec.get('retain_for_session'), 'Hub attachment extensions must be conditional and session-owned')
        check(hub['id'] in spec.get('retained_tracks', {}), 'Hub attachment extension has no matching track')
        role = extension['participant']
        check(role in hub['participants'] and hub['participants'][role] == source['participants'][spec['participant']],
              'Attachment extension must explicitly name a compatible hub role')
        spec['participant'] = role
        spec['animation'] = spec['retained_tracks'][hub['id']]
        hub.setdefault('attachments', {})[key] = spec
    checked,visiting=set(),set()
    def transition_path(node):
        if node['kind']!='transition' or node['id']in checked:return
        check(node['id']not in visiting,'Cyclic automatic transition path')
        visiting.add(node['id'])
        target=nodes.get(node['destination'])
        if target is None:check(not link, 'Unknown transition destination '+node['destination'])
        else:
            check(target['participants']==node['participants'] and target.get('furniture')==node.get('furniture'),'Transition destination must preserve fixed roles and placement')
            transition_path(target)
        visiting.remove(node['id']);checked.add(node['id'])
    for node in nodes.values():transition_path(node)
    for node in nodes.values():
        for mapping in node.get('task_completion_routes',{}).values():
            for target_id in mapping.values():
                target=nodes.get(target_id)
                if target is None:check(not link,'Unknown task route target '+target_id)
                else:check(target['participants']==node['participants'] and target.get('furniture')==node.get('furniture'),'Task route must preserve fixed roles and placement')
    for node in nodes.values():
        for emitter in node.get('sfx',{}).values():
            if link:check(emitter['sound_set'] in sounds,'Unknown sound set')
        profiled = set()
        for attachment_id, spec in node.get('attachments', {}).items():
            if spec.get('body_profile'):
                check(spec['participant'] not in profiled, 'Only one body-region adapter may own a participant')
                profiled.add(spec['participant'])
        for spec in node.get('attachments', {}).values():
            for target in spec.get('retained_tracks', {}):
                if link:check(target in nodes, 'Unknown retained-track target ' + target)
        seen = set()
        for item in node['navigation']:
            check(item['id'] not in seen, 'Duplicate navigation ID on ' + node['id'])
            seen.add(item['id'])
            if item['target']not in nodes and not link:continue
            check(item['target'] in nodes, 'Unknown navigation target ' + item['target'])
            check(nodes[item['target']]['participants'] == node['participants'] and nodes[item['target']].get('furniture') == node.get('furniture'),
                  'Navigation must preserve fixed session roles and body requirements')
            if not (item.get('label') or '').strip():
                item['label'] = nodes[item['target']]['label']
    canonical = json.dumps({'nodes':nodes,'sound_sets':sounds}, sort_keys=True, separators=(',', ':')).encode()
    return {'schema_version': 3, 'digest': hashlib.sha256(canonical).hexdigest(), 'nodes': nodes, 'sound_sets':sounds}


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in sorted(value.items())) + '}'
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, str):
        # JSON escaping is also valid for the restricted source strings accepted above.
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if value is None:
        return 'nil'
    return str(value)


def build(pack_paths, project, expression_paths=None, expression_project=None, projects=None):
    packs=[load_pack(p)for p in pack_paths]
    catalog=compile_packs(packs,link=False)
    check(not any(p.get("attachment_extensions")for p in packs),"Use coverage_attachment data instead of retired attachment_extensions")
    from expression_data import compile_expression_sets
    from data_files import expression_sources,pack_documents,prepare_documents,write,retire_shared
    sources=expression_sources(pack_paths,expression_paths)
    compile_expression_sets([source for _,source in sources])
    documents=pack_documents(pack_paths,expression_paths,packs=packs)
    from voice_data import validate as validate_voice
    voice_ids = {}
    for owner, kind, source, data in documents:
        if kind in ('voice_archetype','voice_context','voice_set'):
            validate_voice(kind, data)
            ident = (kind, data['id'].strip().lower())
            check(ident not in voice_ids or voice_ids[ident] == data, 'Conflicting voice declaration')
            voice_ids[ident] = data
    from facial_pose_data import validate as validate_pose
    pose_ids = {}
    for owner, kind, source, data in documents:
        if kind == 'facial_pose':
            validate_pose(data,owner)
            check(data['id']not in pose_ids or pose_ids[data['id']]==data,'Conflicting facial pose')
            pose_ids[data['id']]=data
    from task_data import validate as validate_task
    task_ids = {}
    for owner, kind, source, data in documents:
        if kind == 'scene_task':
            validate_task(data)
            check(data['id'] not in task_ids or task_ids[data['id']] == data, 'Conflicting task declaration')
            task_ids[data['id']] = data
    from furniture_data import profile as furniture_profile
    furniture_ids, furniture_objects = {}, {}
    for owner, kind, source, data in documents:
        if kind == 'furniture_profile':
            furniture_profile(data)
            check(data['id'] not in furniture_ids or furniture_ids[data['id']] == data, 'Conflicting furniture profile')
            furniture_ids[data['id']] = data
            for item in data['objects']:
                check(item not in furniture_objects or furniture_objects[item] == data, 'Conflicting furniture object')
                furniture_objects[item] = data
    from scene_metadata import builtin_documents,dictionaries,validate_scene
    registry=dictionaries(builtin_documents()+documents)
    for pack in packs:
        for node in pack['nodes']:validate_scene(node,registry)
    owners={p['id']for p in packs}
    if projects is not None:mapping=dict(projects)
    elif len(owners)==1:
        owner=next(iter(owners));mapping={owner:expression_project if owner!='scenezoi'and expression_project is not None else project}
    else:mapping={'scenezoi':project}
    foreign={owner for owner,_,_,_ in documents if owner not in mapping}
    if foreign:
        if expression_project is None or len(foreign)!=1:raise ValueError('Each content owner requires a separate project')
        mapping[next(iter(foreign))]=expression_project
    selected={p['id']for p in packs}
    targets=[mapping[owner].resolve()for owner in selected]
    if len(set(targets))!=len(targets):raise ValueError('Content owners require distinct projects')
    plans={owner:prepare_documents([d for d in documents if d[0]==owner])for owner in selected}
    # Source validation and all ownership decisions precede output changes.
    for owner in sorted(selected):
        target=mapping[owner];retire_shared(target);write(target,plans[owner])
    return catalog


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[1]
    parser.add_argument('--packs', nargs='+', type=Path)
    parser.add_argument('--project', type=Path, default=root / 'modkit/SceneZOI_93C44199')
    parser.add_argument('--expression-sets', nargs='+', type=Path)
    parser.add_argument('--expression-project','--content-project', type=Path, help='Optional second owner project for a multi-pack author build')
    args = parser.parse_args()
    result = build(args.packs or sorted((root / 'packs').glob('*.json')), args.project, args.expression_sets, args.expression_project)
    print(f'Built {len(result["nodes"])} nodes; catalog {result["digest"][:12]}')

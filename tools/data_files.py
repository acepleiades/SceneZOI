"""Wrap pack-owned inert declarations in native data-mod patches.

The ownership inventory is for packaging only; runtime enumerates native rows.
"""
import hashlib,json,re
from pathlib import Path

def expression_sources(pack_paths,overrides=None):
    entries=[]
    for pack_path in pack_paths:
        pack=json.loads(pack_path.read_text(encoding='utf-8'))
        for relative in pack.get('expression_files',[]):
            if not isinstance(relative,str):raise ValueError('Invalid expression file path')
            source=(pack_path.parent/relative).resolve()
            if not source.is_relative_to(pack_path.parent.resolve())or source.suffix.lower()!='.json':
                raise ValueError('Expression file must stay inside pack source directory')
            entries.append((pack['id'],source))
    if overrides is not None:
        owners={source:owner for owner,source in entries}
        entries=[(owners.get(Path(source).resolve(),'custom'),Path(source).resolve())for source in overrides]
    return entries


PREFIX='SceneZOI_Declaration_'
PATCH='Content/JsonPatch/Text_UI_patch.json'


def prepare_documents(documents):
    plan={}
    for owner,kind,source,data in documents:
        name=PREFIX+owner+'__'+kind+'__'+source.stem.lower()
        if not re.fullmatch(r'[A-Za-z0-9_.-]{1,240}',name):raise ValueError('Invalid declaration row ID')
        if name.lower() in {key.lower()for key in plan}:raise ValueError('Duplicate declaration row ID: '+name)
        if not isinstance(data,dict):raise ValueError('Declaration data must be an object')
        envelope={'schema_version':1,'kind':kind,'owner':owner,'data':data}
        payload=json.dumps(envelope,ensure_ascii=False,separators=(',',':'),allow_nan=False)
        if len(payload.encode('utf-8'))>1048576:raise ValueError('Declaration exceeds 1 MiB: '+name)
        plan[name]={'payload':payload,'owner':owner,'kind':kind,'source':source.name}
    return plan


def prepare(expressions):
    from expression_data import unique_object
    return prepare_documents([(owner,'expression_set',source,json.loads(source.read_text(encoding='utf-8-sig'),object_pairs_hook=unique_object))for owner,source in expressions])


def pack_documents(pack_paths,expression_overrides=None,packs=None):
    from expression_data import unique_object
    sources=expression_sources(pack_paths,expression_overrides)
    documents=[(owner,'expression_set',source,json.loads(source.read_text(encoding='utf-8-sig'),object_pairs_hook=unique_object))for owner,source in sources]
    from pack_sources import load_pack
    resolved=packs if packs is not None else [load_pack(path)for path in pack_paths]
    for path,pack in zip(pack_paths,resolved):
        payload={k:v for k,v in pack.items()if k not in ['expression_files','data_files']}
        documents.append((pack['id'],'scene_pack',path,payload))
        for entry in pack.get('data_files',[]):
            if not isinstance(entry,dict)or set(entry)!= {'kind','file'}:raise ValueError('Invalid data_files entry')
            kind=entry['kind']
            if not isinstance(kind,str)or not re.fullmatch(r'[a-z][a-z0-9_.-]{0,95}',kind):raise ValueError('Invalid data kind')
            source=(path.parent/entry['file']).resolve()
            if not source.is_relative_to(path.parent.resolve())or source.suffix.lower()!='.json':raise ValueError('Data source must stay inside its pack directory')
            data=json.loads(source.read_text(encoding='utf-8-sig'),object_pairs_hook=unique_object)
            documents.append((pack['id'],kind,source,data))
    return documents


def retire_shared(project):
    inventory=project/'workspace/data_files.json'
    previous=json.loads(inventory.read_text(encoding='utf-8'))if inventory.exists()else {'files':[]}
    if previous.get('transport')=='native_table':return
    for entry in previous['files']:
        target=(project/entry['path']).resolve()
        if not target.is_relative_to((project/'scenezoi_data').resolve())or target.suffix!='.cfg':
            raise ValueError('Framework unexpectedly owns declaration data')
        target.unlink(missing_ok=True)
    inventory.parent.mkdir(parents=True,exist_ok=True)
    inventory.write_text(json.dumps({'schema_version':2,'transport':'native_table','files':[]},indent=2)+'\n',encoding='utf-8')


def write(project,plan):
    inventory=project/'workspace/data_files.json'
    previous=json.loads(inventory.read_text(encoding='utf-8'))if inventory.exists()else {'files':[],'records':[]}
    target=project/PATCH
    patch=json.loads(target.read_text(encoding='utf-8-sig'))if target.exists()else None
    if patch is None:
        metadata=list((project/'Meta').glob('*.mod'))
        if len(metadata)==1:version=json.loads(metadata[0].read_text(encoding='utf-8-sig'))['LastModified']
        else:version=json.loads((project/'workspace/native_version.json').read_text(encoding='utf-8'))['version']
        patch={'Struct':'Text','BaseVersion':version,'SaveVersion':version,'PatchList':[]}
    if patch.get('Struct')!='Text':raise ValueError('Unexpected native declaration patch type')
    owned={row['id'].lower()for row in previous.get('records',[])}|{name.lower()for name in plan}
    retained=[]
    for item in patch['PatchList']:
        value=item.get('Value',{})
        name=value.get('Id','')if isinstance(value,dict)else ''
        if name.lower()not in owned:retained.append(item)
        elif item.get('Method')!='Append'or item.get('Query')!='Text_UI':
            raise ValueError('Owned declaration is not a native row append')
    records=[]
    for name,entry in sorted(plan.items()):
        retained.append({'Method':'Append','Query':'Text_UI','Value':{'Id':name,'Text':entry['payload']},'Enabled':True})
        records.append(dict(id=name,**{key:value for key,value in entry.items()if key!='payload'}))
    patch['PatchList']=retained
    files=[]
    if retained:
        raw=(json.dumps(patch,ensure_ascii=False,indent=2)+'\n').encode('utf-8')
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        files=[{'path':PATCH,'sha256':hashlib.sha256(raw).hexdigest()}]
    elif target.exists():target.unlink()
    inventory.parent.mkdir(parents=True,exist_ok=True)
    inventory.write_text(json.dumps({'schema_version':2,'transport':'native_table','files':files,'records':records},indent=2)+'\n',encoding='utf-8')

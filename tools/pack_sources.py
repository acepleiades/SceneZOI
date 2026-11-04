"""Expand author-only scene folders into the existing inert scene-pack format."""
import json
from pathlib import Path
from expression_data import unique_object

def read_object(path):
    value=json.loads(path.read_text(encoding='utf-8-sig'),object_pairs_hook=unique_object)
    if not isinstance(value,dict):raise ValueError('Expected JSON object: '+str(path))
    return value

def load_pack(path):
    path=Path(path).resolve()
    pack=read_object(path)
    if 'scene_directory'not in pack:return pack
    if 'nodes'in pack:raise ValueError('Choose scene_directory or inline nodes, not both: '+str(path))
    relative=pack['scene_directory']
    if not isinstance(relative,str)or not relative.strip()or Path(relative).is_absolute():
        raise ValueError('scene_directory must be a relative folder: '+str(path))
    folder=(path.parent/relative).resolve()
    if folder==path.parent or not folder.is_relative_to(path.parent)or not folder.is_dir():
        raise ValueError('scene_directory must exist inside the pack source directory: '+str(path))
    sources=sorted((p for p in folder.rglob('*')if p.is_file()and p.suffix.lower()=='.json'),
                   key=lambda p:(p.relative_to(folder).as_posix().casefold(),p.relative_to(folder).as_posix()))
    if len(sources)>512:raise ValueError('Too many scene files (maximum 512): '+str(folder))
    nodes=[]
    for source in sources:
        if not source.resolve().is_relative_to(folder):raise ValueError('Scene file escapes its directory: '+str(source))
        nodes.append(read_object(source))
    # Preserve field order too: the new source layout need not change packaged bytes.
    return {('nodes'if k=='scene_directory'else k):(nodes if k=='scene_directory'else v)for k,v in pack.items()}

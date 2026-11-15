"""SceneZOI version metadata and author dependencies for native packaging."""
import copy
import json
import re
from pathlib import Path


RELEASE_MODULE = Path('B1/SceneZOI/ReleaseVersion.lua')


def release_module_source(descriptor):
    version = json.loads(descriptor.read_text(encoding='utf-8-sig')).get('VersionName')
    if not isinstance(version, str) or not re.fullmatch(r'[0-9A-Za-z][0-9A-Za-z._+-]*', version):
        raise ValueError(f'Invalid VersionName in {descriptor}')
    return f'-- Generated from the plugin descriptor by tools/build_catalog.py.\nreturn "{version}"\n'


def apply_dependencies(manifest, metadata, plugin):
    dependencies = metadata.get('dependencies', [])
    if not isinstance(dependencies, list):
        raise ValueError('Mod dependencies must be a list of project names')
    seen = {plugin.casefold()}
    for dependency in dependencies:
        if (not isinstance(dependency, str) or not dependency.strip()
                or dependency != dependency.strip()
                or any(ord(char) < 32 for char in dependency)
                or dependency.casefold() in seen):
            raise ValueError('Invalid, duplicate or self-referencing mod dependency')
        seen.add(dependency.casefold())
    result = copy.deepcopy(manifest)
    result['Dependencies'] = list(dependencies)
    return result

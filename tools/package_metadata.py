"""Preserve author dependencies omitted by ModKit's PackageUGC exporter."""
import copy


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

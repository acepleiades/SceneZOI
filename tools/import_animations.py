"""Run with UnrealEditor-Cmd -run=pythonscript -script=<this file>.

Set SCENEZOI_EXPORT_DIR, SCENEZOI_IMPORT_REPORT and optionally SCENEZOI_SOURCE_ROOT.
Imports new animation packages. SCENEZOI_REIMPORT_SOURCES optionally supplies a
JSON array of exact source filenames to replace, limiting the operation to those
entries. Never modifies the reference skeleton.
"""
import hashlib
import json
import os
from pathlib import Path

import unreal

root = Path(os.environ.get('SCENEZOI_SOURCE_ROOT', os.environ.get('SCENEZOI_DEMO_DIR', str(Path(__file__).resolve().parents[1]))))
source = Path(os.environ['SCENEZOI_EXPORT_DIR'])
report_path = Path(os.environ['SCENEZOI_IMPORT_REPORT'])
inventory = {item['filename']: item for item in json.loads((root / 'animation-inventory.json').read_text())}
plan = json.loads((root / 'imports.json').read_text())
reimport_sources = set(json.loads(os.environ.get('SCENEZOI_REIMPORT_SOURCES', '[]')))
assert reimport_sources <= {entry['source'] for entry in plan}, 'Unknown reimport source'
report = []
try:
    skeleton_paths=json.loads(os.environ.get('SCENEZOI_SKELETONS','{"body":"/Game/Characters/Skeletons/SK_Base"}'))
    assert isinstance(skeleton_paths,dict)and all(isinstance(k,str)and isinstance(v,str)for k,v in skeleton_paths.items())
    skeletons={key:unreal.load_asset(path)for key,path in skeleton_paths.items()}
    assert all(skeletons.values()), 'Required existing skeletons are unavailable'
    for entry in plan:
        if reimport_sources and entry['source'] not in reimport_sources:
            continue
        filename = source / entry['source']
        expected = inventory[entry['source']]
        assert hashlib.sha256(filename.read_bytes()).hexdigest() == expected['sha256'], 'Source FBX changed: ' + filename.name
        package, name = entry['destination'].split('.')
        asset = unreal.load_asset(package) if unreal.EditorAssetLibrary.does_asset_exist(package) else None
        imported = asset is None
        replacing = entry['source'] in reimport_sources
        if imported or replacing:
            options = unreal.FbxImportUI()
            options.set_editor_property('automated_import_should_detect_type', False)
            options.set_editor_property('mesh_type_to_import', unreal.FBXImportType.FBXIT_ANIMATION)
            options.set_editor_property('original_import_type', unreal.FBXImportType.FBXIT_ANIMATION)
            options.set_editor_property('import_mesh', False)
            options.set_editor_property('import_animations', True)
            options.set_editor_property('import_materials', False)
            options.set_editor_property('import_textures', False)
            options.set_editor_property('skeleton', skeletons[entry['skeleton']])
            animation = options.get_editor_property('anim_sequence_import_data')
            animation.set_editor_property('animation_length', unreal.FBXAnimationLengthImportType.FBXALIT_EXPORTED_TIME)
            animation.set_editor_property('use_default_sample_rate', False)
            animation.set_editor_property('custom_sample_rate', 60)
            animation.set_editor_property('import_bone_tracks', True)
            animation.set_editor_property('import_meshes_in_bone_hierarchy', False)
            options.get_editor_property('skeletal_mesh_import_data').set_editor_property('update_skeleton_reference_pose', False)
            task = unreal.AssetImportTask()
            task.set_editor_property('filename', str(filename))
            task.set_editor_property('destination_path', package.rsplit('/', 1)[0])
            task.set_editor_property('destination_name', name)
            task.set_editor_property('automated', True)
            task.set_editor_property('replace_existing', replacing)
            task.set_editor_property('replace_existing_settings', replacing)
            task.set_editor_property('save', False)
            task.set_editor_property('factory', unreal.FbxFactory())
            task.set_editor_property('options', options)
            unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
            asset = unreal.load_asset(package)
        assert isinstance(asset, unreal.AnimSequence), 'Expected an animation sequence: ' + package
        assert asset.get_editor_property('skeleton') == skeletons[entry['skeleton']], 'Wrong imported skeleton'
        duration = asset.get_editor_property('sequence_length')
        assert abs(duration - expected['takes'][0]['duration_seconds']) <= 0.0001, 'Unexpected imported duration'
        replacing = entry['source'] in reimport_sources
        if imported or replacing:
            assert unreal.EditorAssetLibrary.save_loaded_asset(asset), 'Could not save animation package'
        report.append({'source': entry['source'], 'asset': asset.get_path_name(), 'imported': imported, 'reimported': replacing,
                       'source_sha256': expected['sha256'],
                       'duration': duration, 'skeleton': asset.get_editor_property('skeleton').get_path_name()})
        report_path.write_text(json.dumps({'ok': False, 'in_progress': True, 'assets': report}, indent=2))
    report_path.write_text(json.dumps({'ok': True, 'assets': report}, indent=2))
except Exception as exc:
    report_path.write_text(json.dumps({'ok': False, 'error': str(exc), 'assets': report}, indent=2))
    raise

"""Filter a native package to the exact assets declared by its author inventory."""
from pathlib import Path
import shutil,subprocess,re,csv,json,argparse
from package_metadata import apply_dependencies

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('package',type=Path,help='Raw packaged mod folder, containing mod_manifest.json')
parser.add_argument('output',type=Path,help='Separate destination mod folder for the filtered package')
parser.add_argument('--modkit-root',type=Path,required=True,help='Folder containing Engine/ and inZOIModKit/')
parser.add_argument('--plugin',default='SceneZOI_93C44199')
parser.add_argument('--inventory',type=Path,default=Path(__file__).resolve().parents[1]/'asset-inventory.json',help='Author-owned packaging inventory')
args=parser.parse_args()
plugin=args.plugin
inventory=json.loads(args.inventory.read_text(encoding='utf-8'))
expected_packages=set(inventory['plugins'][plugin])
expected_package_count=len(expected_packages)
project=args.modkit_root.resolve()/'inZOIModKit'
mod=project/'Mods'/plugin
original=args.package.resolve()
final=args.output.resolve()
assert original!=final and original not in final.parents and final not in original.parents, 'Use separate package directories'
workspace=final.parent/('packaging-audit-'+plugin)
for directory in ['work','outputs']:(workspace/directory).mkdir(parents=True,exist_ok=True)
assert (original/'mod_manifest.json').is_file()
# PackageUGC creates a fresh manifest without copying author dependencies.
# Validate before creating output and carry them into the filtered package.
author_metadata=json.loads((mod/'Meta/mod_manifest.json').read_text(encoding='utf-8-sig'))
package_manifest=apply_dependencies(json.loads((original/'mod_manifest.json').read_text(encoding='utf-8-sig')),author_metadata,plugin)
shutil.copytree(original,final,dirs_exist_ok=True)
# Each package ships its own native declaration patch.
# Native runtime discovery never reads the retired shared cfg directory.
data_inventory=json.loads((mod/'workspace/data_files.json').read_text(encoding='utf-8'))
assert data_inventory['transport']=='native_table'
for entry in data_inventory['files']:
    exported=original/'non_ufs'/Path(entry['path']).relative_to('Content')
    assert json.loads(exported.read_text(encoding='utf-8-sig'))==json.loads((mod/entry['path']).read_text(encoding='utf-8-sig')),'Native declaration patch mismatch'
    assert 'non_ufs/'+Path(entry['path']).relative_to('Content').as_posix()in {p.lstrip('/')for p in json.loads((original/'mod_manifest.json').read_text(encoding='utf-8-sig'))['NonAssets']},'Native patch missing from manifest'
data_sidecars=[]
assert not(final/'scenezoi_data').exists(),'Retired shared declarations in raw package'

response=args.modkit_root.resolve()/'Engine/Programs/AutomationTool/Saved/ResponseFiles'/f'PakListIoStore_{plugin}inZOIModKit-Windows.txt'
# Lua/data-only add-ons have no cooked response/container at all. Validate an exact
# non-asset allowlist instead of invoking IoStore with an empty asset response.
if not expected_packages and not any(original.rglob('*.utoc')):
    assert package_manifest['Assets']==[], 'Assetless manifest declares assets'
    classes=json.loads((original/'mod_assethash.json').read_text(encoding='utf-8-sig'))
    assert isinstance(classes,dict)and not(set(classes)-{'assetClasses'})and classes.get('assetClasses',{})=={}, 'Assetless package declares asset classes'
    allowed={'mod_manifest.json','mod_assethash.json',plugin+'.uplugin'}
    for name in package_manifest['NonAssets']:
        name=name.lstrip('/')
        assert name and '\\'not in name and '..'not in Path(name).parts and not Path(name).is_absolute(), 'Invalid non-asset path'
        allowed.add(name)
    present={p.relative_to(original).as_posix()for p in original.rglob('*')if p.is_file()}
    assert present==allowed, {'missing':sorted(allowed-present),'unexpected':sorted(present-allowed)}
    forbidden={'.uasset','.uexp','.ubulk','.pak','.utoc','.ucas','.umap','.dll'}
    assert not any(Path(name).suffix.lower()in forbidden for name in present), 'Cooked/native payload in assetless package'
    (final/'mod_manifest.json').write_text(json.dumps(package_manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report={'source_response_entries':0,'retained_entries':0,'asset_package_count':0,
        'texture_bulk_chunks':0,'audio_asset_packages':0,'audio_bulk_chunks':0,'data_sidecars':[],
        'asset_payloads':[],'final_directory':str(final),'dependencies':package_manifest['Dependencies'],
        'companion_pak_is_mod_asset_registry_only':True,'no_game_or_engine_asset_payloads':True,
        'assetless_native_package':True,'cooked_containers_present':False,'non_asset_files_verified':len(present)}
    (workspace/'outputs/compat-package-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    raise SystemExit(0)

selected=[]
for line in response.read_text(encoding='utf-8-sig').splitlines():
    match=re.fullmatch(r'"([^"]+)" "([^"]+)"(.*)',line)
    assert match,line
    source,destination,options=match.groups()
    # Every source path contains the plugin's cook directory. Filter by its destination,
    # not by that source substring, or stock game dependencies would leak back in.
    if f'/Mods/{plugin}/Content/' in destination.replace('\\','/'):
        assert Path(source).is_file(),source
        selected.append(line)
assert len(selected)>=expected_package_count
filtered=workspace/'work/compat-plugin-only-response.txt'
filtered.write_text('\n'.join(selected)+'\n',encoding='utf-8')
utoc=final/'Content/Paks/Windows'/f'{plugin}inZOIModKit-Windows.utoc'
commands=workspace/'work/compat-plugin-only-commands.txt'
commands.write_text(f'-Output="{utoc}" -ContainerName={plugin}inZOIModKit-Windows -ResponseFile="{filtered}"\n',encoding='utf-8')
metadata=mod/'Saved/Cooked/Windows/inZOIModKit/Mods'/plugin/'Metadata'
exe=str(args.modkit_root.resolve()/'Engine/Binaries/Win64/UnrealPak.exe')
args=[exe,str(project/'inZOIModKit.uproject'),f'-CreateDLCContainer={mod/(plugin+".uplugin")}',
      f'-PackageStoreManifest={metadata/"packagestore.manifest"}',f'-CookedDirectory={mod/"Saved/Cooked/Windows"}',
      f'-Commands={commands}',f'-ScriptObjects={metadata/"scriptobjects.bin"}',
      '-patchpaddingalign=2048','-compressionformats=Oodle','-compresslevel=4','-compressmethod=Kraken',
      f'-cryptokeys={metadata/"Crypto.json"}','-compressionMinBytesSaved=1024','-compressionMinPercentSaved=5',
      '-WriteBackMetadataToAssetRegistry=Disabled',f'-BasedOnReleaseVersionPath={project/"Releases/UGCExampleGame_v1/Windows"}',
      '-unattended',f'-abslog={workspace/"work/compat-plugin-only-build.log"}']
with (workspace/'work/compat-plugin-only-output.txt').open('w',encoding='utf-8') as output:
    subprocess.run(args,stdout=output,stderr=subprocess.STDOUT,check=True)
inventory=workspace/'work/compat-final-package-assets.csv'
subprocess.run([exe,f'-ListContainer={utoc}',f'-Csv={inventory}','-unattended',
    f'-abslog={workspace/"work/compat-final-package-list.log"}'],check=True,stdout=subprocess.DEVNULL)
with inventory.open(encoding='utf-8-sig',newline='') as f:
    rows=[{k.strip():v.strip() for k,v in row.items()} for row in csv.DictReader(f)]
filenames=[r['Filename'] for r in rows if r['Filename']!='<ContainerHeader>']
assert all(f'/Mods/{plugin}/Content/' in name for name in filenames),filenames
payloads={name.split('/Content/',1)[1]for name in filenames if name.endswith('.uasset')}
assert payloads==expected_packages, {'missing':sorted(expected_packages-payloads),'unexpected':sorted(payloads-expected_packages)}
audio_payloads={name for name in payloads if name.startswith('Audio/')}
texture_bulk_count=sum(name.endswith('.ubulk')and '/Content/Audio/'not in name for name in filenames)
audio_bulk_count=sum(name.endswith('.ubulk')and '/Content/Audio/'in name for name in filenames)
pak_response=response.with_name(f'PakList_{plugin}inZOIModKit-Windows.txt')
pak_entries=pak_response.read_text(encoding='utf-8-sig').splitlines()
assert len(pak_entries)==1 and f'/Mods/{plugin}/AssetRegistry.bin' in pak_entries[0].replace('\\','/'), \
    'The companion pak must contain only the mod asset registry'
# UAT generated this registry from the migrated source, so its declared membership must agree.
manifest_path=final/'mod_manifest.json'
manifest=package_manifest
assert set(manifest['Assets'])=={name.removesuffix('.uasset')for name in expected_packages},'Native manifest membership mismatch'
hashes=json.loads((final/'mod_assethash.json').read_text(encoding='utf-8-sig'))
assert set(hashes['assetClasses'])==set(manifest['Assets']),'Asset-class membership mismatch'
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'source_response_entries':len(response.read_text(encoding='utf-8-sig').splitlines()),
        'retained_entries':len(selected),'asset_package_count':expected_package_count,'texture_bulk_chunks':texture_bulk_count,
        'audio_asset_packages':len(audio_payloads),'audio_bulk_chunks':audio_bulk_count,
        'data_sidecars':data_sidecars,'asset_payloads':filenames,'final_directory':str(final),'dependencies':manifest['Dependencies'],
        'companion_pak_is_mod_asset_registry_only':True,
        'no_game_or_engine_asset_payloads':True}
(workspace/'outputs/compat-package-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))

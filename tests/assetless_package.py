import json,tempfile,subprocess,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class AssetlessTests(unittest.TestCase):
 def package(self,mutate=None):
  with tempfile.TemporaryDirectory()as temp:
   base=Path(temp);plugin='Example_AB12CD34';native=base/'kit/inZOIModKit/Mods'/plugin;raw=base/'raw';out=base/'out'
   def write(p,value):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value),encoding='utf-8')
   patch={'Struct':'Text','PatchList':[]}
   write(native/'Meta/mod_manifest.json',{'dependencies':['SceneZOI_93C44199']})
   write(native/'workspace/data_files.json',{'transport':'native_table','files':[{'path':'Content/JsonPatch/Text_UI_patch.json'}]})
   write(native/'Content/JsonPatch/Text_UI_patch.json',patch);write(raw/'non_ufs/JsonPatch/Text_UI_patch.json',patch)
   (raw/'lua').mkdir();(raw/'lua/Main.lua').write_text('return {}',encoding='utf-8')
   write(raw/(plugin+'.uplugin'),{});write(raw/'mod_assethash.json',{'assetClasses':{}})
   manifest={'Assets':[],'NonAssets':['/lua/Main.lua','/non_ufs/JsonPatch/Text_UI_patch.json'],'Dependencies':[]}
   write(raw/'mod_manifest.json',manifest);write(base/'inventory.json',{'plugins':{plugin:[]}})
   if mutate:mutate(raw,manifest,write)
   run=subprocess.run([sys.executable,str(ROOT/'tools/filter_package.py'),str(raw),str(out),'--modkit-root',str(base/'kit'),'--plugin',plugin,'--inventory',str(base/'inventory.json')],capture_output=True,text=True)
   report=json.loads((out.parent/('packaging-audit-'+plugin)/'outputs/compat-package-audit.json').read_text(encoding='utf-8'))if run.returncode==0 else None
   return run,report
 def test_exact_native_lua_and_json(self):
  run,report=self.package();self.assertEqual(run.returncode,0,run.stderr);self.assertTrue(report['assetless_native_package']);self.assertEqual(report['asset_package_count'],0);self.assertEqual(report['dependencies'],['SceneZOI_93C44199'])
 def test_native_empty_hash_document(self):
  run,report=self.package(lambda raw,manifest,write:write(raw/'mod_assethash.json',{}));self.assertEqual(run.returncode,0,run.stderr);self.assertTrue(report['assetless_native_package'])
 def test_unlisted_file(self):
  run,_=self.package(lambda raw,*_: (raw/'extra.txt').write_text('unexpected'));self.assertNotEqual(run.returncode,0)
 def test_declared_cooked_file_still_rejected(self):
  def mutate(raw,manifest,write):
   (raw/'referenced.uasset').write_bytes(b'bad');manifest['NonAssets'].append('/referenced.uasset');write(raw/'mod_manifest.json',manifest)
  run,_=self.package(mutate);self.assertNotEqual(run.returncode,0)
 def test_declared_asset_rejected(self):
  def mutate(raw,manifest,write):manifest['Assets']=['Game/Unexpected'];write(raw/'mod_manifest.json',manifest)
  run,_=self.package(mutate);self.assertNotEqual(run.returncode,0)
if __name__=='__main__':unittest.main()

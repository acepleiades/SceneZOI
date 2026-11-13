"""Framework-only author validation; no content repository is required."""
import copy,json,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_catalog import build,compile_packs
from pack_sources import load_pack
def standing_pack():
 pack=load_pack(ROOT/'packs/scenezoi.json');pack['nodes']=[n for n in pack['nodes']if n['id']=='scenezoi.standing_idle'];pack.pop('data_files',None)
 return pack

class FrameworkCatalogTests(unittest.TestCase):
 def test_generic_pose_schema(self):
  from facial_pose_data import validate
  pose=json.loads((ROOT/'packs/scenezoi/facial_poses/open_o.json').read_text(encoding='utf-8'))
  validate(pose,'scenezoi')
  partial={'schema_version':1,'id':'example.brow','poses':{'female':[{'bone':'FACIAL_L_Brow','parent':'FACIAL_C_FacialRoot','position':[0,0,0],'rotation':[0,0,0,1]}]}}
  validate(partial,'example')
  for alter in [lambda x:x['poses']['female'][0].update(rotation=[0,0,0,0]),lambda x:x['poses']['female'][0].update(parent='FACIAL_L_Brow'),lambda x:x.update(poses={}),lambda x:x.update(open_mouth=True)]:
   invalid=copy.deepcopy(partial);alter(invalid)
   with self.assertRaises(ValueError):validate(invalid,'example')
 def test_pose_only_scene_and_retired_field_rejection(self):
  self.pack['nodes'][0]['expressions']={'lead':{'facial_pose':'example.brow'}}
  role=next(iter(self.pack['nodes'][0]['participants']))
  self.pack['nodes'][0]['expressions']={role:{'facial_pose':'example.brow'}}
  compile_packs([self.pack])
  self.pack['nodes'][0]['expressions'][role]={'context':'idle','open_mouth':True}
  with self.assertRaises(ValueError):compile_packs([self.pack])

 def setUp(self):self.pack=standing_pack()
 def test_neutral_inventory(self):
  result=compile_packs([self.pack]);self.assertEqual(list(result['nodes']),['scenezoi.standing_idle'])
  self.assertTrue(result['nodes']['scenezoi.standing_idle']['starting_hub'])
  self.assertFalse(result['nodes']['scenezoi.standing_idle']['navigation'])
  self.assertNotIn('HZoi',json.dumps(result))
  self.assertEqual(len(json.loads((ROOT/'asset-inventory.json').read_text(encoding='utf-8'))['plugins']['SceneZOI_93C44199']),4)
  self.assertEqual(len(json.loads((ROOT/'imports.json').read_text(encoding='utf-8'))),4)
 def test_starting_hub_requires_boolean(self):
  self.pack['nodes'][0]['starting_hub']='true'
  with self.assertRaises(ValueError):compile_packs([self.pack])
 def test_optional_track_gate_requires_boolean(self):
  node=self.pack['nodes'][0]
  node['hide_if_tracks_missing']=True
  self.assertTrue(compile_packs([self.pack])['nodes'][node['id']]['hide_if_tracks_missing'])
  node['hide_if_tracks_missing']='true'
  with self.assertRaises(ValueError):compile_packs([self.pack])
 def test_roles_are_named_not_unique_bodies(self):
  node=self.pack['nodes'][0];node['participants']['female']['body']='male'
  self.assertEqual(len(compile_packs([self.pack])['nodes'][node['id']]['participants']),2)
 def test_unknown_schema_field_rejected(self):
  self.pack['nodes'][0]['callback']='run'
  with self.assertRaises(ValueError):compile_packs([self.pack])
 def test_native_stage_has_no_static_catalog(self):
  with tempfile.TemporaryDirectory()as directory:
   project=Path(directory);(project/'workspace').mkdir()
   (project/'workspace/native_version.json').write_text(json.dumps({'version':'test'}))
   build([ROOT/'packs/scenezoi.json'],project)
   entries=json.loads((project/'Content/JsonPatch/Text_UI_patch.json').read_text(encoding='utf-8'))['PatchList']
   self.assertEqual(len(entries),10);self.assertEqual(json.loads(entries[0]['Value']['Text'])['owner'],'scenezoi')
   self.assertFalse((project/'lua').exists());self.assertFalse((project/'ui').exists())
 def test_independent_author_uses_explicit_project(self):
  with tempfile.TemporaryDirectory()as directory:
   root=Path(directory);pack=root/'example.json';data=copy.deepcopy(self.pack);data['id']='example'
   node=data['nodes'][0];node['id']='example.hub';pack.write_text(json.dumps(data))
   project=root/'Example';(project/'workspace').mkdir(parents=True)
   (project/'workspace/native_version.json').write_text(json.dumps({'version':'test'}))
   build([pack],project)
   rows=json.loads((project/'workspace/data_files.json').read_text(encoding='utf-8'))['records']
   self.assertEqual(rows[0]['owner'],'example')
class SceneFileTests(unittest.TestCase):
 def source(self,root):
  folder=root/'scenes';folder.mkdir()
  pack=root/'pack.json';pack.write_text(json.dumps({'schema_version':3,'id':'example','scene_directory':'scenes','extensions':[]}))
  return pack,folder
 def test_scene_folder_discovery_and_field_order(self):
  with tempfile.TemporaryDirectory()as directory:
   pack,folder=self.source(Path(directory));(folder/'02_b.json').write_text('{"id":"example.b"}');(folder/'01_a.json').write_text('{"id":"example.a"}')
   (folder/'notes.txt').write_text('ignored')
   self.assertEqual([node['id']for node in load_pack(pack)['nodes']],['example.a','example.b'])
   self.assertEqual(list(load_pack(pack)),['schema_version','id','nodes','extensions'])
   (folder/'03_c.json').write_text('{"id":"example.c"}')
   self.assertEqual(len(load_pack(pack)['nodes']),3,'Adding a scene must not require editing a file index')
 def test_ambiguous_or_escaping_directories_fail(self):
  with tempfile.TemporaryDirectory()as directory:
   pack,folder=self.source(Path(directory))
   for value in ['../outside',str(folder.resolve()),'',None,'missing']:
    pack.write_text(json.dumps({'scene_directory':value}))
    with self.assertRaises(ValueError):load_pack(pack)
   pack.write_text('{"scene_directory":"scenes","nodes":[]}')
   with self.assertRaises(ValueError):load_pack(pack)
 def test_invalid_scene_and_duplicate_keys_fail(self):
  with tempfile.TemporaryDirectory()as directory:
   pack,folder=self.source(Path(directory));scene=folder/'scene.json'
   for raw in ['[]','not json','{"id":"a","id":"b"}']:
    scene.write_text(raw)
    with self.assertRaises(ValueError):load_pack(pack)
 def test_validation_failure_preserves_previous_output(self):
  with tempfile.TemporaryDirectory()as directory:
   root=Path(directory);pack,folder=self.source(root)
   node=standing_pack()['nodes'][0];node['id']='example.hub';(folder/'scene.json').write_text(json.dumps(node))
   project=root/'project';(project/'workspace').mkdir(parents=True);(project/'workspace/native_version.json').write_text('{"version":"test"}')
   build([pack],project)
   target=project/'Content/JsonPatch/Text_UI_patch.json';before=target.read_bytes()
   (folder/'duplicate.json').write_text(json.dumps(node))
   with self.assertRaises(ValueError):build([pack],project)
   self.assertEqual(target.read_bytes(),before)
class PackageMetadataTests(unittest.TestCase):
 def test_author_dependencies_survive_export(self):
  from package_metadata import apply_dependencies
  original={'Dependencies':[],'Assets':['some_asset'],'FileChecksums':['native-checksum'],'bEnable':True}
  result=apply_dependencies(original,{'dependencies':['ExampleFramework_12345678']},'ExamplePack_87654321')
  self.assertEqual(result['Dependencies'],['ExampleFramework_12345678'])
  self.assertEqual(result['Assets'],original['Assets'])
  self.assertEqual(result['FileChecksums'],original['FileChecksums'])
  self.assertEqual(original['Dependencies'],[])
 def test_framework_has_no_content_dependency(self):
  from package_metadata import apply_dependencies
  self.assertEqual(apply_dependencies({'Dependencies':[]},{},'Framework')['Dependencies'],[])
 def test_invalid_dependency_metadata_is_rejected(self):
  from package_metadata import apply_dependencies
  for value in ['Other',[None],[''],[' Other'],['Self'],['Other','OTHER'],['Other\n']]:
   with self.subTest(value=value),self.assertRaises(ValueError):apply_dependencies({}, {'dependencies':value},'Self')

class VoiceAuthoringTests(unittest.TestCase):
 def test_invalid_voice_declaration_preserves_native_patch(self):
  from build_catalog import build
  from voice_data import validate
  import tempfile
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory);project=root/'project';(project/'workspace').mkdir(parents=True)
   (project/'workspace/native_version.json').write_text(json.dumps({'version':'test'}))
   voice=root/'voice.json';pack=root/'pack.json'
   data={'schema_version':1,'id':'neutral.mature','label':'Mature','body':'female','default':True}
   voice.write_text(json.dumps(data));pack.write_text(json.dumps({'schema_version':3,'id':'neutral','nodes':[],'extensions':[],'data_files':[{'kind':'voice_archetype','file':'voice.json'}]}))
   build([pack],project);patch=project/'Content/JsonPatch/Text_UI_patch.json';before=patch.read_bytes()
   data['callback']='run()';voice.write_text(json.dumps(data))
   with self.assertRaises(ValueError):build([pack],project)
   self.assertEqual(patch.read_bytes(),before)
 def test_voice_contexts_are_not_an_enum(self):
  from voice_data import validate
  validate('voice_context',{'schema_version':1,'id':'custom context','label':'Custom context'})
  with self.assertRaises(ValueError):validate('voice_context',{'schema_version':1,'id':'','label':'Bad'})

class TransitionTests(unittest.TestCase):
 def test_transition_paths_and_types(self):
  pack=standing_pack();hub=pack['nodes'][0]
  transition=copy.deepcopy(hub);transition.update(id='scenezoi.transition',kind='transition',destination=hub['id'],navigation=[]);transition.pop('starting_hub');transition.pop('hub',None)
  pack['nodes'].append(transition);hub['navigation']=[{'id':'transition','target':transition['id']}]
  self.assertEqual(compile_packs([pack])['nodes'][transition['id']]['destination'],hub['id'])
  for change in [{'destination':'missing.node'},{'destination':transition['id']},{'navigation':[{'id':'bad','target':hub['id']}]},{'starting_hub':True},{'hub':'scenezoi.hub'}]:
   bad=copy.deepcopy(pack);bad['nodes'][1].update(change)
   with self.subTest(change=change),self.assertRaises(ValueError):compile_packs([bad])
  bad=copy.deepcopy(pack);bad['nodes'][0]['participants']['male']['body']='female'
  with self.assertRaises(ValueError):compile_packs([bad])
  second=copy.deepcopy(transition);second['id']='scenezoi.second';second['destination']=transition['id'];transition['destination']=second['id'];pack['nodes'].append(second)
  with self.assertRaises(ValueError):compile_packs([pack])
  second['destination']='foreign.loop'
  self.assertIn(transition['id'],compile_packs([pack],link=False)['nodes'])

class TaskRouteTests(unittest.TestCase):
 def test_task_completion_route_schema_and_linking(self):
  pack=standing_pack();origin=pack['nodes'][0]
  target=copy.deepcopy(origin);target.update(id='scenezoi.finish',kind='transition',destination=origin['id'],navigation=[]);target.pop('hub',None);target.pop('starting_hub',None)
  pack['nodes'].append(target);origin['task_completion_routes']={'male':{'custom_task':target['id']}}
  self.assertEqual(compile_packs([pack])['nodes'][origin['id']]['task_completion_routes']['male']['custom_task'],target['id'])
  for routes in [False,{'unknown':{'custom_task':target['id']}},{'male':{'custom_task':1}},{'male':{'bad id':target['id']}},{'male':{'custom_task':'missing.node'}}]:
   bad=copy.deepcopy(pack);bad['nodes'][0]['task_completion_routes']=routes
   with self.subTest(routes=routes),self.assertRaises(ValueError):compile_packs([bad])
  bad=copy.deepcopy(pack);bad['nodes'][1]['participants']['female']['body']='male'
  with self.assertRaises(ValueError):compile_packs([bad])
  origin['task_completion_routes']['male']['custom_task']='foreign.finish'
  self.assertIn(origin['id'],compile_packs([pack],link=False)['nodes'])

class TaskTests(unittest.TestCase):
 def test_definition_and_directive_validation(self):
  from task_data import validate,directives
  good={'schema_version':1,'id':'spell_charge','label':'Spell charging','maximum':200,'completion_event':'spell_ready','display':{'body_colors':{'female':'#ff44aa'}}}
  validate(good);directives({'caster':{'spell_charge':{'rate':0,'cap_percent':50},'other_task':{'rate':-2}}},{'caster':{}})
  for change in [{'maximum':0},{'initial':201},{'decay':-1},{'maximum':float('nan')},{'maximum':True},{'display':{'color':'red'}},{'completion_event':'bad id'}]:
   with self.subTest(change=change),self.assertRaises(ValueError):validate(dict(good,**change))
  for tasks in [{'missing':{'spell_charge':{'rate':1}}},{'caster':{'spell_charge':{'rate':True}}},{'caster':{'spell_charge':{'rate':1,'cap_percent':101}}}]:
   with self.assertRaises(ValueError):directives(tasks,{'caster':{}})
 def test_completion_sound_validation(self):
  from task_data import validate
  action={'type':'play_sound','when':{'body':'male'},'clip':'/Neutral/Charge.Charge','source':{'component':'body','bones':['root']},'volume':.75,'max_voices':2}
  definition={'schema_version':1,'id':'charge','label':'Charge','maximum':90,'on_completion':[action]}
  validate(definition)
  for bad in [{'type':'callback'},{'clip':'code()'},{'source':{'component':'body','bones':[]}},{'when':{'body':'other'}},{'volume':False},{'max_voices':1.5},{'attenuation':{'code':'run()'}}]:
   with self.subTest(bad=bad),self.assertRaises(ValueError):validate(dict(definition,on_completion=[dict(action,**bad)]))
  for bad in [False,{},'run()']:
   with self.assertRaises(ValueError):validate(dict(definition,on_completion=bad))

 def test_bad_task_preserves_generated_outputs(self):
  from build_catalog import build
  from data_files import PATCH
  with tempfile.TemporaryDirectory()as folder:
   root=Path(folder);pack=root/'pack.json';task=root/'task.json';project=root/'project'
   (project/'workspace').mkdir(parents=True);(project/'workspace/native_version.json').write_text('{"version":"test"}')
   from pack_sources import load_pack
   source=load_pack(Path('packs/scenezoi.json'));source['data_files']=[{'kind':'scene_task','file':'task.json'}]
   pack.write_text(json.dumps(source));task.write_text(json.dumps({'schema_version':1,'id':'test','label':'Test','maximum':10}))
   build([pack],project);before={p.relative_to(project):p.read_bytes()for p in project.rglob('*')if p.is_file()}
   task.write_text('{"schema_version":1,"id":"test","label":"Test","maximum":0}')
   with self.assertRaises(ValueError):build([pack],project)
   self.assertEqual(before,{p.relative_to(project):p.read_bytes()for p in project.rglob('*')if p.is_file()})


class CompletionResponseTests(unittest.TestCase):
 def setUp(self):
  self.pack=standing_pack();self.node=self.pack['nodes'][0]
  self.node['movement_timing']={'cycles_per_second':1,'peak_phase':.5}
  self.node['completion_responses']={'female':{'charge':{'enabled':True,'slowdown':{},'shake':{'bones':[{'bone':'joint','child':'tip','weight':-.8}]}}}}
 def test_enabled_and_disabled(self):
  compile_packs([self.pack]);self.node['completion_responses']['female']['charge']={'enabled':False};compile_packs([self.pack])
 def test_marker_validation(self):
  for timing in [{'peak_times':[.3,1.1,2.7]},{'cycles_per_second':2,'peak_phase':.25}]:
   self.node['movement_timing']=timing;compile_packs([self.pack])
  for timing in [{'peak_times':[1,1]},{'peak_times':[3]},{'cycles_per_second':1.1},{'cycles_per_second':True},{'peak_times':[.2],'peak_phase':.5},{'cycles_per_second':1,'peak_times':[.2]}]:
   self.node['movement_timing']=timing
   with self.assertRaises(ValueError):compile_packs([self.pack])
 def test_invalid_effects(self):
  bad=[{'enabled':'yes'},{'enabled':True},{'enabled':True,'slowdown':{'repeats':1.5}},
   {'enabled':True,'slowdown':{'low_speed':.9}}, {'enabled':True,'slowdown':{'callback':'code'}},
   {'enabled':True,'shake':{'frequency_hz':float('nan'),'bones':[]}},
   {'enabled':True,'shake':{'bones':[{'bone':'a','child':'a'}]}},
   {'enabled':True,'shake':{'bones':[{'bone':'a','child':'b'},{'bone':'a','child':'c'}]}}]
  for spec in bad:
   self.node['completion_responses']['female']['charge']=spec
   with self.assertRaises(ValueError):compile_packs([self.pack])
 def test_fallback_and_authored_priority_can_coexist_in_data(self):
  self.node.pop('movement_timing');self.node['completion_responses']['female']['charge']['slowdown']={'fallback_duration':5}
  self.node['task_completion_routes']={'female':{'charge':self.node['id']}}
  compile_packs([self.pack])


class VoiceResponseSourceTests(unittest.TestCase):
 def test_valid_response_groups_and_rules(self):
  from voice_data import validate,completion_rules
  data={'schema_version':1,'id':'test','label':'Test','body':'female','archetype':'test','context':'talk','clips':['/Test/A.A'],'responses':{'answer':{'clips':['/Test/B.B'],'volume':.7}}}
  validate('voice_set',data)
  completion_rules({'lead':{'charge':[{'participant':'speaker','context':'talk','response':'answer','fade_out':.25,'priority':20}]}},{'lead':{},'speaker':{}})
 def test_invalid_response_groups(self):
  from voice_data import validate
  base={'schema_version':1,'id':'test','label':'Test','body':'male','archetype':'test','context':'talk','clips':['/Test/A.A']}
  for groups in [{'x':{'clips':[]}}, {'x':{'clips':['run()']}},{'x':{'clips':['/Test/B.B'],'volume':float('nan')}},{'x':{'clips':['/Test/B.B'],'callback':'run'}},{'X':{'clips':['/Test/A.A']},'x':{'clips':['/Test/B.B']}}]:
   with self.assertRaises(ValueError):validate('voice_set',dict(base,responses=groups))
 def test_invalid_completion_rules(self):
  from voice_data import completion_rules
  for rule in [{'participant':'absent','context':'talk','response':'answer'}, {'participant':'lead','context':'talk','response':'answer','fade_out':-1}, {'participant':'lead','context':'talk','response':'answer','priority':1.5}, {'participant':'lead','context':'talk','response':'answer','callback':'run'}]:
   with self.assertRaises(ValueError):completion_rules({'lead':{'charge':[rule]}},{'lead':{}})

if __name__=='__main__':unittest.main()

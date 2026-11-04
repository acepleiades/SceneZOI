import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from scene_metadata import builtin_documents,dictionaries,validate_scene
from build_catalog import build
class MetadataTests(unittest.TestCase):
 def setUp(self):self.registry=dictionaries(builtin_documents());self.scene={'participants':{'a':{},'b':{}},'tags':['doting'],'actions':[{'type':'embrace','actor':'a','target':'b'}]}
 def test_alias_and_one_sided_hug(self):
  v=validate_scene(self.scene,self.registry);self.assertEqual(v['tags'],['affectionate']);self.assertEqual(len(v['actions']),1);self.assertEqual(v['content_rating'],'GENERAL')
 def test_performer_and_maximum_rating(self):
  self.scene['actions'].append({'type':'vaginal_sex','actor':'b','target':'a','performer':'a'});v=validate_scene(self.scene,self.registry);self.assertEqual(v['content_rating'],'EXPLICIT');self.assertEqual(v['actions'][1]['performer'],'a')
 def test_missing_actions_unclassified(self):
  self.scene['actions']=[];self.assertNotIn('content_rating',validate_scene(self.scene,self.registry))
 def test_unknown_names_and_duplicate_aliases(self):
  for key in ['tags','actions']:
   v=copy.deepcopy(self.scene)
   if key=='tags':v[key]=['unregistered']
   else:v[key][0]['type']='unregistered'
   with self.assertRaises(ValueError):validate_scene(v,self.registry)
 def test_unbound_action(self):
  self.scene['actions'][0]['performer']='missing'
  with self.assertRaises(ValueError):validate_scene(self.scene,self.registry)
 def test_registry_conflict(self):
  docs=builtin_documents();owner,kind,p,data=docs[0];bad=copy.deepcopy(data);bad['tags'][1]['aliases'].append('doting')
  with self.assertRaises(ValueError):dictionaries([(owner,kind,p,bad)]+docs[1:])
 def test_real_scenes(self):
  for p in (ROOT/'packs/scenezoi/scenes').glob('*.json'):
   raw=json.loads(p.read_text());self.assertNotIn('content_rating',raw);v=validate_scene(raw,self.registry);self.assertEqual(v['content_rating'],'GENERAL');self.assertEqual({(a['actor'],a['target']) for a in v['actions'] if a['type']=='hug'},{('male','female'),('female','male')})
 def test_curated_vocabulary(self):
  self.assertEqual(len(self.registry['actions']),85)
  self.assertFalse(any('tail' in n for n in self.registry['actions']))
  self.assertEqual(self.registry['actions']['kissing_foot']['content_rating'],'SUGGESTIVE')
  self.assertEqual(self.registry['actions']['vampire_biting']['content_rating'],'GENERAL')
  self.assertEqual(self.registry['action_names']['finish_on_face'],'ejaculation_on_face')
  for key in ['analfingering','analsex','hj','smothering','specate','sex']:
   self.assertNotIn(key,self.registry['action_names'])
 def test_authored_aliases_require_underscores(self):
  for alias in ['Mixed_Case','two words','two-words']:
   docs=copy.deepcopy(builtin_documents());docs[0][3]['tags'][0]['aliases'].append(alias)
   with self.assertRaises(ValueError):dictionaries(docs)
 def test_custom_named_positions_remain_allowed(self):
  doc={'schema_version':1,'id':'speech.tags','tags':[{'id':'speech.reverse_cowgirl','aliases':['speech.reverse_riding'],'description':'Custom speech classification.'}]}
  r=dictionaries(builtin_documents()+[('speech','tag_dictionary','example',doc)])
  self.assertEqual(r['tag_names']['speech.reverse_riding'],'speech.reverse_cowgirl')
 def test_descriptive_examples_and_removed_position_names(self):
  for key in ['doggy_style','doggystyle','reverse_cowgirl','mating_press','butterfly','spooning']:
   self.assertNotIn(key,self.registry['tag_names'])
  rows=json.loads((ROOT/'docs/examples/descriptive-metadata.json').read_text())['examples']
  for row in rows:validate_scene(row['metadata'],self.registry)

if __name__=='__main__':unittest.main()

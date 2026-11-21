import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from scene_metadata import builtin_documents,dictionaries,validate_scene
from build_catalog import build
SHARED_POSE_TAG_IDS={
 'lower_legs_crossed',
 'hands_behind_head',
 'torso_supported_by_hands',
 'torso_supported_by_elbows',
 'looking_at_partner_pelvis',
 'looking_at_partner_head',
 'missionary',
 'sitting_close_to_partner',
 'on_partner_right',
 'on_partner_left',
 'arm_over_partner_shoulder',
 'right_hand_on_partner_penis',
 'on_floor',
 'hand_on_partner_lower_body',
 'hand_on_partner_thigh',
 'hand_over_partner_hand',
 'bouncing',
}
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
   raw=json.loads(p.read_text(encoding='utf-8'));self.assertNotIn('content_rating',raw);v=validate_scene(raw,self.registry);self.assertEqual(v['content_rating'],'GENERAL')
   if len(raw['participants'])==1:self.assertEqual({a['type'] for a in v['actions']},{'idle'});continue
   expected={('male','female')}if raw['id']=='scenezoi.sofa_idle'else{('male','female'),('female','male')}
   self.assertEqual({(a['actor'],a['target']) for a in v['actions'] if a['type']=='hug'},expected)
 def test_curated_vocabulary(self):
  self.assertEqual(len(self.registry['actions']),85)
  self.assertFalse(any('tail' in n for n in self.registry['actions']))
  self.assertEqual(self.registry['actions']['kissing_foot']['content_rating'],'SUGGESTIVE')
  self.assertEqual(self.registry['actions']['vampire_biting']['content_rating'],'GENERAL')
  self.assertEqual(self.registry['action_names']['finish_on_face'],'ejaculation_on_face')
  for key in ['analfingering','analsex','hj','smothering','specate','sex']:
   self.assertNotIn(key,self.registry['action_names'])
 def test_shared_pose_tags_are_framework_vocabulary(self):
  self.assertTrue(all(owner=='scenezoi'for owner,_,_,_ in builtin_documents()))
  self.assertEqual(len(self.registry['tags']),80)
  self.assertTrue(SHARED_POSE_TAG_IDS<=set(self.registry['tags']))
  self.assertTrue(all('.' not in key for key in self.registry['tags']))
  for key in SHARED_POSE_TAG_IDS:
   self.assertEqual(self.registry['tag_names'][key],key)
  scene=copy.deepcopy(self.scene)
  scene['tags']=['sitting_close_to_partner']
  scene['participant_tags']={
   'a':['sitting','arm_over_partner_shoulder','looking_at_partner_head'],
   'b':['sitting','on_partner_right','hand_over_partner_hand'],
  }
  resolved=validate_scene(scene,self.registry)
  self.assertEqual(resolved['tags'],scene['tags'])
  self.assertIn('arm_over_partner_shoulder',resolved['participant_tags']['a'])
  self.assertNotIn('arm_over_partner_shoulder',resolved['participant_tags']['b'])
  self.assertNotIn('arm_over_partner_shoulder',resolved['tags'])
  self.assertEqual(resolved['content_rating'],'GENERAL')
 def test_replaced_tag_spellings_are_not_aliases(self):
  self.assertFalse(any(key.startswith('hzoi.') for key in self.registry['tag_names']))
  for old in ['arm_over_partner_right_shoulder','hand_on_partner_left_thigh','hzoi.missionary']:
   self.assertNotIn(old,self.registry['tag_names'])
   scene=copy.deepcopy(self.scene);scene['tags']=[old]
   with self.assertRaises(ValueError):validate_scene(scene,self.registry)
 def test_authored_aliases_require_underscores(self):
  for alias in ['Mixed_Case','two words','two-words']:
   docs=copy.deepcopy(builtin_documents());docs[0][3]['tags'][0]['aliases'].append(alias)
   with self.assertRaises(ValueError):dictionaries(docs)
 def test_existing_external_dictionary_transport_remains_supported(self):
  doc={'schema_version':1,'id':'speech.tags','tags':[{'id':'speech.reverse_cowgirl','aliases':['speech.reverse_riding'],'description':'Custom speech classification.'}]}
  r=dictionaries(builtin_documents()+[('speech','tag_dictionary','example',doc)])
  self.assertEqual(r['tag_names']['speech.reverse_riding'],'speech.reverse_cowgirl')
 def test_descriptive_examples_and_removed_position_names(self):
  for key in ['doggy_style','doggystyle','reverse_cowgirl','mating_press','butterfly','spooning']:
   self.assertNotIn(key,self.registry['tag_names'])
  rows=json.loads((ROOT/'docs/examples/descriptive-metadata.json').read_text(encoding='utf-8'))['examples']
  for row in rows:validate_scene(row['metadata'],self.registry)

if __name__=='__main__':unittest.main()

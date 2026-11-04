import copy,json,sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from scene_metadata import addon_data,validate_scene,builtin_documents,dictionaries
class AnnotationTests(unittest.TestCase):
 def test_namespaced_records(self):
  data={'author.effect':{'placement':'waist','weights':[1,None,True]}}
  scene={'participants':{'a':{},'b':{}},'addon_data':data,'participant_addon_data':{'b':data},'actions':[{'type':'hug','actor':'a','target':'b','addon_data':data}]}
  result=validate_scene(scene,dictionaries(builtin_documents()))
  self.assertEqual(result['actions'][0]['addon_data'],data);result['addon_data']['author.effect']['placement']='other';self.assertEqual(data['author.effect']['placement'],'waist')
 def test_invalid_namespace_value_and_size(self):
  for bad in [{'plain':{}},{'author.effect':[]},{'author.effect':{'weight':float('inf')}},{'author.effect':{'blob':'x'*8192}},{'author.effect':{'callback':lambda:None}}]:
   with self.subTest(bad=type(bad)):
    with self.assertRaises(ValueError):addon_data(bad)
 def test_depth_and_role_limits(self):
  data={};nested=data
  for _ in range(10):nested['x']={};nested=nested['x']
  with self.assertRaises(ValueError):addon_data({'author.effect':data})
  with self.assertRaises(ValueError):validate_scene({'participants':{'a':{}},'participant_addon_data':{'missing':{'author.effect':{}}}})
 def test_dictionary_data(self):
  docs=builtin_documents();owner,kind,source,data=docs[0];data=copy.deepcopy(data)
  data['tags'][0]['addon_data']={'author.speech':{'category':'affection'}}
  registry=dictionaries([(owner,kind,source,data)]+docs[1:]);self.assertEqual(registry['tags'][data['tags'][0]['id']]['addon_data']['author.speech']['category'],'affection')
if __name__=='__main__':unittest.main()

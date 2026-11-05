import unittest,json,sys,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from localization_data import validate,validate_documents
class LocalizationTests(unittest.TestCase):
 def setUp(self):self.data=json.loads((ROOT/'packs/scenezoi/localization/text.json').read_text(encoding='utf-8'))
 def test_complete_game_languages_and_messages(self):
  cultures={'ko-KR','en-US','zh-CN','zh-TW','ja-JP','ru-RU','es-ES','pt-BR','pt-PT','de-DE','fr-FR','it-IT','pl-PL','tr-TR','nl-NL'}
  self.assertEqual(set(self.data['translations']),cultures);validate(self.data)
  english=self.data['translations']['en-US']
  for culture,groups in self.data['translations'].items():
   self.assertEqual(set(groups['messages']),set(english['messages']),culture)
   self.assertEqual(set(groups['labels']),set(english['labels']),culture)
 def test_placeholder_and_nonexecuting_text_contract(self):
  data=copy.deepcopy(self.data);data['translations']['fr-FR']['messages']['Enter a whole number from {min} to {max}.']='Choisir {min}'
  with self.assertRaises(ValueError):validate(data)
  data=copy.deepcopy(self.data);data['execute']='code'
  with self.assertRaises(ValueError):validate(data)
 def test_conflicting_documents_rejected_before_output(self):
  other=copy.deepcopy(self.data);other['translations']['en-US']['messages']['Exit']='Conflict'
  with self.assertRaises(ValueError):validate_documents([('scenezoi','localization',Path('a'),self.data),('other','localization',Path('b'),other)])
 def test_content_label_fallback_is_optional(self):
  validate({'schema_version':1,'id':'designer.localization','translations':{'fr-FR':{'labels':{'scene.designer.hub':'Accueil'}}}})
  labels=self.data['translations']['en-US']['labels']
  for path in (ROOT/'packs/scenezoi/scenes').glob('*.json'):
   node=json.loads(path.read_text(encoding='utf-8'));self.assertEqual(labels['scene.'+node['id']],node['label'])
if __name__=='__main__':unittest.main()

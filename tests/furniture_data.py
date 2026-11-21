import copy
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from furniture_data import profile


def spot(name,x):
 return {'id':name,'run':'front','offset_cm':{'x':x,'y':0,'z':0},'yaw_degrees':0,
         'slots':[{'component_name':'Seat_'+name,'slot_name':'Sit_'+name}]}


class FurnitureDataTests(unittest.TestCase):
 def setUp(self):
  self.data={'schema_version':1,'id':'author.sofa','kind':'sofa.pair','objects':['Sofa'],
             'surface_height_cm':44,'sitting_spots':[spot('a',-80),spot('b',0),spot('c',80)],
             'seat_pairs':[{'id':'ab','spots':['a','b']},{'id':'bc','spots':['b','c']}]}

 def test_adjacent_pairs_are_valid_data(self):
  profile(self.data)

 def test_corner_pair_is_rejected(self):
  self.data['sitting_spots'][1]['run']='side'
  self.data['sitting_spots'][1]['yaw_degrees']=90
  with self.assertRaisesRegex(ValueError,'straight run'):profile(self.data)

 def test_cannot_skip_physical_middle_spot(self):
  self.data['seat_pairs']=[{'id':'ac','spots':['a','c']}]
  with self.assertRaisesRegex(ValueError,'intermediate'):profile(self.data)

 def test_cannot_reuse_slot_or_pair_under_another_id(self):
  bad=copy.deepcopy(self.data);bad['sitting_spots'][1]['slots']=bad['sitting_spots'][0]['slots']
  with self.assertRaisesRegex(ValueError,'native slot'):profile(bad)
  bad=copy.deepcopy(self.data);bad['seat_pairs'].append({'id':'ba','spots':['b','a']})
  with self.assertRaisesRegex(ValueError,'combination'):profile(bad)

 def test_bed_schema_remains_whole_surface(self):
  bed={'schema_version':1,'id':'author.bed','kind':'bed.queen','objects':['Bed'],'surface_height_cm':68}
  profile(bed)
  bed['seat_pairs']=[]
  with self.assertRaisesRegex(ValueError,'sofa.pair'):profile(bed)


if __name__=='__main__':unittest.main()

import math

def scene(v):
 if v is None:return
 if not isinstance(v,dict)or set(v)!={'kind','surface_height_cm'}:raise ValueError('Invalid furniture scene context')
 from build_catalog import identifier
 identifier(v['kind']);number(v['surface_height_cm'])
def number(v):
 if type(v)not in (int,float)or not math.isfinite(v)or not -10000<=v<=10000:raise ValueError('Invalid furniture coordinate')
def profile(v):
 from build_catalog import fields,identifier,label
 fields(v,['schema_version','id','kind','objects','surface_height_cm','offset_cm','yaw_degrees','sitting_spots','seat_pairs'],['schema_version','id','kind','objects','surface_height_cm'])
 if type(v['schema_version'])is not int or v['schema_version']!=1:raise ValueError('Unsupported furniture profile')
 identifier(v['id']);identifier(v['kind']);number(v['surface_height_cm'])
 ids=v['objects']
 if not isinstance(ids,list)or not 1<=len(ids)<=512 or any(not isinstance(x,str)for x in ids)or len(set(ids))!=len(ids):raise ValueError('Invalid furniture object list')
 for x in ids:label(x)
 o=v.get('offset_cm',{});fields(o,['x','y','z'],[])
 for x in o.values():number(x)
 yaw=v.get('yaw_degrees',0);number(yaw)
 if not -360<=yaw<=360:raise ValueError('Invalid furniture yaw')
 seating(v)

def seating(v):
 from build_catalog import fields,identifier,label
 if v['kind']!='sofa.pair':
  if 'sitting_spots'in v or 'seat_pairs'in v:raise ValueError('Sitting spots require sofa.pair furniture')
  return
 spots,pairs=v.get('sitting_spots'),v.get('seat_pairs')
 if not isinstance(spots,list)or not 2<=len(spots)<=64 or not isinstance(pairs,list)or not 1<=len(pairs)<=128:raise ValueError('A sofa needs sitting spots and allowed pairs')
 known,slots={},set()
 for spot in spots:
  fields(spot,['id','run','offset_cm','yaw_degrees','slots'],['id','run','offset_cm','yaw_degrees','slots'])
  identifier(spot['id']);identifier(spot['run'])
  if spot['id']in known:raise ValueError('Duplicate sitting spot')
  known[spot['id']]=spot
  fields(spot['offset_cm'],['x','y','z'],['x','y','z'])
  for value in spot['offset_cm'].values():number(value)
  number(spot['yaw_degrees'])
  if not -360<=spot['yaw_degrees']<=360:raise ValueError('Invalid sitting spot yaw')
  if not isinstance(spot['slots'],list)or not 1<=len(spot['slots'])<=32:raise ValueError('Sitting spot has no native slots')
  for slot in spot['slots']:
   fields(slot,['component_name','slot_name'],['component_name','slot_name']);label(slot['component_name']);label(slot['slot_name'])
   key=slot['component_name'],slot['slot_name']
   if key in slots:raise ValueError('A native slot cannot belong to two physical spots')
   slots.add(key)
 pair_ids,combinations=set(),set()
 for pair in pairs:
  fields(pair,['id','spots','label'],['id','spots']);identifier(pair['id'])
  if 'label'in pair:label(pair['label'])
  if pair['id']in pair_ids:raise ValueError('Duplicate seat pair')
  pair_ids.add(pair['id']);ids=pair['spots']
  if not isinstance(ids,list)or len(ids)!=2 or ids[0]==ids[1]or any(x not in known for x in ids):raise ValueError('A seat pair needs two different known spots')
  key=tuple(sorted(ids))
  if key in combinations:raise ValueError('Duplicate sitting-spot combination')
  combinations.add(key);a,b=(known[x]for x in ids)
  if a['run']!=b['run']or abs((a['yaw_degrees']-b['yaw_degrees']+180)%360-180)>=.01:raise ValueError('Seat pair must face the same way on one straight run')
  x,y,z=(b['offset_cm'][k]-a['offset_cm'][k]for k in ('x','y','z'));length=x*x+y*y
  if length<=1 or abs(z)>=1:raise ValueError('Seat pair must share one sitting surface')
  for other in spots:
   if other is a or other is b or other['run']!=a['run']:continue
   dx,dy=(other['offset_cm'][k]-a['offset_cm'][k]for k in ('x','y'));t=(dx*x+dy*y)/length
   if 0<t<1 and abs(dx*y-dy*x)/math.sqrt(length)<1:raise ValueError('Seat pair skips an intermediate sitting spot')

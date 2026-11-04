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
 fields(v,['schema_version','id','kind','objects','surface_height_cm','offset_cm','yaw_degrees'],['schema_version','id','kind','objects','surface_height_cm'])
 if type(v['schema_version'])is not int or v['schema_version']!=1:raise ValueError('Unsupported furniture profile')
 identifier(v['id']);identifier(v['kind']);number(v['surface_height_cm'])
 ids=v['objects']
 if not isinstance(ids,list)or not 1<=len(ids)<=512 or any(not isinstance(x,str)for x in ids)or len(set(ids))!=len(ids):raise ValueError('Invalid furniture object list')
 for x in ids:label(x)
 o=v.get('offset_cm',{});fields(o,['x','y','z'],[])
 for x in o.values():number(x)
 yaw=v.get('yaw_degrees',0);number(yaw)
 if not -360<=yaw<=360:raise ValueError('Invalid furniture yaw')

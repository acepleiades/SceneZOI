"""Validate inert fixed facial-bone poses contributed by native content packs."""
import math,re
from build_catalog import fields,identifier,label,check

def validate(data,owner=None):
    fields(data,['schema_version','id','label','poses'],['schema_version','id','poses'])
    check(type(data['schema_version'])is int and data['schema_version']==1,'Unsupported facial pose schema')
    identifier(data['id'])
    if owner is not None:check(data['id'].startswith(owner+'.'),'Facial pose namespace mismatch')
    if 'label'in data:label(data['label'])
    poses=data['poses'];check(isinstance(poses,dict)and poses and not poses.keys()-{'male','female'},'Invalid facial pose bodies')
    for rows in poses.values():
        check(isinstance(rows,list)and 1<=len(rows)<=256,'Invalid facial pose bone count')
        names=set()
        for row in rows:
            fields(row,['bone','parent','position','rotation'],['bone','parent','position','rotation'])
            for key in ['bone','parent']:check(isinstance(row[key],str)and re.fullmatch(r'FACIAL_[A-Za-z0-9_]{1,90}',row[key]),'Invalid facial bone name')
            check(row['bone']not in names and row['bone']!=row['parent'],'Duplicate/self-parent facial bone');names.add(row['bone'])
            for key,n,limit in [('position',3,200),('rotation',4,1.00001)]:
                v=row[key];check(isinstance(v,list)and len(v)==n and all(type(x)in(int,float)and math.isfinite(x)and abs(x)<=limit for x in v),'Invalid facial pose '+key)
            check(abs(sum(x*x for x in row['rotation'])-1)<.00001,'Facial pose rotation must be a unit quaternion')
        parents={r['bone']:r['parent']for r in rows}
        for name in names:
            visited=set();n=name
            while n in parents:
                check(n not in visited,'Cyclic facial pose hierarchy');visited.add(n);n=parents[n]
    return data

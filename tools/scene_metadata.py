"""Validate registered scene descriptions; action ratings are the sole rating source."""
import copy,json,re,math
from pathlib import Path
RATINGS={'GENERAL':1,'SUGGESTIVE':2,'EXPLICIT':3}
def check(v,msg):
 if not v:raise ValueError(msg)
def fields(v,allowed,required=()):
 check(isinstance(v,dict)and not set(v)-set(allowed)and not set(required)-set(v),'Invalid metadata fields')
def name(v):
 check(isinstance(v,str)and len(v)<=96,'Invalid metadata name')
 v=re.sub(r'[\s-]+','_',v.strip().lower());check(re.fullmatch('[a-z][a-z0-9_.]*',v),'Invalid metadata name');return v
def names(v):
 check(isinstance(v,list)and len(v)<=256,'Expected metadata array')
 out=[name(x)for x in v];check(len(out)==len(set(out)),'Duplicate metadata name');return out
def addon_data(value):
 if value is None:return
 check(isinstance(value,dict),'addon_data must be a namespace object')
 count=0
 def visit(v,depth):
  nonlocal count
  count+=1;check(count<=1024 and depth<=8,'addon_data exceeds nesting/item limits')
  check(v is None or isinstance(v,(dict,list,str,bool,int,float)),'addon_data must contain JSON values')
  if isinstance(v,(int,float))and not isinstance(v,bool):check(math.isfinite(v),'Non-finite addon_data')
  if isinstance(v,dict):
   for k,x in v.items():check(isinstance(k,str),'Invalid addon_data key');visit(x,depth+1)
  elif isinstance(v,list):
   for x in v:visit(x,depth+1)
 for namespace,data in value.items():
  check(isinstance(namespace,str)and re.fullmatch('[a-z][a-z0-9_.-]*',namespace)and len(namespace)<=96 and '.'in namespace,'Expected author.addon namespace')
  check(isinstance(data,dict),'Each addon_data namespace must contain an object');visit(data,1)
 check(len(json.dumps(value,ensure_ascii=False,separators=(',',':')).encode('utf-8'))<=8192,'addon_data exceeds 8 KiB')
def dictionaries(documents):
 result={'tags':{},'actions':{},'tag_names':{},'action_names':{}}
 for kind,key in [('tag_dictionary','tags'),('action_dictionary','actions')]:
  defs={}
  for owner,k,source,data in documents:
   if k!=kind:continue
   fields(data,['schema_version','id',key],['schema_version','id',key]);check(data['schema_version']==1,'Unsupported dictionary version');name(data['id'])
   check(isinstance(data[key],list)and len(data[key])<=512,'Invalid dictionary entries')
   for row in data[key]:
    fields(row,['id','aliases','description','content_rating','actor_description','target_description','performer_description','actor_requirements','target_requirements','addon_data'],['id','description']+(['content_rating']if key=='actions'else []))
    addon_data(row.get('addon_data'))
    ident=name(row['id']);check(ident==row['id'],'Canonical ID must be normalized')
    check(isinstance(row['description'],str)and 0<len(row['description'])<=160,'Invalid description')
    check(owner=='scenezoi'or ident.startswith(owner+'.'),'Custom metadata must use its owner namespace')
    aliases=names(row.get('aliases',[]))
    check(row.get('aliases',[])==aliases,'Dictionary aliases must use lowercase words separated by underscores')
    check(owner=='scenezoi'or all(a.startswith(owner+'.')for a in aliases),'Custom aliases must use their owner namespace')
    if key=='actions':check(row['content_rating']in RATINGS,'Unknown action content_rating')
    else:check('content_rating'not in row,'Only actions have content_rating')
    for f in ['actor_description','target_description','performer_description']:
     if f in row:check(isinstance(row[f],str)and 0<len(row[f])<=160,'Invalid role description')
    for f in ['actor_requirements','target_requirements']:
     if f in row:names(row[f])
    value=copy.deepcopy(row);value['aliases']=aliases
    check(ident not in defs or defs[ident]==value,'Conflicting metadata definition: '+ident);defs[ident]=value
  aliases={}
  for ident,row in sorted(defs.items()):
   for alias in [ident]+row['aliases']:
    check(alias not in aliases or aliases[alias]==ident,'Ambiguous metadata alias: '+alias);aliases[alias]=ident
  result[key]=defs;result['tag_names'if key=='tags'else 'action_names']=aliases
 return result
def builtin_documents():
 folder=Path(__file__).resolve().parents[1]/'packs/scenezoi/metadata'
 return [('scenezoi',kind,p,json.loads(p.read_text(encoding='utf-8')))for kind,p in [('tag_dictionary',folder/'tags.json'),('action_dictionary',folder/'actions.json')]]
def validate_scene(v,registry=None):
 addon_data(v.get('addon_data'));fields(v.get('participant_addon_data',{}),v['participants'])
 for data in v.get('participant_addon_data',{}).values():addon_data(data)
 names(v.get('tags',[]));fields(v.get('participant_tags',{}),v['participants'])
 for tags in v.get('participant_tags',{}).values():names(tags)
 check(isinstance(v.get('actions',[]),list)and len(v.get('actions',[]))<=256,'Invalid actions')
 result=copy.deepcopy(v)
 if registry:
  def resolve(kind,n):
   n=name(n);lookup=registry['tag_names'if kind=='tags'else 'action_names'];check(n in lookup,'Unknown registered '+kind+': '+n);return lookup[n]
  def resolve_tags(tags):
   out=[resolve('tags',n)for n in tags];check(len(out)==len(set(out)),'Duplicate canonical tag');return sorted(out)
  result['tags']=resolve_tags(v.get('tags',[]));result['participant_tags']={r:resolve_tags(t)for r,t in v.get('participant_tags',{}).items()}
  result['actions']=[]
 seen=set();highest=0
 for a in v.get('actions',[]):
  addon_data(a.get('addon_data'));fields(a,['type','actor','target','performer','addon_data'],['type','actor']);name(a['type'])
  for key in ['actor','target','performer']:
   if key in a:check(a[key]in v['participants'],'Unbound action '+key)
  if registry:
   row={'type':resolve('actions',a['type']),'actor':a['actor'],'target':a.get('target',a['actor']),'performer':a.get('performer',a['actor'])}
   entry=tuple(row.values());
   if 'addon_data'in a:row['addon_data']=copy.deepcopy(a['addon_data'])
   check(entry not in seen,'Duplicate directional action');seen.add(entry);result['actions'].append(row)
   rating=registry['actions'][row['type']]['content_rating']
   if RATINGS[rating]>highest:highest=RATINGS[rating];result['content_rating']=rating
 return result

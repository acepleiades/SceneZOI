"""Validate inert display-only localization declarations before producing native output."""
import re
def placeholders(text):return set(re.findall(r'{([A-Za-z0-9_]+)}',text))
def validate(data):
 if not isinstance(data,dict)or set(data)!={'schema_version','id','translations'}or type(data['schema_version'])is not int or data['schema_version']!=1:raise ValueError('Invalid localization document')
 if not isinstance(data['id'],str)or not re.fullmatch(r'[a-z][a-z0-9_.-]{0,95}',data['id']):raise ValueError('Invalid localization id')
 if not isinstance(data['translations'],dict)or len(data['translations'])>64:raise ValueError('Invalid localization cultures')
 for culture,groups in data['translations'].items():
  if not re.fullmatch(r'[a-z]{2}-[A-Za-z0-9-]{1,32}',culture)or not isinstance(groups,dict)or set(groups)-{'messages','labels'}:raise ValueError('Invalid localization culture/groups')
  for kind,rows in groups.items():
   if not isinstance(rows,dict)or len(rows)>2048:raise ValueError('Invalid localized text map')
   for key,text in rows.items():
    if not isinstance(key,str)or not 0<len(key.encode('utf-8'))<=1024 or any(ord(c)<32 for c in key):raise ValueError('Invalid localization key')
    if not isinstance(text,str)or not text.strip()or len(text.encode('utf-8'))>4096 or any(ord(c)<32 for c in text):raise ValueError('Invalid localized text')
    if kind=='messages'and placeholders(key)!=placeholders(text):raise ValueError('Translation placeholders differ')
 return data
def validate_documents(documents):
 seen={}
 for owner,kind,source,data in documents:
  if kind!='localization':continue
  validate(data)
  for culture,groups in data['translations'].items():
   for group,rows in groups.items():
    for key,text in rows.items():
     identity=(culture,group,key)
     if identity in seen and seen[identity]!=text:raise ValueError('Conflicting localized text: '+key)
     seen[identity]=text

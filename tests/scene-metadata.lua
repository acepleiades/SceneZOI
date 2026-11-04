package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local J=require('SceneZOI.Json');local V=require('SceneZOI.DataValidation');local Meta=require('SceneZOI.Metadata');local Search=require('SceneZOI.SceneSearch')
local function read(p)local f=assert(io.open(p,'rb'));local v=J.decode(f:read('*a'));f:close();return v end
local source={by_kind={}}
for kind,file in pairs({tag_dictionary='tags',action_dictionary='actions'})do source.by_kind[kind]={{owner='scenezoi',source=file,data=read('packs/scenezoi/metadata/'..file..'.json')}}end
local registry=Meta.compile(source);assert(#registry.warnings==0,table.concat(registry.warnings,';'));assert(registry.action_names.embracing=='hug')
local function node(id,actions)
 return {id=id,label=id,kind='loop',navigation={},participants={first={body='female'},second={body='female'},third={body='male'}},tags={'doting'},participant_tags={first={'kneel'},second={'standing'}},actions=actions}
end
local a=Meta.resolve_scene(registry,node('one',{{type='embrace',actor='first',target='third',performer='first'}}))
assert(a.content_rating=='GENERAL'and #a.actions==1 and a.actions[1].type=='hug','A one-sided hug must not acquire a reciprocal action')
local b=Meta.resolve_scene(registry,node('two',{{type='hug',actor='first',target='third'},{type='hugging',actor='third',target='first'}}));assert(#b.actions==2)
local c=Meta.resolve_scene(registry,node('three',{{type='vaginal_sex',actor='third',target='first',performer='first'},{type='hug',actor='first',target='third'}}));assert(c.content_rating=='EXPLICIT'and c.actions[1].performer=='first')
local empty=Meta.resolve_scene(registry,node('empty',{}));assert(not empty.content_rating)
assert(not pcall(Meta.resolve_scene,registry,node('bad',{{type='made_up',actor='first'}})))
local invalid=node('bad',{{type='hug',actor='not_a_role'}});assert(not pcall(Meta.resolve_scene,registry,invalid))
local duplicate=node('bad',{{type='hug',actor='first'},{type='embrace',actor='first'}});assert(not pcall(Meta.resolve_scene,registry,duplicate))
local q=Search.criteria(registry,{allowed_content_ratings={'GENERAL'},required_tags={'compassionate'},required_actions={'hugging'},participant_tags={first={required_tags={'kneeling'}}},action_filters={{type='hug',actor='first',target='third'}}})
assert(Search.matches(a,q)and not Search.matches(c,q)and not Search.matches(empty,q))
assert(not Search.matches(a,Search.criteria(registry,{excluded_tags={'affectionate'}})))
local transition=V.copy(a);transition.id='transition';transition.kind='transition';transition.destination=c.id
local nodes={[a.id]=a,[b.id]=b,[c.id]=c,[empty.id]=empty,[transition.id]=transition}
assert(not Search.allowed(nodes,transition,q),'A GENERAL transition must not bypass an EXPLICIT destination')
assert(#Search.find({nodes=nodes},q)==2)
assert(Search.random({},function()error('No-match must not draw')end)==nil)
assert(Search.random({a,b},function(n)assert(n==2);return 2 end).id=='two')
local conflict=V.copy(source);conflict.by_kind.tag_dictionary[#conflict.by_kind.tag_dictionary+1]={owner='extra',source='other',data={schema_version=1,id='extra.tags',tags={{id='extra.other',description='Other',aliases={'extra.same'}},{id='extra.second',description='Second',aliases={'extra.same'}}}}}
local bad=Meta.compile(conflict);assert(#bad.warnings>0 and not bad.tags['extra.other']and not bad.tags['extra.second'])
local rows={{id='1',body='female'},{id='2',body='male'},{id='3',body='female'}}
local binding=Search.bind(a,rows);assert(binding and binding.first~=binding.second and binding.third=='2')
assert(not pcall(Search.criteria,registry,{allowed_content_ratings={'UNKNOWN'}}))
assert(not pcall(Search.criteria,registry,{required_tags={'not_registered'}}))
print('Metadata/search passed: real dictionaries, aliases, directed/mutual actions, performer distinction, maximum rating, unrated exclusion, all/any/none queries, transition closure, repeated bodies and deterministic alias-conflict isolation.')

local Catalog=require('SceneZOI.Catalog')
local one=V.copy(a);one.navigation={{id='blocked',target=c.id}};one.task_completion_routes={first={task=c.id}}
nodes.one=one;Catalog.value={nodes=nodes,profiles={rules={}}}
local current={session_restrictions={allowed_content_ratings={'GENERAL'}}}
assert(#Catalog.get('one',current).navigation==0)
assert(not pcall(Catalog.destination,one,'blocked',current))
assert(not pcall(Catalog.transition_destination,transition,current))
assert(not pcall(Catalog.task_destination,one,{source_node_id='one',participant_role='first',task_id='task',target=c.id},current))
print('Catalog restrictions passed: hidden navigation and rejected direct, automatic-transition and task-completion destinations.')

local json_query=Search.criteria(registry,J.decode('{"required_tags":[],"action_filters":[]}'))
assert(J.encode(json_query):find('"required_tags":%[%]')and J.encode(json_query):find('"action_filters":%[%]'),'Public criteria round-trip preserves empty arrays')
assert(J.encode(registry.tags.gentle.aliases)=='[]')

-- Descriptive posture + directed action facts are sufficient for an add-on's own label.
local examples=read('docs/examples/descriptive-metadata.json').examples
local described={}
for i,example in ipairs(examples)do
 local data=V.copy(example.metadata);data.id='description.'..i;data.kind='loop';data.label=example.review_label;data.navigation={}
 described[i]=Meta.resolve_scene(registry,data)
end
local reverse=Search.criteria(registry,{participant_tags={receiving={required_tags={'on_top','straddling_partner','facing_away'}}},action_filters={{type='vaginal_sex',actor='penetrating',target='receiving',performer='receiving'}}})
assert(Search.matches(described[2],reverse)and not Search.matches(described[3],reverse),'Facing-away receiving role distinguishes the actual layout')
local wrong=V.copy(described[2]);wrong.participant_tags.receiving={'kneeling'};wrong.participant_tags.penetrating={'on_top','straddling_partner','facing_away'}
assert(not Search.matches(wrong,reverse),'Posture facts on the wrong participant must not match')
local press=Search.criteria(registry,{participant_tags={receiving={required_tags={'lying_on_back','legs_raised','thighs_against_torso'}}},required_actions={'vaginal_sex'}})
assert(Search.matches(described[1],press)and not Search.matches(described[2],press))
assert(registry.action_names.finger_anus=='anal_fingering'and not registry.action_names.analfingering)
assert(registry.action_names.spectate=='spectating'and not registry.action_names.specate)
assert(not registry.tag_names.doggy_style and not registry.tag_names.reverse_cowgirl)
local custom={schema_version=1,id='speech.tags',tags={{id='speech.reverse_cowgirl',aliases={'speech.reverse_riding'},description='Custom position terminology.'}}}
assert(Meta.dictionary(custom,'tag_dictionary','speech')['speech.reverse_cowgirl'])
custom.tags[1].aliases={'speech.reverse riding'};assert(not pcall(Meta.dictionary,custom,'tag_dictionary','speech'))
assert(Search.criteria(registry,{required_tags={'HANDS AND KNEES'}}).required_tags[1]=='all_fours','Queries may normalize spelling independently of author declarations')
print('Descriptive metadata passed: worked variants, correct action/participant pairing, custom namespaced terms, authored spelling and normalized query convenience.')

-- Scene-wide and role-specific tags use one vocabulary but remain separate scopes.
local scoped=Meta.resolve_scene(registry,{participants={first={},second={}},tags={'intimate'},participant_tags={first={'eager'},second={'standing'}},actions={}})
assert(Search.matches(scoped,Search.criteria(registry,{required_tags={'intimate'},participant_tags={first={required_tags={'eager'}}}})))
assert(not Search.matches(scoped,Search.criteria(registry,{required_tags={'eager'}})),'Actor tags are not automatically scene tags')
assert(not Search.matches(scoped,Search.criteria(registry,{participant_tags={second={required_tags={'intimate'}}}})),'Scene tags are not inherited by actors')
assert(not registry.tags.fellatio and not registry.tags.spanking and not registry.tags.gesture)
assert(registry.actions.fellatio and registry.actions.spanking and registry.actions.holding_penis_at_base)
print('Metadata scope passed: shared vocabulary, independent scene/role filters and directed positioning support action.')

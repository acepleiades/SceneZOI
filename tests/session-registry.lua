-- Sessions are addressed by ID, and removing one cannot disturb another or a list in use.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local S=require('SceneZOI.Sessions')
local a={token='a',participant_ids={'1','2'}};local b={token='b',participant_ids={'3','4'}}
S.add(a);S.add(b);assert(S.count()==2 and S.get('a')==a and S.get('b')==b and S.has(a))
assert(not pcall(S.add,{token='a',participant_ids={}}),'A token identifies one session')
assert(S.holding('3')==b and S.holding('1')==a and S.holding('9')==nil)
assert(S.focused()==nil);S.focus(a);assert(S.focused()==a)
local walking=S.list();assert(S.remove(b)and #walking==2 and walking[2]==b,'A list in use must not change underneath its caller')
assert(not S.get('b')and not S.has(b)and S.count()==1 and S.focused()==a)
assert(not S.remove(b),'Removing twice is harmless')
assert(S.remove(a)and S.focused()==nil,'Removing the focused session clears focus')
S.reset();assert(S.count()==0)
print('Session registry passed: addressing by ID, duplicate refusal, participant lookup, focus and stable iteration.')

-- Sessions are addressed by ID, and removing one cannot disturb another or a list in use.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local S=require('SceneZOI.Sessions')
local a={token='a',participant_ids={'1','2'}};local b={token='b',participant_ids={'3','4'}}
S.add(a);S.add(b);assert(S.count()==2 and S.get('a')==a and S.get('b')==b and S.has(a))
assert(not pcall(S.add,{token='a',participant_ids={}}),'A token identifies one session')
assert(S.focused()==nil);S.focus(a);assert(S.focused()==a)
local walking=S.list();assert(S.remove(b)and #walking==2 and walking[2]==b,'A list in use must not change underneath its caller')
assert(not S.get('b')and not S.has(b)and S.count()==1 and S.focused()==a)
assert(not S.remove(b),'Removing twice is harmless')
assert(S.remove(a)and S.focused()==nil,'Removing the focused session clears focus')
S.reset();assert(S.count()==0)
-- Reservations are all or nothing and cover pending starts.
assert(S.reserve('pending.1',{'1','2'},'9')and S.holder('1')=='pending.1'and S.furniture_holder('9')=='pending.1')
local ok,why=S.reserve('pending.2',{'3','2'});assert(not ok and why=='participant_busy')
assert(S.holder('3')==nil,'A refused start must hold nothing')
ok,why=S.reserve('pending.2',{'3','4'},'9');assert(not ok and why=='furniture_unavailable'and S.holder('3')==nil)
assert(S.reserve('pending.1',{'1','2'},'9'),'Re-reserving what you hold is harmless')
S.transfer('pending.1','scene.1');assert(S.holder('2')=='scene.1'and S.furniture_holder('9')=='scene.1')
-- Held through cleanup: only removing the session frees them.
local c={token='scene.1',participant_ids={'1','2'}};S.add(c);assert(S.holder('1')=='scene.1')
S.remove(c);assert(S.holder('1')==nil and S.furniture_holder('9')==nil)
assert(S.reserve('x',{'1'})and S.release('x')==nil and S.holder('1')==nil)
print('Session registry passed: addressing by ID, duplicate refusal, focus, stable iteration, and atomic roster and furniture reservations.')

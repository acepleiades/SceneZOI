package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Json=require('SceneZOI.Json')
local Guard=require('SceneZOI.ModeGuard')
local snapshot={blocked=false,pause_reasons={}}
local calls,failed,invalid=0,false,false
inzoi={cli={execute=function(command)
    assert(command=='ui.get_blocking','The guard may only observe native UI state')
    calls=calls+1
    if failed then return false,'Unavailable' end
    return true,'',invalid and 'invalid JSON' or Json.encode(snapshot)
end}}
assert(Guard.can_restore_input())
snapshot={blocked=false,pause_reasons={'CharacterCustomization'}}
local mode=Guard.update(1,true)
assert(mode.known and mode.editor and not mode.blocked,
    'In-save Create a Zoi is not reported as a modal blocker; inspect its actual pause owner')
assert(not Guard.can_restore_input(),'Never focus gameplay while the editor owns input')
snapshot={blocked=false,pause_reasons={'UserPause'}}
mode=Guard.update(1,true)
assert(not mode.editor and Guard.can_restore_input(),'Ordinary time pause must not end scenes or block their controls')
snapshot={blocked=true,pause_reasons={'GameMenu'}}
mode=Guard.update(1,true)
assert(not mode.editor and not Guard.can_restore_input(),'ESC/menu modality only delays focus restoration')
snapshot={blocked=false,pause_reasons={}}
assert(Guard.can_restore_input(),'Deferred input must become available again after returning to gameplay')
-- A cached gameplay sample is insufficient immediately after a save acknowledgement.
Guard.update(1,true)
snapshot={blocked=false,pause_reasons={'CharacterCustomization'}}
assert(not Guard.can_restore_input(),'Recheck the editor immediately before restoring focus')
failed=true
assert(not Guard.update(1,true).known and not Guard.can_restore_input(),'A failed lookup must not steal focus')
failed=false;invalid=true
assert(not Guard.update(1,true).known and not Guard.can_restore_input(),'A malformed response is not proof of gameplay')
invalid=false;snapshot={blocked=false,pause_reasons={}}
assert(Guard.can_restore_input(),'Transient failures must remain retryable')
local before=calls
for _=1,20 do Guard.update(.01,false)end
assert(calls==before,'Idle sessions must not poll native UI state')
snapshot={blocked=false,pause_reasons={'CharacterCustomization'}}
assert(Guard.update(0,true).editor,'A new session must not reuse an older gameplay sample')
print('Mode guard passed: CAZ pause owner, ordinary pause, modal focus deferral, fresh recheck, transient errors and repeated-session reset.')

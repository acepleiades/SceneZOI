-- Real character callbacks must retain the latest actor for an entity ID.
package.path='modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;'..package.path
local Runtime=require('SceneZOI.Runtime')
local Character=require('Zoi.SceneZOI')
local Protocol=require('SceneZOI.Protocol')
local Json=require('SceneZOI.Json')
local saved
inzoi={cli={execute=function(line)saved=line;return true,''end}}
local function actor(id)
    return {GetEntityId=function()return {Value=id}end}
end
local old,replacement,unrelated=actor(1),actor(1),actor(2)
Character.on_begin({},old)
Character.on_begin({},unrelated)
Character.on_begin({},replacement)
assert(Runtime.actors['1']==replacement and Runtime.actors['2']==unrelated)

Character.on_end({},old)
assert(Runtime.actors['1']==replacement,'Late old-actor cleanup must not unregister its replacement')
assert(Runtime.actors['2']==unrelated,'Late cleanup must preserve unrelated Zois')
local status=Runtime.publish_actor_registration_status('1')
assert(status.requested_registered and status.registered_count==2)
assert(status.register_calls==3 and status.unregister_calls==1 and status.non_owner_unregister_calls==1)
assert(status.last_registered_id=='1' and status.last_unregistered_id=='1')
assert(Json.decode(assert(Protocol.decode(saved:match(' value=(.*)')))).requested_id=='1')
local missing=Runtime.publish_actor_registration_status('3')
assert(not missing.requested_registered and missing.registered_count==2)
assert(Runtime.actors['1']==replacement,'Diagnostic snapshots must not change registrations')

Character.on_end({},old)
Character.on_end({},actor(1))
assert(Runtime.actors['1']==replacement,'Repeated or unregistered-owner cleanup must preserve the current actor')

Character.on_begin({},replacement)
Character.on_end({},replacement)
assert(Runtime.actors['1']==nil,'The currently registered actor must still unregister normally')
assert(Runtime.actors['2']==unrelated)
Character.on_end({},replacement)
Character.on_end({},unrelated)
assert(next(Runtime.actors)==nil,'Normal teardown must release all current registrations')
local empty=Runtime.publish_actor_registration_status('1')
assert(empty.registered_count==0 and #empty.registered_ids==0 and not empty.requested_registered)
print('Actor registration passed: replacement survives late/repeated/foreign cleanup; current and unrelated actors retain independent ownership.')

-- Spawn callbacks can precede native identity assignment for several Zois.
local first_id,second_id=-1,-1
local first={GetEntityId=function()return {Value=first_id}end}
local second={GetEntityId=function()return {Value=second_id}end}
local first_state,second_state={},{}
Character.on_begin(first_state,first)
Character.on_begin(second_state,second)
assert(next(Runtime.actors)==nil,'Unassigned native IDs must not enter the actor registry')
first_id,second_id=10,11
Character.on_tick(first_state,first,.016)
Character.on_tick(second_state,second,.016)
assert(Runtime.actors['10']==first and Runtime.actors['11']==second,
    'Every initially unassigned Zoi must register when its own ID becomes ready')
local recovered=Runtime.publish_actor_registration_status('10')
assert(recovered.deferred_register_calls==2 and #recovered.actor_identities==2)
local calls=recovered.register_calls
Character.on_tick(first_state,first,.016)
assert(Runtime.publish_actor_registration_status('10').register_calls==calls,
    'A ready actor must not repeat registration every tick')
-- Teardown may reset the native ID before the mod receives on_end.
first_id=-1
Character.on_end(first_state,first)
assert(Runtime.actors['10']==nil and Runtime.actors['11']==second,
    'Teardown must release the stored registration even after the native ID resets')
Character.on_end(second_state,second)
local ended_state,ended_actor={},actor(-1)
Character.on_begin(ended_state,ended_actor)
Character.on_end(ended_state,ended_actor)
assert(next(Runtime.actors)==nil)
print('Deferred actor identity passed: separate pending Zois recover, stable actors stop retrying, teardown uses the registered ID.')

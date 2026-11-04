package.path="modkit/SceneZOI_93C44199/workspace/lua/B1/?.lua;"..package.path
local Binding=require("SceneZOI.Binding")
local node={participants={actor_a={body="male"},actor_b={body="female"}},
    anchor_participant="actor_b",tracks={actor_a="clip_a",actor_b="clip_b"}}
local male={id="1",control="npc",body="male",role="actor_a"}
local female={id="2",control="controlled",body="female",role="actor_b"}
local result=Binding.resolve({female,male},node)
assert(result.actor_a==male and result.actor_b==female)
assert(Binding.validate(node,"actor_b","female")=="actor_b")
assert(not pcall(Binding.resolve,{male,male},node))
assert(not pcall(Binding.resolve,{male},node))
local another={id="3",body="male",role="actor_c"}
node.participants.actor_c={body="male"};node.tracks.actor_c="clip_c"
assert(Binding.resolve({another,female,male},node).actor_c==another)
another.role="actor_a";assert(not pcall(Binding.resolve,{another,female,male},node));another.role="actor_c"
assert(not pcall(Binding.validate,node,"actor_b","male"))
node.anchor_participant="missing"
assert(not pcall(Binding.resolve,{male,female},node))
print("Binding checks passed: content role IDs, actor order/control independence, missing/duplicate participants and anchor validation.")
